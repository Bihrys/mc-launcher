#pragma once

#include <QJsonObject>
#include <QString>

#include "download/GameInstaller.h"

// UI-facing facade corresponding to HMCL's DownloadProvider + VersionList
// orchestration. Network failures are returned as empty payloads so the view can
// enter FAILED state; no fabricated versions are injected.
class DownloadService {
public:
    QJsonObject refreshCatalog(const QString &source);
    QJsonObject loaderMetadata(const QString &source,
                               const QString &gameVersion,
                               const QString &loaderKind);

    void startInstall(const QString &source,
                      const QString &gameVersion,
                      const QString &instanceName,
                      const QString &loaderKind,
                      const QString &loaderVersion);
    QJsonObject pollTask();
    void cancel();

    QJsonObject idleDownloadTask() const;
    QJsonObject finishedDownloadTask(const QString &message) const;

private:
    GameInstaller m_installer;
};
