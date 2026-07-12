#include "launch/LaunchService.h"

#include "launch/LaunchCrashAnalyzer.h"
#include "core/JsonUtil.h"
#include "download/Downloader.h"
#include "download/hmcl/DownloadProvider.h"
#include "logging/AppLogger.h"

#include <QDateTime>
#include <QMetaObject>
#include <QThread>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QSysInfo>
#include <QTimer>
#include <QUrl>

namespace {

QJsonArray initialStages() {
    return QJsonArray{
        QJsonObject{{"id", "launch.state.java"},
                    {"title", "检查 Java"},
                    {"status", "waiting"}},
        QJsonObject{{"id", "launch.state.dependencies"},
                    {"title", "检查游戏完整性"},
                    {"status", "waiting"}},
        QJsonObject{{"id", "launch.state.logging_in"},
                    {"title", "登录账户"},
                    {"status", "waiting"}},
        QJsonObject{{"id", "launch.state.waiting_launching"},
                    {"title", "等待游戏启动"},
                    {"status", "waiting"}}
    };
}

QString formatSpeed(qint64 bytesPerSecond) {
    const double value = qMax<qint64>(0, bytesPerSecond);
    if (value < 1024.0) return QString::number(value, 'f', 0) + QStringLiteral(" B/s");
    if (value < 1024.0 * 1024.0)
        return QString::number(value / 1024.0, 'f', 1) + QStringLiteral(" KiB/s");
    return QString::number(value / (1024.0 * 1024.0), 'f', 1) + QStringLiteral(" MiB/s");
}

QString exitTypeName(ProcessListener::ExitType type) {
    switch (type) {
    case ProcessListener::ExitType::JvmError: return QStringLiteral("JVM_ERROR");
    case ProcessListener::ExitType::ApplicationError: return QStringLiteral("APPLICATION_ERROR");
    case ProcessListener::ExitType::SigKill: return QStringLiteral("SIGKILL");
    case ProcessListener::ExitType::Normal: return QStringLiteral("NORMAL");
    case ProcessListener::ExitType::Interrupted: return QStringLiteral("INTERRUPTED");
    }
    return QStringLiteral("APPLICATION_ERROR");
}


bool fileMatchesSha1(const QString &path, const QString &sha1) {
    const QFileInfo info(path);
    if (!info.isFile() || info.size() <= 0) return false;
    if (sha1.isEmpty()) return true;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return false;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    if (!hash.addData(&file)) return false;
    return hash.result().toHex() == sha1.toLatin1().toLower();
}

QList<DownloadItem> downloadItemsFromJson(const QJsonArray &array) {
    QList<DownloadItem> items;
    for (const QJsonValue &value : array) {
        const QJsonObject object = value.toObject();
        DownloadItem item;
        for (const QJsonValue &url : object.value("urls").toArray()) {
            const QUrl parsed(url.toString());
            if (parsed.isValid() && !parsed.isEmpty()) item.urls.append(parsed);
        }
        item.destPath = object.value("destPath").toString();
        item.sha1 = object.value("sha1").toString();
        item.size = static_cast<qint64>(object.value("size").toDouble());
        item.displayName = object.value("displayName").toString();
        item.stageId = object.value("stageId").toString();
        if (!item.destPath.isEmpty() && !item.urls.isEmpty()) items.append(item);
    }
    return items;
}

QList<DownloadItem> assetDownloads(const LaunchOptions &options, QString *error) {
    QList<DownloadItem> items;
    if (options.assetIndexFile.isEmpty()) return items;
    const QJsonObject index = JsonUtil::readObjectFile(options.assetIndexFile, {});
    if (index.isEmpty()) {
        if (error) *error = QStringLiteral("资源索引无法解析：") + options.assetIndexFile;
        return items;
    }

    const HmclDownloadProvider provider = HmclDownloadProvider::fromSource(options.downloadSource);
    const QJsonObject objects = index.value("objects").toObject();
    items.reserve(objects.size());
    for (auto it = objects.begin(); it != objects.end(); ++it) {
        const QJsonObject object = it.value().toObject();
        const QString hash = object.value("hash").toString();
        if (hash.size() < 2) continue;
        const QString location = hash.left(2) + u'/' + hash;
        DownloadItem item;
        item.urls = provider.assetObjectCandidates(location);
        item.destPath = options.assetsDirectory + QStringLiteral("/objects/") + location;
        item.sha1 = hash;
        item.size = static_cast<qint64>(object.value("size").toDouble());
        const QFileInfo existing(item.destPath);
        if (existing.isFile()
            && (item.size <= 0 || existing.size() == item.size)
            && fileMatchesSha1(item.destPath, hash)) {
            continue;
        }
        item.displayName = hash;
        item.stageId = QStringLiteral("hmcl.install.assets");
        items.append(item);
    }
    return items;
}

} // namespace

