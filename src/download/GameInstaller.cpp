#include "download/GameInstaller.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"
#include "download/Downloader.h"
#include "download/hmcl/DownloadProvider.h"
#include "download/hmcl/LoaderInstaller.h"
#include "game/VersionRules.h"

#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QThread>
#include <QUrl>

namespace {

QString formatSpeed(qint64 bytesPerSec) {
    double v = static_cast<double>(bytesPerSec);
    const char *unit = "B/s";
    if (v >= 1024.0 * 1024.0) { v /= 1024.0 * 1024.0; unit = "MB/s"; }
    else if (v >= 1024.0) { v /= 1024.0; unit = "KB/s"; }
    return QString::number(v, 'f', 1) + " " + unit;
}

} // namespace

GameInstaller::GameInstaller(QObject *parent) : QObject(parent) {
    m_task = QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 0},
                         {"title", "空闲"}, {"message", "还没有下载任务。"},
                         {"totalFiles", 0}, {"finishedFiles", 0}, {"totalBytes", 0},
                         {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0},
                         {"status", "idle"}, {"stages", QJsonArray()}};
}

GameInstaller::~GameInstaller() {
    cancel();
    if (m_thread) {
        m_thread->quit();
        m_thread->wait(3000);
    }
}

QJsonObject GameInstaller::task() const {
    QMutexLocker lock(&m_mutex);
    return m_task;
}

void GameInstaller::setTask(const QJsonObject &task) {
    QMutexLocker lock(&m_mutex);
    m_task = task;
    m_task.insert("stages", stagesJson());
}

void GameInstaller::mergeTask(const QJsonObject &patch) {
    QMutexLocker lock(&m_mutex);
    for (auto it = patch.begin(); it != patch.end(); ++it) m_task.insert(it.key(), it.value());
    m_task.insert("stages", stagesJson());
}

QJsonObject GameInstaller::buildTask(const QString &status, const QString &title,
                                     const QString &message, int percent) const {
    const bool active = status == "preparing" || status == "downloading";
    return QJsonObject{{"active", active}, {"cancelled", status == "cancelled"},
                       {"percent", percent}, {"title", title}, {"message", message},
                       {"totalFiles", 0}, {"finishedFiles", 0}, {"totalBytes", 0},
                       {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0},
                       {"status", status}, {"stages", QJsonArray()}};
}

void GameInstaller::beginStage(const QString &id, const QString &title) {
    QMutexLocker lock(&m_mutex);
    for (auto &s : m_stages) {
        if (s.id == id) {
            s.status = TaskStage::Running;
            s.title = title;
            return;
        }
    }
    TaskStage stage;
    stage.id = id;
    stage.title = title;
    stage.status = TaskStage::Running;
    m_stages.append(stage);
}

void GameInstaller::updateStageCount(const QString &id, int count, int total) {
    QMutexLocker lock(&m_mutex);
    for (auto &s : m_stages) {
        if (s.id == id) {
            s.count = count;
            s.total = total;
            return;
        }
    }
}

void GameInstaller::succeedStage(const QString &id) {
    QMutexLocker lock(&m_mutex);
    for (auto &s : m_stages) {
        if (s.id == id) { s.status = TaskStage::Success; return; }
    }
}

void GameInstaller::failStage(const QString &id) {
    QMutexLocker lock(&m_mutex);
    for (auto &s : m_stages) {
        if (s.id == id) { s.status = TaskStage::Failed; return; }
    }
}

QJsonArray GameInstaller::stagesJson() const {
    QJsonArray arr;
    for (const auto &s : m_stages) arr.append(s.toJson());
    return arr;
}

void GameInstaller::cancel() {
    m_cancelled.store(true);
    QMutexLocker lock(&m_mutex);
    if (m_downloader) m_downloader->cancel();
}

void GameInstaller::start(const QString &source, const QString &gameVersion,
                          const QString &loaderKind, const QString &loaderVersion) {
    if (m_running.load()) return;
    m_running.store(true);
    m_cancelled.store(false);

    {
        QMutexLocker lock(&m_mutex);
        m_stages.clear();
    }

    setTask(buildTask("preparing", "准备安装", "正在获取版本信息…", 0));

    m_thread = QThread::create([this, source, gameVersion, loaderKind, loaderVersion]() {
        runPipeline(source, gameVersion, loaderKind, loaderVersion);
    });
    connect(m_thread, &QThread::finished, this, [this]() { m_running.store(false); });
    m_thread->start();
}

