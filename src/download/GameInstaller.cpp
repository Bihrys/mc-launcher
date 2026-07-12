#include "download/GameInstaller.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"
#include "download/Downloader.h"
#include "download/hmcl/DownloadProvider.h"
#include "download/hmcl/LoaderInstaller.h"
#include "game/VersionRules.h"

#include <QDir>
#include <QDirIterator>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QThread>
#include <QUrl>
#include <QSysInfo>

namespace {

QString nativeClassifierForLibrary(const QJsonObject &library) {
#ifdef Q_OS_WIN
    const QString os = QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    const QString os = QStringLiteral("osx");
#else
    const QString os = QStringLiteral("linux");
#endif
    QString classifier = library.value("natives").toObject().value(os).toString();
    classifier.replace("${arch}", QSysInfo::WordSize >= 64 ? "64" : "32");
    return classifier;
}

QString displayLoaderName(const QString &kind) {
    if (kind == QStringLiteral("fabric")) return QStringLiteral("Fabric");
    if (kind == QStringLiteral("quilt")) return QStringLiteral("Quilt");
    if (kind == QStringLiteral("forge")) return QStringLiteral("Forge");
    if (kind == QStringLiteral("neoforge")) return QStringLiteral("NeoForge");
    if (kind == QStringLiteral("optifine")) return QStringLiteral("OptiFine");
    if (kind == QStringLiteral("liteloader")) return QStringLiteral("LiteLoader");
    return kind;
}

QString formatSpeed(qint64 bytesPerSec) {
    double value = static_cast<double>(qMax<qint64>(0, bytesPerSec));
    const char *unit = "B/s";
    if (value >= 1024.0 * 1024.0 * 1024.0) {
        value /= 1024.0 * 1024.0 * 1024.0;
        unit = "GiB/s";
    } else if (value >= 1024.0 * 1024.0) {
        value /= 1024.0 * 1024.0;
        unit = "MiB/s";
    } else if (value >= 1024.0) {
        value /= 1024.0;
        unit = "KiB/s";
    }
    return QString::number(value, 'f', 1) + " " + unit;
}

bool materializeVersionId(const QString &sourceId, const QString &targetId,
                          QString *errorMessage) {
    if (sourceId == targetId) return true;

    const QString sourceDirPath = LauncherPaths::versionsDir() + "/" + sourceId;
    const QString targetDirPath = LauncherPaths::versionsDir() + "/" + targetId;
    if (!QDir(sourceDirPath).exists()) {
        if (errorMessage) *errorMessage = QString("安装器没有生成版本目录：%1").arg(sourceDirPath);
        return false;
    }
    if (QDir(targetDirPath).exists()) {
        if (errorMessage) *errorMessage = QString("版本名称已存在：%1").arg(targetId);
        return false;
    }
    if (!QDir().mkpath(targetDirPath)) {
        if (errorMessage) *errorMessage = QString("无法创建版本目录：%1").arg(targetDirPath);
        return false;
    }

    QDir sourceDir(sourceDirPath);
    QDirIterator iterator(sourceDirPath,
                          QDir::NoDotAndDotDot | QDir::AllEntries,
                          QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        const QString sourcePath = iterator.next();
        const QFileInfo info(sourcePath);
        QString relative = sourceDir.relativeFilePath(sourcePath);
        if (relative == sourceId + ".json") relative = targetId + ".json";
        if (relative == sourceId + ".jar") relative = targetId + ".jar";
        const QString targetPath = targetDirPath + "/" + relative;

        if (info.isDir()) {
            if (!QDir().mkpath(targetPath)) {
                if (errorMessage) *errorMessage = QString("无法创建目录：%1").arg(targetPath);
                QDir(targetDirPath).removeRecursively();
                return false;
            }
            continue;
        }

        QDir().mkpath(QFileInfo(targetPath).absolutePath());
        if (!QFile::copy(sourcePath, targetPath)) {
            if (errorMessage) *errorMessage = QString("无法复制版本文件：%1 -> %2").arg(sourcePath, targetPath);
            QDir(targetDirPath).removeRecursively();
            return false;
        }
    }

    const QString targetJsonPath = targetDirPath + "/" + targetId + ".json";
    QJsonObject json = JsonUtil::readObjectFile(targetJsonPath, {});
    if (json.isEmpty()) {
        if (errorMessage) *errorMessage = QString("复制后的版本 JSON 无法解析：%1").arg(targetJsonPath);
        QDir(targetDirPath).removeRecursively();
        return false;
    }
    json.insert("id", targetId);
    if (!JsonUtil::writeObjectFile(targetJsonPath, json)) {
        if (errorMessage) *errorMessage = QString("无法写入版本 JSON：%1").arg(targetJsonPath);
        QDir(targetDirPath).removeRecursively();
        return false;
    }
    return true;
}

} // namespace

