#include "download/hmcl/LoaderInstaller.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"
#include "download/Downloader.h"
#include "game/VersionRules.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <QTextStream>

#include <utility>

namespace {

QString sanitizeId(QString s) {
    s.replace(QRegularExpression("[^A-Za-z0-9_.+-]"), "_");
    return s;
}

QJsonObject readObjectFile(const QString &path) {
    return JsonUtil::readObjectFile(path, {});
}

QJsonObject objectFromFile(const QString &path) {
    return readObjectFile(path);
}

QString firstString(const QJsonValue &value, const QStringList &keys) {
    if (value.isString()) return value.toString();
    const QJsonObject obj = value.toObject();
    for (const QString &key : keys) {
        const QString s = obj.value(key).toString();
        if (!s.isEmpty()) return s;
    }
    return QString();
}

QString ensureSlash(QString url) {
    if (!url.isEmpty() && !url.endsWith('/')) url += '/';
    return url;
}

QString defaultMavenRootForKind(const QString &kind, const QString &name) {
    if (kind == "quilt" || name.startsWith("org.quiltmc:"))
        return QStringLiteral("https://maven.quiltmc.org/repository/release/");
    if (name.startsWith("net.fabricmc:"))
        return QStringLiteral("https://maven.fabricmc.net/");
    return QStringLiteral("https://libraries.minecraft.net/");
}

QJsonObject libraryObject(const QString &name, const QString &urlRoot,
                          const HmclDownloadProvider &provider,
                          DownloadItem *downloadItem = nullptr) {
    const QString rel = VersionRules::libraryPathFromName(name);
    if (rel.isEmpty()) return {};

    const QString base = ensureSlash(urlRoot.isEmpty() ? defaultMavenRootForKind(QString(), name) : urlRoot) + rel;
    QJsonObject artifact{{"path", rel}, {"url", provider.injectUrl(base)}};

    QJsonObject downloads{{"artifact", artifact}};
    QJsonObject lib{{"name", name}, {"downloads", downloads}};

    if (downloadItem) {
        downloadItem->urls = provider.candidatesFor(base);
        downloadItem->destPath = LauncherPaths::minecraftDir() + "/libraries/" + rel;
        downloadItem->sha1 = QString();
        downloadItem->size = 0;
    }
    return lib;
}

void appendLibraryIfNew(QJsonArray &libs, QSet<QString> &seen, const QJsonObject &lib) {
    const QString name = lib.value("name").toString();
    if (name.isEmpty() || seen.contains(name)) return;
    seen.insert(name);
    libs.append(lib);
}

QString metadataUrl(const QString &kind, const QString &gameVersion, const QString &loaderVersion) {
    if (kind == "fabric") {
        return QString("https://meta.fabricmc.net/v2/versions/loader/%1/%2").arg(gameVersion, loaderVersion);
    }
    if (kind == "quilt") {
        return QString("https://meta.quiltmc.org/v3/versions/loader/%1/%2").arg(gameVersion, loaderVersion);
    }
    return QString();
}

QJsonObject downloadJsonToCache(Downloader *downloader, const HmclDownloadProvider &provider,
                                const QString &url, const QString &cacheName,
                                QString *error) {
    const QString cachePath = LauncherPaths::cacheDir() + "/hmcl-loader-meta/" + cacheName;
    QDir().mkpath(QFileInfo(cachePath).absolutePath());
    if (!downloader->downloadSync(provider.candidatesFor(url), cachePath)) {
        if (error) *error = QString("无法下载加载器元数据：%1").arg(url);
        return {};
    }
    QJsonObject obj = objectFromFile(cachePath);
    if (obj.isEmpty() && error) *error = QString("加载器元数据解析失败：%1").arg(cachePath);
    return obj;
}

QString mainClassFromLauncherMeta(const QJsonObject &launcherMeta) {
    const QJsonValue mainValue = launcherMeta.value("mainClass");
    if (mainValue.isString()) return mainValue.toString();
    const QJsonObject mainObj = mainValue.toObject();
    QString s = mainObj.value("client").toString();
    if (s.isEmpty()) s = mainObj.value("common").toString();
    return s;
}

void collectLibrariesFromSide(const QJsonObject &librariesObj, const QString &side,
                              const QString &kind,
                              const HmclDownloadProvider &provider,
                              QJsonArray &libs, QSet<QString> &seen,
                              QList<DownloadItem> &downloads) {
    for (const QJsonValue &v : librariesObj.value(side).toArray()) {
        const QJsonObject item = v.toObject();
        const QString name = item.value("name").toString();
        if (name.isEmpty() || seen.contains(name)) continue;
        const QString urlRoot = item.value("url").toString(defaultMavenRootForKind(kind, name));
        DownloadItem dlItem;
        const QJsonObject lib = libraryObject(name, urlRoot, provider, &dlItem);
        appendLibraryIfNew(libs, seen, lib);
        if (!dlItem.destPath.isEmpty()) downloads.append(dlItem);
    }
}

void collectMavenField(const QJsonObject &meta, const QString &fieldName,
                       const QString &kind,
                       const HmclDownloadProvider &provider,
                       QJsonArray &libs, QSet<QString> &seen,
                       QList<DownloadItem> &downloads) {
    const QJsonObject obj = meta.value(fieldName).toObject();
    const QString name = obj.value("maven").toString();
    if (name.isEmpty() || seen.contains(name)) return;
    DownloadItem dlItem;
    const QJsonObject lib = libraryObject(name, defaultMavenRootForKind(kind, name), provider, &dlItem);
    appendLibraryIfNew(libs, seen, lib);
    if (!dlItem.destPath.isEmpty()) downloads.append(dlItem);
}


QString forgeArtifactVersion(const QString &gameVersion, const QString &loaderVersion) {
    if (loaderVersion.startsWith(gameVersion + "-")) return loaderVersion;
    return gameVersion + "-" + loaderVersion;
}

QString installerUrlFor(const QString &gameVersion, const QString &loaderKind, const QString &loaderVersion) {
    if (loaderKind == "forge") {
        const QString artifact = forgeArtifactVersion(gameVersion, loaderVersion);
        return QString("https://maven.minecraftforge.net/net/minecraftforge/forge/%1/forge-%1-installer.jar").arg(artifact);
    }

    if (loaderKind == "neoforge") {
        // NeoForge 1.20.1 used the legacy net.neoforged:forge coordinate;
        // newer versions use net.neoforged:neoforge.
        if (loaderVersion.startsWith("1.20.1-")) {
            return QString("https://maven.neoforged.net/releases/net/neoforged/forge/%1/forge-%1-installer.jar").arg(loaderVersion);
        }
        return QString("https://maven.neoforged.net/releases/net/neoforged/neoforge/%1/neoforge-%1-installer.jar").arg(loaderVersion);
    }

    return QString();
}

QString javaExecutable() {
    const QString javaHome = qEnvironmentVariable("JAVA_HOME");
    if (!javaHome.isEmpty()) {
        const QString candidate = javaHome + "/bin/java";
        if (QFileInfo::exists(candidate)) return candidate;
    }
    return QStringLiteral("java");
}

QSet<QString> versionDirectoryIds() {
    QSet<QString> out;
    QDir dir(LauncherPaths::versionsDir());
    for (const QFileInfo &info : dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        out.insert(info.fileName());
    }
    return out;
}

QString findInstalledLoaderVersionId(const QSet<QString> &before,
                                     const QString &gameVersion,
                                     const QString &loaderKind,
                                     const QString &loaderVersion) {
    Q_UNUSED(before)
    QDir dir(LauncherPaths::versionsDir());
    QFileInfo best;
    const QString gameKey = gameVersion.toLower();
    const QString kindKey = loaderKind.toLower();
    const QString versionKey = loaderVersion.toLower();

    for (const QFileInfo &info : dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        const QString id = info.fileName();
        const QString low = id.toLower();
        if (!low.contains(gameKey)) continue;
        if (!low.contains(kindKey)) continue;
        if (!versionKey.isEmpty() && !low.contains(versionKey)) {
            // Forge installer ids sometimes omit the Minecraft prefix in the
            // selected value. Keep the game+kind test as the hard requirement.
        }
        const QString jsonPath = info.absoluteFilePath() + "/" + id + ".json";
        if (!QFileInfo::exists(jsonPath)) continue;
        if (!best.exists() || info.lastModified() > best.lastModified()) best = info;
    }

    if (best.exists()) return best.fileName();
    return QString();
}

bool runJavaInstaller(const QString &installerJar,
                      const QString &minecraftDir,
                      const QString &loaderKind,
                      QString *errorMessage,
                      const HmclLoaderInstaller::StatusCallback &statusCallback) {
    QDir().mkpath(minecraftDir);

    const QString java = javaExecutable();
    const QList<QStringList> attempts = {
        QStringList{QStringLiteral("-jar"), installerJar, QStringLiteral("--installClient"), minecraftDir},
        QStringList{QStringLiteral("-jar"), installerJar, QStringLiteral("--installClient")}
    };

    QString combinedLog;
    for (int i = 0; i < attempts.size(); ++i) {
        if (statusCallback) statusCallback(QString("正在执行 %1 安装器 processor（第 %2 次）…").arg(loaderKind).arg(i + 1), 88 + i * 4);

        QProcess process;
        process.setWorkingDirectory(minecraftDir);
        process.setProcessChannelMode(QProcess::MergedChannels);
        process.start(java, attempts.at(i));

        if (!process.waitForStarted(15000)) {
            combinedLog += QString("\n无法启动 Java：%1 %2\n").arg(java, attempts.at(i).join(' '));
            continue;
        }

        if (!process.waitForFinished(15 * 60 * 1000)) {
            process.kill();
            process.waitForFinished(5000);
            combinedLog += QString("\n%1 安装器执行超时。\n").arg(loaderKind);
            continue;
        }

        const QString output = QString::fromLocal8Bit(process.readAllStandardOutput());
        combinedLog += output;
        if (process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0) {
            return true;
        }
        combinedLog += QString("\n退出码：%1\n").arg(process.exitCode());
    }

    if (errorMessage) {
        QString tail = combinedLog;
        if (tail.size() > 4000) tail = tail.right(4000);
        *errorMessage = QString("%1 安装器执行失败。请确认本机 java 可用，并检查安装器输出：\n%2").arg(loaderKind, tail);
    }
    return false;
}

bool copyBaseJarToChild(const QString &gameVersion, const QString &finalId, QString *error) {
    const QString baseJar = LauncherPaths::versionsDir() + "/" + gameVersion + "/" + gameVersion + ".jar";
    const QString childJar = LauncherPaths::versionsDir() + "/" + finalId + "/" + finalId + ".jar";
    QDir().mkpath(QFileInfo(childJar).absolutePath());
    QFile::remove(childJar);
    if (!QFile::copy(baseJar, childJar)) {
        if (error) *error = QString("无法复制原版 client.jar 到加载器版本：%1 -> %2").arg(baseJar, childJar);
        return false;
    }
    return true;
}

} // namespace

