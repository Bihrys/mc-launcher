#include "download/DownloadService.h"

#include "download/hmcl/DownloadProvider.h"
#include "download/hmcl/VersionListService.h"

QJsonObject DownloadService::cachedCatalog(const QString &source) {
    HmclVersionListService service(HmclDownloadProvider::fromSource(source));
    return service.cachedCatalog();
}

QJsonObject DownloadService::refreshCatalog(const QString &source) {
    HmclVersionListService service(HmclDownloadProvider::fromSource(source));
    return service.refreshCatalog();
}

QJsonObject DownloadService::loaderMetadata(const QString &source,
                                            const QString &gameVersion,
                                            const QString &loaderKind) {
    HmclVersionListService service(HmclDownloadProvider::fromSource(source));
    return service.loaderMetadata(gameVersion, loaderKind);
}

void DownloadService::startInstall(const QString &source,
                                   const QString &gameVersion,
                                   const QString &instanceName,
                                   const QString &loaderKind,
                                   const QString &loaderVersion,
                                   const QString &addonsJson) {
    m_installer.start(source, gameVersion, instanceName, loaderKind, loaderVersion, addonsJson);
}

QJsonObject DownloadService::pollTask() {
    return m_installer.task();
}

void DownloadService::cancel() {
    m_installer.cancel();
}

QJsonObject DownloadService::idleDownloadTask() const {
    return QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 0},
                       {"title", "空闲"}, {"message", "还没有下载任务。"},
                       {"totalFiles", 0}, {"finishedFiles", 0}, {"totalBytes", 0},
                       {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0},
                       {"status", "idle"}};
}

QJsonObject DownloadService::finishedDownloadTask(const QString &message) const {
    return QJsonObject{{"active", false}, {"cancelled", false}, {"percent", 100},
                       {"title", "安装完成"}, {"message", message},
                       {"totalFiles", 1}, {"finishedFiles", 1}, {"totalBytes", 0},
                       {"downloadedBytes", 0}, {"currentFile", ""}, {"speed", 0},
                       {"status", "finished"}};
}