GameInstaller::GameInstaller(QObject *parent) : QObject(parent) {
    m_task = QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 0},
                         {"title", "空闲"}, {"message", "还没有下载任务。"},
                         {"totalFiles", 0}, {"finishedFiles", 0}, {"totalBytes", 0},
                         {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0},
                         {"speedText", "0 B/s"}, {"files", QJsonArray{}},
                         {"canCancel", false}, {"status", "idle"}, {"stages", QJsonArray()}};
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
                       {"speedText", QStringLiteral("0 B/s")}, {"files", QJsonArray{}},
                       {"canCancel", active}, {"status", status}, {"stages", QJsonArray()}};
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
                          const QString &instanceName, const QString &loaderKind,
                          const QString &loaderVersion, const QString &addonsJson) {
    if (m_running.load()) return;
    m_running.store(true);
    m_cancelled.store(false);

    {
        QMutexLocker lock(&m_mutex);
        m_stages.clear();
    }

    setTask(buildTask("preparing", "安装新游戏", "正在获取版本信息…", 0));

    m_thread = QThread::create([this, source, gameVersion, instanceName,
                                loaderKind, loaderVersion, addonsJson]() {
        runPipeline(source, gameVersion, instanceName, loaderKind, loaderVersion, addonsJson);
    });
    connect(m_thread, &QThread::finished, this, [this]() { m_running.store(false); });
    m_thread->start();
}