LaunchService::LaunchService(QObject *parent) : QObject(parent), m_status(idle()) {}

QJsonObject LaunchService::idle() const {
    return QJsonObject{
        {"id", ""}, {"active", false}, {"percent", 0},
        {"title", "启动游戏"}, {"message", "还没有启动任务。"},
        {"status", "idle"}, {"visibility", "hide"},
        {"gameStarted", false}, {"shouldHide", false},
        {"shouldClose", false}, {"shouldReopen", false},
        {"pid", 0}, {"canCancel", false}, {"cancelled", false},
        {"speedText", ""}, {"currentStage", ""},
        {"analysisCategory", ""}, {"crash", QJsonObject{}},
        {"stages", QJsonArray{}}, {"tasks", QJsonArray{}},
        {"files", QJsonArray{}}
    };
}

void LaunchService::start(const LaunchOptions &options, const QString &visibility) {
    if (m_status.value("active").toBool()
        || (m_launcher && m_launcher->isRunning())) {
        AppLogger::warning("launch", "duplicate_start_ignored",
                           QStringLiteral("已有游戏启动任务正在运行。"));
        return;
    }
    if (m_authlibReply) {
        m_authlibReply->abort();
        m_authlibReply->deleteLater();
        m_authlibReply = nullptr;
    }

    m_options = options;
    m_visibility = visibility.isEmpty() ? QStringLiteral("hide") : visibility;
    m_launcher.reset();
    m_processReady = false;
    m_terminal = false;
    m_processLog.clear();
    ++m_dependencyGeneration;
    m_dependencyCancel = std::make_shared<std::atomic_bool>(false);

    m_status = QJsonObject{
        {"id", QStringLiteral("launch-") + options.versionId + u'-'
                   + QString::number(QDateTime::currentMSecsSinceEpoch())},
        {"active", true}, {"percent", 5},
        {"title", "启动游戏"}, {"message", "正在准备启动。"},
        {"status", "preparing"}, {"visibility", m_visibility},
        {"gameStarted", false}, {"shouldHide", false},
        {"shouldClose", false}, {"shouldReopen", false},
        {"pid", 0}, {"canCancel", true}, {"cancelled", false},
        {"speedText", "请耐心等待"},
        {"currentStage", "launch.state.java"},
        {"analysisCategory", ""}, {"crash", QJsonObject{}},
        {"stages", initialStages()}, {"tasks", QJsonArray{}},
        {"files", QJsonArray{}}, {"gameLogFile", options.logFile}
    };
    publish();

    if (!options.valid) {
        fail(QStringLiteral("启动失败"), options.error.isEmpty()
                 ? QStringLiteral("无法生成启动参数。") : options.error);
        return;
    }

    setStageStatus(QStringLiteral("launch.state.java"), QStringLiteral("running"));
    setTask(QStringLiteral("launch.state.java"),
            QString("Java %1").arg(options.requiredJavaMajor),
            options.javaExecutable, 100);
    QTimer::singleShot(40, this, [this]() {
        if (m_terminal) return;
        setStageStatus(QStringLiteral("launch.state.java"), QStringLiteral("success"));
        clearTasks();
        startDependencyStage();
    });
}

void LaunchService::cancel() {
    if (!m_status.value("active").toBool() && !m_launcher) return;
    m_terminal = true;
    if (m_dependencyCancel) m_dependencyCancel->store(true);
    ++m_dependencyGeneration;
    if (m_authlibReply) {
        m_authlibReply->abort();
        m_authlibReply->deleteLater();
        m_authlibReply = nullptr;
    }
    if (m_launcher) m_launcher->stop();
    m_status.insert("active", false);
    m_status.insert("status", "cancelled");
    m_status.insert("cancelled", true);
    m_status.insert("canCancel", false);
    m_status.insert("message", "启动任务已取消。");
    m_status.insert("speedText", "");
    m_status.insert("tasks", QJsonArray{});
    m_status.insert("files", QJsonArray{});
    publish();
}

void LaunchService::publish() {
    emit statusChanged(m_status);
}

