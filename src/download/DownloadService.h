#pragma once

#include <QJsonObject>
#include <QString>

#include "download/GameInstaller.h"

class DownloadService {
public:
    QJsonObject refreshCatalog(const QString &source);
    QJsonObject loaderMetadata(const QString &source, const QString &gameVersion, const QString &loaderKind);

    // Async vanilla install pipeline (ported from HMCL GameInstallTask). Kicks
    // off a background worker; poll pollTask() until status is terminal.
    void startInstall(const QString &source, const QString &gameVersion, const QString &loaderKind, const QString &loaderVersion);
    QJsonObject pollTask();
    void cancel();

    QJsonObject idleDownloadTask() const;
    QJsonObject finishedDownloadTask(const QString &message) const;

private:
    QByteArray httpGet(const QUrl &url, int timeoutMs = 12000) const;
    QJsonObject fallbackCatalog() const;
    QJsonArray fallbackFabricLoaders() const;
    QJsonArray fallbackQuiltLoaders() const;
    QJsonArray fallbackForgeInstallers(const QString &gameVersion) const;

    GameInstaller m_installer;
};