QString HmclLoaderInstaller::versionIdFor(const QString &gameVersion,
                                          const QString &loaderKind,
                                          const QString &loaderVersion) {
    if (loaderKind.isEmpty() || loaderKind == "vanilla") return gameVersion;
    return sanitizeId(gameVersion + "-" + loaderKind + "-" + loaderVersion);
}

bool HmclLoaderInstaller::install(Downloader *downloader,
                                  const HmclDownloadProvider &provider,
                                  const QString &gameVersion,
                                  const QString &loaderKind,
                                  const QString &loaderVersion,
                                  QString *outVersionId,
                                  QString *errorMessage,
                                  const StatusCallback &statusCallback) {
    if (loaderKind == "fabric" || loaderKind == "quilt") {
        return installFabricLike(downloader, provider, gameVersion, loaderKind, loaderVersion,
                                 outVersionId, errorMessage, statusCallback);
    }

    if (loaderKind == "forge" || loaderKind == "neoforge") {
        return installForgeLike(downloader, provider, gameVersion, loaderKind, loaderVersion,
                                outVersionId, errorMessage, statusCallback);
    }

    if (errorMessage) {
        *errorMessage = QString("%1 安装器暂未在当前前端启用；不会生成损坏实例。").arg(loaderKind);
    }
    if (outVersionId) *outVersionId = versionIdFor(gameVersion, loaderKind, loaderVersion);
    Q_UNUSED(downloader)
    Q_UNUSED(provider)
    Q_UNUSED(statusCallback)
    return false;
}