void LaunchService::setStageStatus(const QString &id, const QString &status,
                                   const QString &message) {
    QJsonArray stages = m_status.value("stages").toArray();
    for (int i = 0; i < stages.size(); ++i) {
        QJsonObject stage = stages.at(i).toObject();
        if (stage.value("id").toString() != id) continue;
        stage.insert("status", status);
        if (!message.isEmpty()) stage.insert("message", message);
        stages[i] = stage;
        break;
    }
    m_status.insert("stages", stages);
    m_status.insert("currentStage", id);
    publish();
}

void LaunchService::setTask(const QString &stageId, const QString &name,
                            const QString &message, int percent) {
    QJsonObject task{{"stageId", stageId}, {"name", name}, {"message", message}};
    if (percent >= 0) task.insert("percent", percent);
    m_status.insert("files", QJsonArray{task});
    m_status.insert("tasks", QJsonArray{task});
    publish();
}

void LaunchService::clearTasks() {
    m_status.insert("files", QJsonArray{});
    m_status.insert("tasks", QJsonArray{});
    publish();
}

void LaunchService::fail(const QString &title, const QString &message,
                         const QString &category) {
    if (m_terminal && m_status.value("status").toString() == QStringLiteral("failed")) return;
    m_terminal = true;

    const QString current = m_status.value("currentStage").toString();
    QJsonArray stages = m_status.value("stages").toArray();
    for (int i = 0; i < stages.size(); ++i) {
        QJsonObject stage = stages.at(i).toObject();
        if (stage.value("id").toString() != current) continue;
        stage.insert("status", QStringLiteral("failed"));
        stage.insert("message", message);
        stages[i] = stage;
        break;
    }

    m_status.insert("active", false);
    m_status.insert("percent", 100);
    m_status.insert("title", title);
    m_status.insert("message", message);
    m_status.insert("status", QStringLiteral("failed"));
    m_status.insert("analysisCategory", category);
    m_status.insert("gameStarted", false);
    m_status.insert("canCancel", false);
    m_status.insert("speedText", QString());
    m_status.insert("shouldHide", false);
    m_status.insert("shouldClose", false);
    m_status.insert("shouldReopen", false);
    m_status.insert("stages", stages);
    m_status.insert("tasks", QJsonArray{});
    m_status.insert("files", QJsonArray{});
    m_status.insert("crash", QJsonObject{});
    publish();
}


void LaunchService::startDependencyStage() {
    if (m_terminal) return;
    setStageStatus(QStringLiteral("launch.state.dependencies"), QStringLiteral("running"));
    m_status.insert("percent", 15);
    m_status.insert("message", QStringLiteral("正在检查并补全游戏文件。"));
    setTask(QStringLiteral("launch.state.dependencies"),
            QStringLiteral("检查游戏完整性"), m_options.versionId, -1);
    publish();

    const LaunchOptions options = m_options;
    const quint64 generation = m_dependencyGeneration;
    const std::shared_ptr<std::atomic_bool> cancelFlag = m_dependencyCancel;
    QPointer<LaunchService> guard(this);

    QThread *thread = QThread::create([guard, options, generation, cancelFlag]() {
        if (!guard || !cancelFlag || cancelFlag->load()) return;

        auto reportProgress = [guard, generation](int finished, int total, qint64 bytes,
                                                  const QString &current, qint64 speed,
                                                  const QJsonArray &files,
                                                  const QJsonObject &) {
            if (!guard) return;
            QMetaObject::invokeMethod(guard.data(), [guard, generation, finished, total, bytes,
                                              current, speed, files]() {
                if (!guard || guard->m_dependencyGeneration != generation
                    || guard->m_terminal) return;
                const int percent = total > 0 ? qBound(0, 15 + int(35.0 * finished / total), 50) : 15;
                guard->m_status.insert("percent", percent);
                guard->m_status.insert("message", current.isEmpty()
                    ? QStringLiteral("正在检查并补全游戏文件。")
                    : QStringLiteral("正在下载：") + current);
                guard->m_status.insert("speedText", formatSpeed(speed));
                guard->m_status.insert("files", files);
                guard->m_status.insert("tasks", files);
                guard->m_status.insert("downloadedBytes", static_cast<double>(bytes));
                guard->m_status.insert("finishedFiles", finished);
                guard->m_status.insert("totalFiles", total);
                guard->publish();
            }, Qt::QueuedConnection);
        };

        bool ok = true;
        QString error;
        QList<DownloadItem> initial = downloadItemsFromJson(options.dependencyDownloads);
        if (!initial.isEmpty()) {
            Downloader downloader;
            downloader.setConcurrency(HmclDownloadProvider::fromSource(options.downloadSource).concurrency());
            downloader.setCancellationFlag(cancelFlag);
            QObject::connect(&downloader, &Downloader::progress, &downloader,
                             reportProgress, Qt::DirectConnection);
            ok = downloader.run(initial);
            if (!ok && !cancelFlag->load()) error = QStringLiteral("游戏依赖文件下载失败，请检查网络后重试。");
        }

        if (ok && !cancelFlag->load()) {
            QList<DownloadItem> assets = assetDownloads(options, &error);
            if (error.isEmpty() && !assets.isEmpty()) {
                Downloader downloader;
                downloader.setConcurrency(HmclDownloadProvider::fromSource(options.downloadSource).concurrency());
                downloader.setCancellationFlag(cancelFlag);
                QObject::connect(&downloader, &Downloader::progress, &downloader,
                                 reportProgress, Qt::DirectConnection);
                ok = downloader.run(assets);
                if (!ok && !cancelFlag->load()) error = QStringLiteral("游戏资源文件下载失败，请检查网络后重试。");
            } else if (!error.isEmpty()) {
                ok = false;
            }
        }

        if (!guard) return;
        QMetaObject::invokeMethod(guard.data(), [guard, generation, cancelFlag, ok, error]() {
            if (!guard || guard->m_dependencyGeneration != generation
                || guard->m_terminal || (cancelFlag && cancelFlag->load())) return;
            guard->clearTasks();
            guard->m_status.insert("speedText", QStringLiteral("请耐心等待"));
            if (!ok) {
                guard->fail(QStringLiteral("启动失败"),
                            error.isEmpty() ? QStringLiteral("游戏完整性检查失败。") : error,
                            QStringLiteral("DEPENDENCY_ERROR"));
                return;
            }
            guard->setStageStatus(QStringLiteral("launch.state.dependencies"),
                                  QStringLiteral("success"));
            guard->startAuthenticationStage();
        }, Qt::QueuedConnection);
    });
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    thread->start();
}

