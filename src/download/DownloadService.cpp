#include "download/DownloadService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"
#include "download/hmcl/DownloadProvider.h"
#include "download/hmcl/VersionListService.h"

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
    const bool timedOut = !timer.isActive();
    if (!timedOut && reply->error() == QNetworkReply::NoError && reply->isReadable()) {
        QByteArray data = reply->readAll();
        reply->deleteLater();
        return data;
    }
    if (timedOut && !reply->isFinished()) reply->abort();
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
    HmclVersionListService service(HmclDownloadProvider::fromSource(source));
    QJsonObject catalog = service.refreshCatalog();
    if (catalog.isEmpty()) return fallbackCatalog();
    if (catalog.value("fabricLoaders").toArray().isEmpty()) catalog.insert("fabricLoaders", fallbackFabricLoaders());
    if (catalog.value("quiltLoaders").toArray().isEmpty()) catalog.insert("quiltLoaders", fallbackQuiltLoaders());
    return catalog;
}

QJsonObject DownloadService::loaderMetadata(const QString &source, const QString &gameVersion, const QString &loaderKind) {
    HmclVersionListService service(HmclDownloadProvider::fromSource(source));
    QJsonObject out = service.loaderMetadata(gameVersion, loaderKind);
    if ((loaderKind == "fabric" || loaderKind.isEmpty()) && out.value("fabricLoaders").toArray().isEmpty())
        out.insert("fabricLoaders", fallbackFabricLoaders());
    if ((loaderKind == "quilt" || loaderKind.isEmpty()) && out.value("quiltLoaders").toArray().isEmpty())
        out.insert("quiltLoaders", fallbackQuiltLoaders());
    if (loaderKind == "forge" && out.value("forgeInstallers").toArray().isEmpty())
        out.insert("forgeInstallers", fallbackForgeInstallers(gameVersion));
    if (loaderKind == "neoforge" && out.value("neoforgeInstallers").toArray().isEmpty())
        out.insert("neoforgeInstallers", fallbackForgeInstallers(gameVersion));
    return out;
}

void DownloadService::startInstall(const QString &source, const QString &gameVersion, const QString &loaderKind, const QString &loaderVersion) {
    m_installer.start(source, gameVersion, loaderKind, loaderVersion);
}

QJsonObject DownloadService::pollTask() {
    return m_installer.task();
}

void DownloadService::cancel() {
    m_installer.cancel();
}

QJsonObject DownloadService::idleDownloadTask() const {
    return QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 0}, {"title", "空闲"}, {"message", "还没有下载任务。"}, {"totalFiles", 0}, {"finishedFiles", 0}, {"totalBytes", 0}, {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0}, {"status", "idle"}};
}

QJsonObject DownloadService::finishedDownloadTask(const QString &message) const {
    return QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 100}, {"title", "安装完成"}, {"message", message}, {"totalFiles", 1}, {"finishedFiles", 1}, {"totalBytes", 0}, {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0}, {"status", "finished"}};
}
