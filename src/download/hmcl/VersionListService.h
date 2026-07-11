#pragma once

#include "download/hmcl/DownloadProvider.h"

#include <QByteArray>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QUrl>

// C++ port of HMCL VersionList implementations used by the download page.
// Metadata responses use an HMCL-style disk cache with ETag/Last-Modified
// revalidation. The cached game catalog can be displayed immediately while a
// network refresh continues in the background.
class HmclVersionListService {
public:
    explicit HmclVersionListService(HmclDownloadProvider provider);

    QJsonObject cachedCatalog() const;
    QJsonObject refreshCatalog() const;
    QJsonObject loaderMetadata(const QString &gameVersion, const QString &loaderKind) const;

    QJsonArray fabricLoaders(bool *requestOk = nullptr) const;
    QJsonArray quiltLoaders(bool *requestOk = nullptr) const;
    QJsonArray forgeInstallers(const QString &gameVersion, bool *requestOk = nullptr) const;
    QJsonArray neoForgeInstallers(const QString &gameVersion, bool *requestOk = nullptr) const;
    QJsonArray optiFineInstallers(const QString &gameVersion) const;
    QJsonArray liteLoaderInstallers(const QString &gameVersion) const;

private:
    QByteArray httpGetFirst(const QList<QUrl> &urls, int timeoutMs = 15000) const;
    QByteArray cachedBytesFor(const QUrl &url) const;
    QJsonObject getObject(const QList<QUrl> &urls, bool *requestOk = nullptr) const;
    QJsonArray getArray(const QList<QUrl> &urls, bool *requestOk = nullptr) const;

    HmclDownloadProvider m_provider;
};
