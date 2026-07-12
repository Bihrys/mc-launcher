#include "launch/LaunchService.h"

#include "launch/LaunchCrashAnalyzer.h"
#include "logging/AppLogger.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
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
        {"analysisCategory", ""},
        {"stages", QJsonArray{}}, {"tasks", QJsonArray{}},
        {"files", QJsonArray{}}
    };
}

void LaunchService::start(const LaunchOptions &options, const QString &visibility) {
    if (m_launcher && m_launcher->isRunning()) {
        fail(QStringLiteral("无法启动游戏"), QStringLiteral("已有游戏启动任务正在运行。"));
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
        {"analysisCategory", ""},
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
        setStageStatus(QStringLiteral("launch.state.dependencies"), QStringLiteral("running"));
        setTask(QStringLiteral("launch.state.dependencies"),
                QStringLiteral("检查版本文件、依赖库和原生库"),
                m_options.versionId, 100);
        QTimer::singleShot(40, this, [this]() {
            if (m_terminal) return;
            setStageStatus(QStringLiteral("launch.state.dependencies"), QStringLiteral("success"));
            clearTasks();
            startAuthenticationStage();
        });
    });
}

void LaunchService::cancel() {
    if (!m_status.value("active").toBool() && !m_launcher) return;
    m_terminal = true;
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
    if (!current.isEmpty()) setStageStatus(current, QStringLiteral("failed"), message);
    m_status.insert("active", false);
    m_status.insert("percent", 100);
    m_status.insert("title", title);
    m_status.insert("message", message);
    m_status.insert("status", "failed");
    m_status.insert("analysisCategory", category);
    m_status.insert("gameStarted", false);
    m_status.insert("canCancel", false);
    m_status.insert("speedText", "失败");
    m_status.insert("shouldHide", false);
    m_status.insert("shouldClose", false);
    m_status.insert("shouldReopen", true);
    m_status.insert("tasks", QJsonArray{});
    m_status.insert("files", QJsonArray{});
    publish();
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

    QString line = QString::fromUtf8(data).trimmed();
    if (line.size() > 240) line = line.right(240);
    if (!line.isEmpty()) {
        m_status.insert("message", line);
        publish();
    }
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
        QString message;
        QString title = QStringLiteral("启动失败");
        QString category;
        if (analysis.matched) {
            title = analysis.title;
            category = analysis.category;
            message = analysis.message;
        } else {
            message = QString("游戏进程异常退出，退出代码：%1，类型：%2。")
                          .arg(exitCode).arg(exitTypeName(exitType));
        }
        message += QStringLiteral("\n游戏日志：") + m_options.logFile;
        if (!tail.isEmpty()) message += QStringLiteral("\n\n") + tail;
        fail(title, message, category);
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