void LaunchService::startAuthenticationStage() {
    setStageStatus(QStringLiteral("launch.state.logging_in"), QStringLiteral("running"));
    m_status.insert("percent", 55);
    m_status.insert("message", QString("正在登录账户 %1。").arg(m_options.accountName));
    publish();

    if (m_options.accountKind == QStringLiteral("yggdrasil")
        && !QFileInfo::exists(m_options.authlibInjectorPath)) {
        setTask(QStringLiteral("launch.state.logging_in"),
                QStringLiteral("下载 authlib-injector"),
                QStringLiteral("authlib-injector-1.2.7.jar"), 0);
        downloadAuthlibInjector();
        return;
    }

    QTimer::singleShot(30, this, [this]() {
        if (m_terminal) return;
        setStageStatus(QStringLiteral("launch.state.logging_in"), QStringLiteral("success"));
        clearTasks();
        startProcess();
    });
}

void LaunchService::downloadAuthlibInjector(int candidateIndex) {
    static const QStringList candidates{
        QStringLiteral("https://repo1.maven.org/maven2/org/glavo/hmcl/authlib-injector/1.2.7/authlib-injector-1.2.7.jar"),
        QStringLiteral("https://bmclapi2.bangbang93.com/maven/org/glavo/hmcl/authlib-injector/1.2.7/authlib-injector-1.2.7.jar")
    };
    if (candidateIndex >= candidates.size()) {
        fail(QStringLiteral("登录失败"),
             QStringLiteral("无法下载 authlib-injector。请检查网络或切换下载源。"));
        return;
    }

    QNetworkRequest request{QUrl(candidates.at(candidateIndex))};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "HMCL-Qt/0.1");
    m_authlibReply = m_network.get(request);
    m_authlibTimer.restart();
    m_authlibLastBytes = 0;
    m_authlibLastMs = 0;

    connect(m_authlibReply, &QNetworkReply::downloadProgress, this,
            [this](qint64 received, qint64 total) {
        if (!m_authlibReply || m_terminal) return;
        const int percent = total > 0 ? int((received * 100) / total) : 0;
        const qint64 now = m_authlibTimer.elapsed();
        qint64 speed = 0;
        if (now > m_authlibLastMs) {
            speed = (received - m_authlibLastBytes) * 1000 / (now - m_authlibLastMs);
            m_authlibLastBytes = received;
            m_authlibLastMs = now;
        }
        setTask(QStringLiteral("launch.state.logging_in"),
                QStringLiteral("下载 authlib-injector"),
                QString("%1 / %2").arg(received).arg(total), percent);
        m_status.insert("speedText", formatSpeed(speed));
        publish();
    });

    connect(m_authlibReply, &QNetworkReply::finished, this,
            [this, candidateIndex]() {
        QPointer<QNetworkReply> reply = m_authlibReply;
        m_authlibReply = nullptr;
        if (!reply || m_terminal) {
            if (reply) reply->deleteLater();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || !reply->isReadable()) {
            const QString error = reply->errorString();
            reply->deleteLater();
            AppLogger::warning("launch", "authlib_download_failed", error,
                               {{"candidateIndex", candidateIndex}});
            downloadAuthlibInjector(candidateIndex + 1);
            return;
        }
        const QByteArray data = reply->readAll();
        reply->deleteLater();
        if (data.size() < 1024 || !data.startsWith("PK")) {
            downloadAuthlibInjector(candidateIndex + 1);
            return;
        }
        QDir().mkpath(QFileInfo(m_options.authlibInjectorPath).absolutePath());
        QSaveFile file(m_options.authlibInjectorPath);
        if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size()
            || !file.commit()) {
            fail(QStringLiteral("登录失败"), QStringLiteral("无法保存 authlib-injector。"));
            return;
        }
        setStageStatus(QStringLiteral("launch.state.logging_in"), QStringLiteral("success"));
        clearTasks();
        m_status.insert("speedText", QStringLiteral("请耐心等待"));
        startProcess();
    });
}

