#pragma once

#include "download/hmcl/DownloadProvider.h"

#include <QByteArray>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QUrl>

// C++ port of HMCL VersionList implementations used by the download page.
// It keeps the same output shape already consumed by HmclDownloadPage.qml.
class HmclVersionListService {
public:
    explicit HmclVersionListService(HmclDownloadProvider provider);

    QJsonObject refreshCatalog() const;
    QJsonObject loaderMetadata(const QString &gameVersion, const QString &loaderKind) const;

    QJsonArray fabricLoaders() const;
    QJsonArray quiltLoaders() const;
    QJsonArray forgeInstallers(const QString &gameVersion) const;
    QJsonArray neoForgeInstallers(const QString &gameVersion) const;
    QJsonArray optiFineInstallers(const QString &gameVersion) const;
    QJsonArray liteLoaderInstallers(const QString &gameVersion) const;

private:
    QByteArray httpGetFirst(const QList<QUrl> &urls, int timeoutMs = 15000) const;
    QJsonObject getObject(const QList<QUrl> &urls) const;
    QJsonArray getArray(const QList<QUrl> &urls) const;

    HmclDownloadProvider m_provider;
};
