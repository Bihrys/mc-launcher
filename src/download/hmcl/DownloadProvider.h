#pragma once

#include <QList>
#include <QString>
#include <QUrl>

// C++ port of HMCLCore download/DownloadProvider, MojangDownloadProvider and
// BMCLAPIDownloadProvider URL routing. The object is intentionally value-type so
// worker-thread install code can copy it freely.
class HmclDownloadProvider {
public:
    enum class Kind { Mojang, BMCLAPI };

    explicit HmclDownloadProvider(Kind kind = Kind::Mojang,
                                  QString apiRoot = QStringLiteral("https://bmclapi2.bangbang93.com"));

    static HmclDownloadProvider fromSource(const QString &source);

    Kind kind() const { return m_kind; }
    QString apiRoot() const { return m_apiRoot; }
    int concurrency() const;

    QList<QUrl> versionListUrls() const;
    QList<QUrl> assetObjectCandidates(const QString &assetLocation) const;
    QList<QUrl> candidatesFor(const QString &baseUrl) const;
    QString injectUrl(const QString &baseUrl) const;

private:
    QString replaceByTable(const QString &baseUrl, bool fallbackTable) const;

    Kind m_kind;
    QString m_apiRoot;
};