void GameInstaller::runPipeline(const QString &source, const QString &gameVersion,
                                const QString &instanceName, const QString &loaderKind,
                                const QString &loaderVersion, const QString &addonsJson) {
    const HmclDownloadProvider provider = HmclDownloadProvider::fromSource(source);
    const bool installingLoader = !loaderKind.isEmpty() && loaderKind != "vanilla";
    const QJsonObject addons = JsonUtil::objectFromString(addonsJson, {});
    const QJsonObject fabricApi = addons.value("fabricApi").toObject();
    const bool installingFabricApi = !fabricApi.value("version").toString().isEmpty()
            && !fabricApi.value("fileUrl").toString().isEmpty();

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
    const QString requestedVersionId = instanceName.trimmed().isEmpty() ? gameVersion : instanceName.trimmed();
    const QString requestedVersionDir = LauncherPaths::versionsDir() + "/" + requestedVersionId;

    if (requestedVersionId != gameVersion && QDir(requestedVersionDir).exists()) {
        setTask(buildTask("failed", "安装失败",
                          QString("版本名称已存在：%1").arg(requestedVersionId), 0));
        return;
    }

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
    // All consumers use stable stage ids; the generic downloader reports exact
    // per-stage completion rather than inferring it from concurrent finish order.
    const QString gameStage = QString("hmcl.install.game:%1").arg(gameVersion);
    const QString libStage = QStringLiteral("hmcl.install.libraries");
    const QString assetStage = QStringLiteral("hmcl.install.assets");

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
        item.displayName = requestedVersionId + QStringLiteral(".jar");
        item.stageId = gameStage;
        batch.append(item);
    }
    int gameEndIdx = batch.size();

    // Libraries and native classifiers (OS-rule filtered, same logic as
    // HMCL's GameLibrariesTask). Native jars must be present even though they
    // are not part of the Java classpath; InstanceService extracts them before
    // every launch when the native cache key changes.
    int libStartIdx = batch.size();
    for (const QJsonValue &v : versionJson.value("libraries").toArray()) {
        const QJsonObject lib = v.toObject();
        if (!VersionRules::allowedByRules(lib.value("rules").toArray())) continue;
        const QJsonObject downloads = lib.value("downloads").toObject();

        const QJsonObject artifact = downloads.value("artifact").toObject();
        QString rel = artifact.value("path").toString();
        if (rel.isEmpty()) rel = VersionRules::libraryPathFromName(lib.value("name").toString());
        const QString url = artifact.value("url").toString();
        if (!rel.isEmpty() && !url.isEmpty()) {
            DownloadItem item;
            item.urls = provider.candidatesFor(url);
            item.destPath = librariesRoot + "/" + rel;
            item.sha1 = artifact.value("sha1").toString();
            item.size = static_cast<qint64>(artifact.value("size").toDouble());
            item.displayName = QFileInfo(rel).fileName();
            item.stageId = libStage;
            batch.append(item);
        }

        const QString nativeClassifier = nativeClassifierForLibrary(lib);
        const QJsonObject nativeArtifact = downloads.value("classifiers").toObject()
                                               .value(nativeClassifier).toObject();
        const QString nativeRel = nativeArtifact.value("path").toString();
        const QString nativeUrl = nativeArtifact.value("url").toString();
        if (!nativeClassifier.isEmpty() && !nativeRel.isEmpty() && !nativeUrl.isEmpty()) {
            DownloadItem item;
            item.urls = provider.candidatesFor(nativeUrl);
            item.destPath = librariesRoot + "/" + nativeRel;
            item.sha1 = nativeArtifact.value("sha1").toString();
            item.size = static_cast<qint64>(nativeArtifact.value("size").toDouble());
            item.displayName = QFileInfo(nativeRel).fileName();
            item.stageId = libStage;
            batch.append(item);
        }
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
        item.displayName = hash;
        item.stageId = assetStage;
        batch.append(item);
    }
    int assetEndIdx = batch.size();

    if (m_cancelled.load()) { cancelledExit(); return; }

    const int totalFiles = batch.size();
    qint64 totalBytes = 0;
    for (const DownloadItem &i : batch) totalBytes += i.size;

    // Declare stages matching HMCL's TaskListPane stage hints.
    beginStage(gameStage, QString("安装 Minecraft %1").arg(gameVersion));
    if (libEndIdx > libStartIdx)
        beginStage(libStage, QStringLiteral("下载依赖库"));
    if (assetEndIdx > assetStartIdx)
        beginStage(assetStage, QStringLiteral("下载资源"));

    updateStageCount(gameStage, 0, gameEndIdx - gameStartIdx);
    updateStageCount(libStage, 0, libEndIdx - libStartIdx);
    updateStageCount(assetStage, 0, assetEndIdx - assetStartIdx);

    {
        QMutexLocker lock(&m_mutex);
        m_task = QJsonObject{{"active", true}, {"cancelled", false}, {"percent", 0},
                             {"title", QStringLiteral("安装新游戏")},
                             {"message", QString("正在下载游戏文件（%1 个）…").arg(totalFiles)},
                             {"totalFiles", totalFiles}, {"finishedFiles", 0},
                             {"totalBytes", static_cast<double>(totalBytes)}, {"downloadedBytes", 0},
                             {"currentFile", ""}, {"speed", 0}, {"speedText", "0 B/s"},
                             {"files", QJsonArray{}}, {"canCancel", true},
                             {"status", "downloading"}, {"stages", stagesJson()}};
    }

    connect(dl, &Downloader::progress, this,
            [this, totalBytes, gameStage, libStage, assetStage]
            (int finished, int total, qint64 bytes, const QString &current,
             qint64 speed, const QJsonArray &files,
             const QJsonObject &stageProgress) {
                const int percent = totalBytes > 0
                    ? qBound(0, static_cast<int>(bytes * 100 / totalBytes), 100)
                    : (total > 0 ? static_cast<int>(finished * 100.0 / total) : 0);

                QMutexLocker lock(&m_mutex);
                m_task.insert("finishedFiles", finished);
                m_task.insert("totalFiles", total);
                m_task.insert("downloadedBytes", static_cast<double>(bytes));
                m_task.insert("totalBytes", static_cast<double>(totalBytes));
                m_task.insert("percent", percent);
                m_task.insert("speed", static_cast<double>(speed));
                m_task.insert("speedText", formatSpeed(speed));
                m_task.insert("files", files);
                if (!current.isEmpty()) m_task.insert("currentFile", current);

                for (auto &stage : m_stages) {
                    const QJsonObject progress = stageProgress.value(stage.id).toObject();
                    if (!progress.isEmpty()) {
                        stage.count = progress.value("finished").toInt();
                        stage.total = progress.value("total").toInt();
                        if (stage.total > 0 && stage.count >= stage.total
                                && stage.status == TaskStage::Running)
                            stage.status = TaskStage::Success;
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
        beginStage(loaderStage, QString("安装 %1 %2").arg(displayLoaderName(loaderKind), loaderVersion));

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
            QString namingError;
            if (!materializeVersionId(finalId, requestedVersionId, &namingError)) {
                failStage(loaderStage);
                QJsonObject fail = buildTask("failed", "安装失败", namingError, 0);
                { QMutexLocker lock(&m_mutex); fail.insert("stages", stagesJson()); }
                setTask(fail);
                teardown();
                return;
            }
            succeedStage(loaderStage);

            if (installingFabricApi) {
                const QString apiStage = QStringLiteral("hmcl.install.fabric-api");
                const QString apiVersion = fabricApi.value("version").toString();
                beginStage(apiStage, QString("安装 Fabric API %1").arg(apiVersion));
                mergeTask(QJsonObject{{"title", "正在安装 Fabric API"},
                                      {"message", QString("正在下载 Fabric API %1…").arg(apiVersion)},
                                      {"currentFile", fabricApi.value("fileName").toString()}});
                QString fileName = fabricApi.value("fileName").toString();
                if (fileName.isEmpty()) fileName = QString("fabric-api-%1.jar").arg(apiVersion);
                const QString modsDir = LauncherPaths::versionsDir() + "/" + requestedVersionId + "/mods";
                QDir().mkpath(modsDir);
                const bool apiOk = dl->downloadSync(
                    provider.candidatesFor(fabricApi.value("fileUrl").toString()),
                    modsDir + "/" + fileName,
                    fabricApi.value("sha1").toString());
                if (!apiOk) {
                    failStage(apiStage);
                    QJsonObject fail = buildTask("failed", "Fabric API 安装失败",
                        QString("无法下载 Fabric API %1。请切换下载源或重试。").arg(apiVersion), 0);
                    { QMutexLocker lock(&m_mutex); fail.insert("stages", stagesJson()); }
                    setTask(fail);
                    teardown();
                    return;
                }
                succeedStage(apiStage);
            }
            QJsonObject done{{"active", false}, {"cancelled", false}, {"percent", 100},
                             {"title", "安装完成"}, {"message", QString("%1 安装完成，可以启动了。").arg(requestedVersionId)},
                             {"installedVersionId", requestedVersionId},
                             {"totalFiles", totalFiles}, {"finishedFiles", totalFiles},
                             {"totalBytes", static_cast<double>(totalBytes)},
                             {"downloadedBytes", static_cast<double>(totalBytes)},
                             {"currentFile", ""}, {"speed", 0}, {"speedText", "0 B/s"},
                             {"files", QJsonArray{}}, {"canCancel", false},
                             {"status", "finished"}};
            { QMutexLocker lock(&m_mutex); done.insert("stages", stagesJson()); }
            setTask(done);
        } else {
            failStage(loaderStage);
            QJsonObject fail = buildTask("failed", "加载器安装失败", loaderError, 0);
            { QMutexLocker lock(&m_mutex); fail.insert("stages", stagesJson()); }
            setTask(fail);
        }
    } else {
        QString namingError;
        if (!materializeVersionId(id, requestedVersionId, &namingError)) {
            QJsonObject fail = buildTask("failed", "安装失败", namingError, 0);
            { QMutexLocker lock(&m_mutex); fail.insert("stages", stagesJson()); }
            setTask(fail);
            teardown();
            return;
        }
        QJsonObject done{{"active", false}, {"cancelled", false}, {"percent", 100},
                         {"title", "安装完成"}, {"message", QString("%1 安装完成，可以启动了。").arg(requestedVersionId)},
                         {"installedVersionId", requestedVersionId},
                         {"totalFiles", totalFiles}, {"finishedFiles", totalFiles},
                         {"totalBytes", static_cast<double>(totalBytes)},
                         {"downloadedBytes", static_cast<double>(totalBytes)},
                         {"currentFile", ""}, {"speed", 0}, {"speedText", "0 B/s"},
                         {"files", QJsonArray{}}, {"canCancel", false},
                         {"status", "finished"}};
        { QMutexLocker lock(&m_mutex); done.insert("stages", stagesJson()); }
        setTask(done);
    }

    teardown();
}