bool HmclLoaderInstaller::installForgeLike(Downloader *downloader,
                                           const HmclDownloadProvider &provider,
                                           const QString &gameVersion,
                                           const QString &loaderKind,
                                           const QString &loaderVersion,
                                           QString *outVersionId,
                                           QString *errorMessage,
                                           const StatusCallback &statusCallback) {
    if (!downloader) {
        if (errorMessage) *errorMessage = "下载器未初始化。";
        return false;
    }

    const QString url = installerUrlFor(gameVersion, loaderKind, loaderVersion);
    if (url.isEmpty()) {
        if (errorMessage) *errorMessage = QString("无法构造 %1 安装器 URL。").arg(loaderKind);
        return false;
    }

    const QString artifact = loaderKind == "forge"
        ? forgeArtifactVersion(gameVersion, loaderVersion)
        : loaderVersion;
    const QString installerPath = LauncherPaths::cacheDir() + "/hmcl-loader-installers/" + loaderKind + "-" + sanitizeId(artifact) + "-installer.jar";
    QDir().mkpath(QFileInfo(installerPath).absolutePath());

    if (statusCallback) statusCallback(QString("正在下载 %1 安装器…").arg(loaderKind), 74);
    if (!downloader->downloadSync(provider.candidatesFor(url), installerPath)) {
        if (errorMessage) *errorMessage = QString("无法下载 %1 安装器：%2").arg(loaderKind, url);
        return false;
    }

    const QSet<QString> before = versionDirectoryIds();
    if (statusCallback) statusCallback(QString("正在运行 %1 安装器…").arg(loaderKind), 84);
    if (!runJavaInstaller(installerPath, LauncherPaths::minecraftDir(), loaderKind, errorMessage, statusCallback)) {
        return false;
    }

    QString installedId = findInstalledLoaderVersionId(before, gameVersion, loaderKind, loaderVersion);
    if (installedId.isEmpty()) {
        // If the installer succeeded but the id cannot be inferred, keep the
        // expected HMCL Qt id as the outward status. The installed version will
        // still be picked up by InstanceService on refresh if it exists.
        installedId = versionIdFor(gameVersion, loaderKind, loaderVersion);
    }

    if (outVersionId) *outVersionId = installedId;
    if (statusCallback) statusCallback(QString("%1 安装完成：%2").arg(loaderKind, installedId), 100);
    return true;
}

