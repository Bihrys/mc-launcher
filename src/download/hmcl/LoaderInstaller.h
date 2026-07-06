#pragma once

#include "download/hmcl/DownloadProvider.h"

#include <QJsonObject>
#include <QString>
#include <functional>

class Downloader;

// Native C++ port of the simple HMCL loader installers. Fabric and Quilt are
// fully metadata-driven and do not need external Java processors; their install
// logic is implemented here by creating a version patch that inherits from the
// vanilla version and downloading the loader libraries.
class HmclLoaderInstaller {
public:
    using StatusCallback = std::function<void(const QString &message, int percent)>;

    static bool install(Downloader *downloader,
                        const HmclDownloadProvider &provider,
                        const QString &gameVersion,
                        const QString &loaderKind,
                        const QString &loaderVersion,
                        QString *outVersionId,
                        QString *errorMessage,
                        const StatusCallback &statusCallback = {});

    static QString versionIdFor(const QString &gameVersion,
                                const QString &loaderKind,
                                const QString &loaderVersion);

private:
    static bool installFabricLike(Downloader *downloader,
                                  const HmclDownloadProvider &provider,
                                  const QString &gameVersion,
                                  const QString &loaderKind,
                                  const QString &loaderVersion,
                                  QString *outVersionId,
                                  QString *errorMessage,
                                  const StatusCallback &statusCallback);
};
