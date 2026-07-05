#pragma once

#include <QJsonObject>
#include <QString>

class DownloadService {
public:
    QJsonObject refreshCatalog(const QString &source);
    QJsonObject loaderMetadata(const QString &source, const QString &gameVersion, const QString &loaderKind);
    QJsonObject installVersion(const QString &source, const QString &gameVersion, const QString &loaderKind, const QString &loaderVersion);
    QJsonObject idleDownloadTask() const;
    QJsonObject finishedDownloadTask(const QString &message) const;

private:
    QByteArray httpGet(const QUrl &url, int timeoutMs = 12000) const;
    QJsonObject fallbackCatalog() const;
    QJsonArray fallbackFabricLoaders() const;
    QJsonArray fallbackQuiltLoaders() const;
    QJsonArray fallbackForgeInstallers(const QString &gameVersion) const;
};