bool HmclLoaderInstaller::installFabricLike(Downloader *downloader,
                                            const HmclDownloadProvider &provider,
                                            const QString &gameVersion,
                                            const QString &loaderKind,
                                            const QString &loaderVersion,
                                            QString *outVersionId,
                                            QString *errorMessage,
                                            const StatusCallback &statusCallback) {
    const QString finalId = versionIdFor(gameVersion, loaderKind, loaderVersion);
    if (outVersionId) *outVersionId = finalId;

    if (statusCallback) statusCallback(QString("正在下载 %1 元数据…").arg(loaderKind), 70);
    const QString url = metadataUrl(loaderKind, gameVersion, loaderVersion);
    QJsonObject meta = downloadJsonToCache(downloader, provider, url,
                                           finalId + ".json", errorMessage);
    if (meta.isEmpty()) return false;

    const QJsonObject launcherMeta = meta.value("launcherMeta").toObject();
    QString mainClass = mainClassFromLauncherMeta(launcherMeta);
    if (mainClass.isEmpty()) {
        mainClass = loaderKind == "quilt"
            ? QStringLiteral("org.quiltmc.loader.impl.launch.knot.KnotClient")
            : QStringLiteral("net.fabricmc.loader.impl.launch.knot.KnotClient");
    }

    QJsonArray libs;
    QSet<QString> seen;
    QList<DownloadItem> libDownloads;

    const QJsonObject librariesObj = launcherMeta.value("libraries").toObject();
    collectLibrariesFromSide(librariesObj, "common", loaderKind, provider, libs, seen, libDownloads);
    collectLibrariesFromSide(librariesObj, "client", loaderKind, provider, libs, seen, libDownloads);

    // HMCL FabricInstallTask/QuiltInstallTask explicitly add mapping + loader
    // artifacts from the metadata root object.
    collectMavenField(meta, "intermediary", loaderKind, provider, libs, seen, libDownloads);
    collectMavenField(meta, "hashed", loaderKind, provider, libs, seen, libDownloads);
    collectMavenField(meta, "loader", loaderKind, provider, libs, seen, libDownloads);

    if (libs.isEmpty()) {
        if (errorMessage) *errorMessage = QString("%1 元数据没有给出任何库。URL: %2").arg(loaderKind, url);
        return false;
    }

    if (statusCallback) statusCallback(QString("正在下载 %1 依赖库…").arg(loaderKind), 78);
    if (!libDownloads.isEmpty() && !downloader->run(libDownloads)) {
        if (errorMessage) *errorMessage = QString("%1 依赖库下载失败。请切换下载源或重试。").arg(loaderKind);
        return false;
    }

    if (!copyBaseJarToChild(gameVersion, finalId, errorMessage)) return false;

    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    QJsonObject child;
    child.insert("id", finalId);
    child.insert("inheritsFrom", gameVersion);
    child.insert("type", QStringLiteral("release"));
    child.insert("time", now);
    child.insert("releaseTime", now);
    child.insert("mainClass", mainClass);
    child.insert("libraries", libs);

    QJsonObject hmclQt;
    hmclQt.insert("libraryId", loaderKind);
    hmclQt.insert("gameVersion", gameVersion);
    hmclQt.insert("loaderVersion", loaderVersion);
    hmclQt.insert("source", provider.id());
    child.insert("hmclQt", hmclQt);

    const QString jsonPath = LauncherPaths::versionsDir() + "/" + finalId + "/" + finalId + ".json";
    if (!JsonUtil::writeObjectFile(jsonPath, child)) {
        if (errorMessage) *errorMessage = QString("无法写入加载器版本 JSON：%1").arg(jsonPath);
        return false;
    }

    if (statusCallback) statusCallback(QString("%1 安装完成。").arg(finalId), 100);
    return true;
}