void LaunchService::startProcess() {
    if (m_terminal) return;
    setStageStatus(QStringLiteral("launch.state.waiting_launching"), QStringLiteral("running"));
    setTask(QStringLiteral("launch.state.waiting_launching"),
            QStringLiteral("创建游戏进程"),
            QFileInfo(m_options.javaExecutable).fileName(), -1);
    m_status.insert("percent", 80);
    m_status.insert("message", QString("正在启动 %1。").arg(m_options.versionId));
    publish();

    m_launcher = std::make_unique<DefaultLauncher>(m_options, this, this);
    m_launcher->start();
}

QString LaunchService::gameLogTail() const {
    QFile file(m_options.logFile);
    if (!file.open(QIODevice::ReadOnly)) return {};
    constexpr qint64 maxBytes = 48 * 1024;
    if (file.size() > maxBytes) file.seek(file.size() - maxBytes);
    QString text = QString::fromUtf8(file.readAll()).trimmed();
    if (text.size() > 5000) text = text.right(5000);
    return text;
}

void LaunchService::onProcessStarted(qint64 pid) {
    if (m_terminal) return;
    m_status.insert("pid", static_cast<double>(pid));
    m_status.insert("message", QStringLiteral("游戏进程已创建，正在等待游戏窗口。"));
    setTask(QStringLiteral("launch.state.waiting_launching"),
            QStringLiteral("等待游戏启动"),
            QString("PID %1").arg(pid), -1);
    publish();
}

void LaunchService::onProcessLog(const QByteArray &data, bool standardError) {
    Q_UNUSED(standardError)
    if (m_terminal || data.isEmpty()) return;

    m_processLog.append(QString::fromUtf8(data));
    constexpr qsizetype maxCharacters = 256 * 1024;
    if (m_processLog.size() > maxCharacters)
        m_processLog = m_processLog.right(maxCharacters);

    // HMCL's TaskExecutorDialogPane keeps showing the launch stage and the
    // fixed "请耐心等待" progress text. Raw Minecraft output belongs to the
    // process log / crash window and must never replace the task description.
}

void LaunchService::onProcessReady() {
    if (m_terminal) return;
    m_processReady = true;
    setStageStatus(QStringLiteral("launch.state.waiting_launching"), QStringLiteral("success"));
    clearTasks();
    m_status.insert("active", false);
    m_status.insert("percent", 100);
    m_status.insert("title", QStringLiteral("启动游戏"));
    m_status.insert("message", QString("%1 已启动。").arg(m_options.versionId));
    m_status.insert("status", QStringLiteral("gameRunning"));
    m_status.insert("gameStarted", true);
    m_status.insert("canCancel", false);
    m_status.insert("speedText", QString());
    m_status.insert("shouldHide", m_visibility == QStringLiteral("hide")
                                  || m_visibility == QStringLiteral("close")
                                  || m_visibility == QStringLiteral("hide_and_reopen"));
    m_status.insert("shouldClose", false);
    m_status.insert("shouldReopen", false);
    publish();
}

