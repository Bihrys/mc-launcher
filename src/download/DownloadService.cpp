#include "download/DownloadService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"

#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

QByteArray DownloadService::httpGet(const QUrl &url, int timeoutMs) const {
    QNetworkAccessManager manager;
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", "mc-launcher-qt-cpp/0.1");
    QNetworkReply *reply = manager.get(req);
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();
    if (timer.isActive() && reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        reply->deleteLater();
        return data;
    }
    reply->abort();
    reply->deleteLater();
    return {};
}

QJsonArray DownloadService::fallbackFabricLoaders() const {
    QJsonArray a;
    a.append(QJsonObject{{"version", "0.16.10"}, {"stable", true}});
    a.append(QJsonObject{{"version", "0.15.11"}, {"stable", true}});
    return a;
}

QJsonArray DownloadService::fallbackQuiltLoaders() const {
    QJsonArray a;
    a.append(QJsonObject{{"version", "0.26.4"}, {"stable", true}});
    a.append(QJsonObject{{"version", "0.25.0"}, {"stable", true}});
    return a;
}

QJsonArray DownloadService::fallbackForgeInstallers(const QString &gameVersion) const {
    QJsonArray a;
    a.append(QJsonObject{{"loaderVersion", gameVersion + "-latest"}, {"gameVersion", gameVersion}, {"releaseTime", "placeholder"}});
    return a;
}

QJsonObject DownloadService::fallbackCatalog() const {
    QJsonArray versions;
    const QStringList release = {"1.21.11", "1.21.10", "1.21.8", "1.20.1", "1.19.4", "1.18.2", "1.16.5", "1.12.2"};
    for (const QString &id : release) versions.append(QJsonObject{{"id", id}, {"versionType", "release"}, {"releaseTime", ""}});
    versions.append(QJsonObject{{"id", "25w31a"}, {"versionType", "snapshot"}, {"releaseTime", ""}});
    return QJsonObject{{"latestRelease", "1.21.11"}, {"latestSnapshot", "25w31a"}, {"gameVersions", versions}, {"fabricLoaders", fallbackFabricLoaders()}, {"quiltLoaders", fallbackQuiltLoaders()}, {"forgeInstallers", QJsonArray{}}, {"neoforgeInstallers", QJsonArray{}}};
}

QJsonObject DownloadService::refreshCatalog(const QString &source) {
    Q_UNUSED(source)
    const QByteArray data = httpGet(QUrl("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"));
    if (data.isEmpty()) return fallbackCatalog();
    QJsonObject manifest = JsonUtil::objectFromString(QString::fromUtf8(data), {});
    if (manifest.isEmpty()) return fallbackCatalog();
    QJsonArray versions;
    const auto in = manifest.value("versions").toArray();
    for (int i = 0; i < in.size() && i < 300; ++i) {
        QJsonObject item = in.at(i).toObject();
        versions.append(QJsonObject{{"id", item.value("id").toString()}, {"versionType", item.value("type").toString()}, {"releaseTime", item.value("releaseTime").toString()}});
    }
    QJsonObject latest = manifest.value("latest").toObject();
    return QJsonObject{{"latestRelease", latest.value("release").toString()}, {"latestSnapshot", latest.value("snapshot").toString()}, {"gameVersions", versions}, {"fabricLoaders", fallbackFabricLoaders()}, {"quiltLoaders", fallbackQuiltLoaders()}, {"forgeInstallers", QJsonArray{}}, {"neoforgeInstallers", QJsonArray{}}};
}

QJsonObject DownloadService::loaderMetadata(const QString &source, const QString &gameVersion, const QString &loaderKind) {
    Q_UNUSED(source)
    QJsonObject out{{"loaderKind", loaderKind}};
    if (loaderKind == "fabric" || loaderKind.isEmpty()) out.insert("fabricLoaders", fallbackFabricLoaders());
    if (loaderKind == "quilt" || loaderKind.isEmpty()) out.insert("quiltLoaders", fallbackQuiltLoaders());
    if (loaderKind == "forge") out.insert("forgeInstallers", fallbackForgeInstallers(gameVersion));
    if (loaderKind == "neoforge") out.insert("neoforgeInstallers", fallbackForgeInstallers(gameVersion));
    return out;
}

QJsonObject DownloadService::installVersion(const QString &source, const QString &gameVersion, const QString &loaderKind, const QString &loaderVersion) {
    Q_UNUSED(source)
    QString id = gameVersion;
    if (!loaderKind.isEmpty() && loaderKind != "vanilla") id += "-" + loaderKind;
    QString dir = LauncherPaths::versionsDir() + "/" + id;
    QDir().mkpath(dir);
    QJsonObject versionJson{{"id", id}, {"type", "release"}, {"inheritsFrom", gameVersion}, {"mainClass", "net.minecraft.client.main.Main"}};
    if (loaderKind == "vanilla") versionJson.remove("inheritsFrom");
    if (!loaderVersion.isEmpty()) versionJson.insert("loaderVersion", loaderVersion);
    JsonUtil::writeObjectFile(dir + "/" + id + ".json", versionJson);
    QFile jar(dir + "/" + id + ".jar");
    if (!jar.exists() && jar.open(QIODevice::WriteOnly)) jar.close();
    return QJsonObject{{"success", true}, {"versionId", id}, {"message", "已创建版本骨架：" + id}};
}

QJsonObject DownloadService::idleDownloadTask() const {
    return QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 0}, {"title", "空闲"}, {"message", "还没有下载任务。"}, {"totalFiles", 0}, {"finishedFiles", 0}, {"totalBytes", 0}, {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0}, {"status", "idle"}};
}

QJsonObject DownloadService::finishedDownloadTask(const QString &message) const {
    return QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 100}, {"title", "安装完成"}, {"message", message}, {"totalFiles", 1}, {"finishedFiles", 1}, {"totalBytes", 0}, {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0}, {"status", "finished"}};
}