void GameInstaller::runPipeline(const QString &source, const QString &gameVersion,
                                const QString &loaderKind, const QString &loaderVersion) {
    const HmclDownloadProvider provider = HmclDownloadProvider::fromSource(source);
    const bool installingLoader = !loaderKind.isEmpty() && loaderKind != "vanilla";

    // HMCL installs the vanilla game first, then applies loader patches on top.
    // The base version id stays the raw Minecraft version; loader installs create
    // a child version that inherits from it.
    const QString id = gameVersion;
    const QString mcDir = LauncherPaths::minecraftDir();
    const QString versionDir = LauncherPaths::versionsDir() + "/" + id;
    const QString versionJsonPath = versionDir + "/" + id + ".json";
    const QString clientJarPath = versionDir + "/" + id + ".jar";
    const QString librariesRoot = mcDir + "/libraries";
    const QString assetsRoot = mcDir + "/assets";

    QDir().mkpath(versionDir);

    Downloader *dl = new Downloader();
    dl->setConcurrency(provider.concurrency());
    {
        QMutexLocker lock(&m_mutex);
        m_downloader = dl;
    }

    auto teardown = [&]() {
        QMutexLocker lock(&m_mutex);
        m_downloader = nullptr;
        delete dl;
    };

    auto cancelledExit = [&]() {
        setTask(buildTask("cancelled", "已取消", "下载任务已取消。", 0));
        teardown();
    };

    // --- Step 1: version manifest -> find version JSON URL ---
    const QString manifestTmp = LauncherPaths::cacheDir() + "/version_manifest_v2.json";
    QDir().mkpath(LauncherPaths::cacheDir());
    if (!dl->downloadSync(provider.versionListUrls(), manifestTmp)) {
        if (m_cancelled.load()) { cancelledExit(); return; }
        setTask(buildTask("failed", "安装失败", "无法获取版本清单 (version_manifest_v2.json)。", 0));
        teardown();
        return;
    }
    const QJsonObject manifest = JsonUtil::readObjectFile(manifestTmp, {});
    QString versionJsonUrl;
    for (const QJsonValue &v : manifest.value("versions").toArray()) {
        const QJsonObject o = v.toObject();
        if (o.value("id").toString() == gameVersion) {
            versionJsonUrl = o.value("url").toString();
            break;
        }
    }
    if (versionJsonUrl.isEmpty()) {
        setTask(buildTask("failed", "安装失败", QString("版本清单中找不到版本：%1").arg(gameVersion), 0));
        teardown();
        return;
    }
    if (m_cancelled.load()) { cancelledExit(); return; }

    // --- Step 2: version JSON ---
    mergeTask(QJsonObject{{"message", "正在下载版本 JSON…"}, {"currentFile", id + ".json"}});
    if (!dl->downloadSync(provider.candidatesFor(versionJsonUrl), versionJsonPath)) {
        if (m_cancelled.load()) { cancelledExit(); return; }
        setTask(buildTask("failed", "安装失败", "无法下载版本 JSON。", 0));
        teardown();
        return;
    }
    const QJsonObject versionJson = JsonUtil::readObjectFile(versionJsonPath, {});
    if (versionJson.isEmpty()) {
        setTask(buildTask("failed", "安装失败", "版本 JSON 解析失败。", 0));
        teardown();
        return;
    }
    if (m_cancelled.load()) { cancelledExit(); return; }

    // --- Step 3: asset index ---
    const QJsonObject assetIndexInfo = versionJson.value("assetIndex").toObject();
    const QString assetId = assetIndexInfo.value("id").toString(versionJson.value("assets").toString("legacy"));
    const QString assetIndexUrl = assetIndexInfo.value("url").toString();
    const QString assetIndexSha1 = assetIndexInfo.value("sha1").toString();
    const QString assetIndexPath = assetsRoot + "/indexes/" + assetId + ".json";
    QJsonObject assetIndex;
    if (!assetIndexUrl.isEmpty()) {
        mergeTask(QJsonObject{{"message", "正在下载资源索引…"}, {"currentFile", assetId + ".json"}});
        if (!dl->downloadSync(provider.candidatesFor(assetIndexUrl), assetIndexPath, assetIndexSha1)) {
            if (m_cancelled.load()) { cancelledExit(); return; }
            setTask(buildTask("failed", "安装失败", "无法下载资源索引 (asset index)。", 0));
            teardown();
            return;
        }
        assetIndex = JsonUtil::readObjectFile(assetIndexPath, {});
    }
    if (m_cancelled.load()) { cancelledExit(); return; }

    // --- Build the concurrent batch: client jar + libraries + asset objects ---
    // Track index ranges per stage so progress callbacks can update per-stage counts.
    QList<DownloadItem> batch;
    int gameStartIdx = 0;

    // Client jar (downloads.client).
    const QJsonObject clientInfo = versionJson.value("downloads").toObject().value("client").toObject();
    const QString clientUrl = clientInfo.value("url").toString();
    if (clientUrl.isEmpty()) {
        setTask(buildTask("failed", "安装失败", "版本 JSON 缺少 client 下载信息。", 0));
        teardown();
        return;
    }
    {
        DownloadItem item;
        item.urls = provider.candidatesFor(clientUrl);
        item.destPath = clientJarPath;
        item.sha1 = clientInfo.value("sha1").toString();
        item.size = static_cast<qint64>(clientInfo.value("size").toDouble());
        batch.append(item);
    }
    int gameEndIdx = batch.size();

    // Libraries (OS-rule filtered, same logic as launch classpath).
    int libStartIdx = batch.size();
    for (const QJsonValue &v : versionJson.value("libraries").toArray()) {
        const QJsonObject lib = v.toObject();
        if (!VersionRules::allowedByRules(lib.value("rules").toArray())) continue;
        const QJsonObject artifact = lib.value("downloads").toObject().value("artifact").toObject();
        QString rel = artifact.value("path").toString();
        if (rel.isEmpty()) rel = VersionRules::libraryPathFromName(lib.value("name").toString());
        if (rel.isEmpty()) continue;
        const QString url = artifact.value("url").toString();
        if (url.isEmpty()) continue;
        DownloadItem item;
        item.urls = provider.candidatesFor(url);
        item.destPath = librariesRoot + "/" + rel;
        item.sha1 = artifact.value("sha1").toString();
        item.size = static_cast<qint64>(artifact.value("size").toDouble());
        batch.append(item);
    }
    int libEndIdx = batch.size();

    // Asset objects: objects map { name -> { hash, size } }, location hash[0:2]/hash.
    int assetStartIdx = batch.size();
    const QJsonObject objects = assetIndex.value("objects").toObject();
    for (auto it = objects.begin(); it != objects.end(); ++it) {
        const QJsonObject obj = it.value().toObject();
        const QString hash = obj.value("hash").toString();
        if (hash.size() < 2) continue;
        const QString location = hash.left(2) + "/" + hash;
        DownloadItem item;
        item.urls = provider.assetObjectCandidates(location);
        item.destPath = assetsRoot + "/objects/" + location;
        item.sha1 = hash;
        item.size = static_cast<qint64>(obj.value("size").toDouble());
        batch.append(item);
    }
    int assetEndIdx = batch.size();

    if (m_cancelled.load()) { cancelledExit(); return; }

    const int totalFiles = batch.size();
    qint64 totalBytes = 0;
    for (const DownloadItem &i : batch) totalBytes += i.size;

    // Declare stages matching HMCL's TaskListPane stage hints.
    const QString gameStage = QString("hmcl.install.game:%1").arg(gameVersion);
    const QString libStage = QStringLiteral("hmcl.install.libraries");
    const QString assetStage = QStringLiteral("hmcl.install.assets");

    beginStage(gameStage, QString("安装游戏 %1").arg(gameVersion));
    if (libEndIdx > libStartIdx)
        beginStage(libStage, QStringLiteral("下载依赖库"));
    if (assetEndIdx > assetStartIdx)
        beginStage(assetStage, QStringLiteral("下载资源文件"));

    updateStageCount(gameStage, 0, gameEndIdx - gameStartIdx);
    updateStageCount(libStage, 0, libEndIdx - libStartIdx);
    updateStageCount(assetStage, 0, assetEndIdx - assetStartIdx);

    {
        QMutexLocker lock(&m_mutex);
        m_task = QJsonObject{{"active", true}, {"cancelled", false}, {"percent", 0},
                             {"title", QString("正在安装 %1").arg(id)},
                             {"message", QString("正在下载游戏文件（%1 个）…").arg(totalFiles)},
                             {"totalFiles", totalFiles}, {"finishedFiles", 0},
                             {"totalBytes", static_cast<double>(totalBytes)}, {"downloadedBytes", 0},
                             {"currentFile", ""}, {"speed", 0}, {"status", "downloading"},
                             {"stages", stagesJson()}};
    }

    QElapsedTimer timer;
    timer.start();
    connect(dl, &Downloader::progress, this,
            [this, totalBytes, timer, gameStage, libStage, assetStage,
             gameStartIdx, gameEndIdx, libStartIdx, libEndIdx, assetStartIdx, assetEndIdx]
            (int finished, int total, qint64 bytes, const QString &current) {
                const qint64 elapsedMs = timer.elapsed();
                const qint64 speed = elapsedMs > 0 ? (bytes * 1000 / elapsedMs) : 0;
                const int percent = total > 0 ? static_cast<int>(finished * 100.0 / total) : 0;

                // Update per-stage counts based on how many files finished in each range.
                const int gameTotal = gameEndIdx - gameStartIdx;
                const int libTotal = libEndIdx - libStartIdx;
                const int assetTotal = assetEndIdx - assetStartIdx;
                const int gameFinished = qMin(finished, gameTotal);
                const int libFinished = qMin(qMax(0, finished - gameTotal), libTotal);
                const int assetFinished = qMin(qMax(0, finished - gameTotal - libTotal), assetTotal);

                QMutexLocker lock(&m_mutex);
                m_task.insert("finishedFiles", finished);
                m_task.insert("totalFiles", total);
                m_task.insert("downloadedBytes", static_cast<double>(bytes));
                m_task.insert("totalBytes", static_cast<double>(totalBytes));
                m_task.insert("percent", percent);
                m_task.insert("speed", static_cast<double>(speed));
                m_task.insert("speedText", formatSpeed(speed));
                if (!current.isEmpty()) m_task.insert("currentFile", current);

                // Update stage progress (within lock since m_stages is guarded).
                for (auto &s : m_stages) {
                    if (s.id == gameStage) {
                        s.count = gameFinished;
                        if (gameFinished >= gameTotal && s.status == TaskStage::Running)
                            s.status = TaskStage::Success;
                    } else if (s.id == libStage) {
                        s.count = libFinished;
                        if (libFinished >= libTotal && s.status == TaskStage::Running)
                            s.status = TaskStage::Success;
                    } else if (s.id == assetStage) {
                        s.count = assetFinished;
                        if (assetFinished >= assetTotal && s.status == TaskStage::Running)
                            s.status = TaskStage::Success;
                    }
                }
                m_task.insert("stages", stagesJson());
            },
            Qt::DirectConnection);

    const bool ok = dl->run(batch);

    if (m_cancelled.load()) { cancelledExit(); return; }

    if (!ok) {
        failStage(gameStage);
        failStage(libStage);
        failStage(assetStage);
        QJsonObject fail = buildTask("failed", "安装失败", "部分文件下载失败，请检查网络后重试。", 0);
        {
            QMutexLocker lock(&m_mutex);
            fail.insert("stages", stagesJson());
        }
        setTask(fail);
        teardown();
        return;
    }

    succeedStage(gameStage);
    succeedStage(libStage);
    succeedStage(assetStage);

    if (installingLoader) {
        const QString loaderStage = "hmcl.install." + loaderKind;
        beginStage(loaderStage, QString("安装 %1 %2").arg(loaderKind, loaderVersion));

        QString finalId;
        QString loaderError;
        const bool loaderOk = HmclLoaderInstaller::install(
            dl, provider, gameVersion, loaderKind, loaderVersion, &finalId, &loaderError,
            [this, &loaderStage](const QString &message, int percent) {
                mergeTask(QJsonObject{{"title", "正在安装加载器"},
                                      {"message", message},
                                      {"percent", percent},
                                      {"currentFile", QString()}});
            });
        if (m_cancelled.load()) { cancelledExit(); return; }
        if (loaderOk) {
            succeedStage(loaderStage);
            QJsonObject done{{"active", false}, {"cancelled", false}, {"percent", 100},
                             {"title", "安装完成"}, {"message", QString("%1 安装完成，可以启动了。").arg(finalId)},
                             {"totalFiles", totalFiles}, {"finishedFiles", totalFiles},
                             {"totalBytes", static_cast<double>(totalBytes)},
                             {"downloadedBytes", static_cast<double>(totalBytes)},
                             {"currentFile", ""}, {"speed", 0}, {"status", "finished"}};
            { QMutexLocker lock(&m_mutex); done.insert("stages", stagesJson()); }
            setTask(done);
        } else {
            failStage(loaderStage);
            QJsonObject fail = buildTask("failed", "加载器安装失败", loaderError, 0);
            { QMutexLocker lock(&m_mutex); fail.insert("stages", stagesJson()); }
            setTask(fail);
        }
    } else {
        QJsonObject done{{"active", false}, {"cancelled", false}, {"percent", 100},
                         {"title", "安装完成"}, {"message", QString("%1 安装完成，可以启动了。").arg(id)},
                         {"totalFiles", totalFiles}, {"finishedFiles", totalFiles},
                         {"totalBytes", static_cast<double>(totalBytes)},
                         {"downloadedBytes", static_cast<double>(totalBytes)},
                         {"currentFile", ""}, {"speed", 0}, {"status", "finished"}};
        { QMutexLocker lock(&m_mutex); done.insert("stages", stagesJson()); }
        setTask(done);
    }

    teardown();
}