void LaunchService::onProcessExited(int exitCode, ProcessListener::ExitType exitType,
                                    bool exitedBeforeReady) {
    if (m_terminal || m_status.value("cancelled").toBool()) return;
    if (exitType == ProcessListener::ExitType::Interrupted) return;

    const QString tail = gameLogTail();
    QString analysisText = m_processLog;
    if (!tail.isEmpty() && !analysisText.contains(tail))
        analysisText += QStringLiteral("\n") + tail;

    const LaunchCrashAnalyzer::Result analysis =
        LaunchCrashAnalyzer::analyze(analysisText, exitCode);

    if (analysis.matched || exitType != ProcessListener::ExitType::Normal) {
        m_terminal = true;

        QString reason;
        QString title = QStringLiteral("游戏异常退出");
        QString category;
        if (analysis.matched) {
            title = analysis.title;
            category = analysis.category;
            reason = analysis.message;
        } else {
            reason = QString("游戏进程异常退出，退出代码：%1，类型：%2。")
                         .arg(exitCode).arg(exitTypeName(exitType));
        }

        QJsonArray stages = m_status.value("stages").toArray();
        const QString current = m_status.value("currentStage").toString();
        for (int i = 0; i < stages.size(); ++i) {
            QJsonObject stage = stages.at(i).toObject();
            if (stage.value("id").toString() != current) continue;
            stage.insert("status", QStringLiteral("failed"));
            stages[i] = stage;
            break;
        }

        QJsonArray loaders;
        for (const QString &loader : m_options.loaderKinds) loaders.append(loader);
        const QJsonObject crash{
            {"title", title},
            {"reason", reason},
            {"details", analysisText.right(16000)},
            {"category", category},
            {"exitCode", exitCode},
            {"exitType", exitTypeName(exitType)},
            {"exitedBeforeReady", exitedBeforeReady},
            {"versionId", m_options.versionId},
            {"gameVersion", m_options.gameVersion},
            {"javaExecutable", m_options.javaExecutable},
            {"javaMajor", m_options.requiredJavaMajor},
            {"memoryMiB", m_options.maxMemoryMiB},
            {"gameDirectory", m_options.workingDirectory},
            {"instanceDirectory", m_options.instanceDirectory},
            {"nativeDirectory", m_options.nativeDirectory},
            {"gameLogFile", m_options.logFile},
            {"loaderKinds", loaders},
            {"renderer", m_options.renderer},
            {"graphicsBackend", m_options.graphicsBackend},
            {"operatingSystem", QSysInfo::prettyProductName()},
            {"architecture", QSysInfo::currentCpuArchitecture()},
            {"launcherVersion", QStringLiteral("0.1.0")}
        };

        m_status.insert("active", false);
        m_status.insert("percent", 100);
        m_status.insert("title", title);
        m_status.insert("message", reason);
        m_status.insert("status", QStringLiteral("gameCrashed"));
        m_status.insert("analysisCategory", category);
        m_status.insert("gameStarted", m_processReady);
        m_status.insert("canCancel", false);
        m_status.insert("speedText", QString());
        m_status.insert("shouldHide", false);
        m_status.insert("shouldClose", false);
        m_status.insert("shouldReopen",
                        m_visibility == QStringLiteral("hide_and_reopen"));
        m_status.insert("exitCode", exitCode);
        m_status.insert("exitType", exitTypeName(exitType));
        m_status.insert("stages", stages);
        m_status.insert("tasks", QJsonArray{});
        m_status.insert("files", QJsonArray{});
        m_status.insert("crash", crash);
        publish();
        return;
    }

    m_terminal = true;
    m_status.insert("active", false);
    m_status.insert("status", QStringLiteral("gameExited"));
    m_status.insert("gameStarted", m_processReady);
    m_status.insert("canCancel", false);
    m_status.insert("message", exitedBeforeReady
        ? QStringLiteral("游戏进程已正常退出。")
        : QStringLiteral("游戏已正常退出。"));
    m_status.insert("shouldHide", false);
    m_status.insert("shouldClose", false);
    m_status.insert("shouldReopen",
                    m_visibility == QStringLiteral("hide_and_reopen"));
    m_status.insert("exitCode", exitCode);
    publish();
}

void LaunchService::onProcessError(const QString &message) {
    if (m_terminal) return;
    fail(QStringLiteral("无法创建游戏进程"), message, QStringLiteral("process_creation"));
}
