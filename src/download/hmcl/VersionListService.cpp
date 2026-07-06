#include "download/hmcl/VersionListService.h"

#include "core/JsonUtil.h"

#include <QEventLoop>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>

#include <utility>

namespace {

QString neoGameVersionFromArtifactVersion(const QString &version) {
    // Port of HMCL NeoForgeOfficialVersionList version inference, simplified to
    // the public version scheme used by current NeoForge metadata.
    // Examples: 20.4.237 -> 1.20.4, 21.1.200 -> 1.21.1, 1.20.1-47.1.106 -> 1.20.1.
    if (version.startsWith("1.")) return version.section('-', 0, 0);
    const QStringList parts = version.split(QRegularExpression("[.+-]"), Qt::SkipEmptyParts);
    if (parts.size() < 2) return QString();
    bool okMajor = false;
    const int major = parts.at(0).toInt(&okMajor);
    if (!okMajor) return QString();
    if (major >= 20) {
        if (parts.size() >= 2) return QString("1.%1.%2").arg(major).arg(parts.at(1));
        return QString("1.%1").arg(major);
    }
    return QString();
}

QJsonArray emptyArray() { return QJsonArray{}; }

} // namespace

HmclVersionListService::HmclVersionListService(HmclDownloadProvider provider)
    : m_provider(std::move(provider)) {}

QByteArray HmclVersionListService::httpGetFirst(const QList<QUrl> &urls, int timeoutMs) const {
    QNetworkAccessManager manager;
    for (const QUrl &url : urls) {
        if (!url.isValid()) continue;
        QNetworkRequest req(url);
        req.setRawHeader("User-Agent", "mc-launcher-qt-cpp/0.1 HMCL-download-port");
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
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
            if (!data.isEmpty()) return data;
        } else {
            reply->abort();
        }
        reply->deleteLater();
    }
    return {};
}

QJsonObject HmclVersionListService::getObject(const QList<QUrl> &urls) const {
    const QByteArray data = httpGetFirst(urls);
    if (data.isEmpty()) return {};
    return JsonUtil::objectFromString(QString::fromUtf8(data), {});
}

QJsonArray HmclVersionListService::getArray(const QList<QUrl> &urls) const {
    const QByteArray data = httpGetFirst(urls);
    if (data.isEmpty()) return {};
    QJsonParseError err{};
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) return {};
    return doc.array();
}

QJsonArray HmclVersionListService::fabricLoaders() const {
    const QJsonArray raw = getArray(m_provider.candidatesFor("https://meta.fabricmc.net/v2/versions/loader"));
    QJsonArray out;
    for (const QJsonValue &v : raw) {
        const QJsonObject o = v.toObject();
        const QString version = o.value("version").toString();
        if (version.isEmpty()) continue;
        out.append(QJsonObject{{"version", version}, {"stable", o.value("stable").toBool()}});
    }
    return out;
}

QJsonArray HmclVersionListService::quiltLoaders() const {
    const QJsonArray raw = getArray(m_provider.candidatesFor("https://meta.quiltmc.org/v3/versions/loader"));
    QJsonArray out;
    for (const QJsonValue &v : raw) {
        const QJsonObject o = v.toObject();
        const QString version = o.value("version").toString();
        if (version.isEmpty()) continue;
        out.append(QJsonObject{{"version", version}, {"stable", o.value("stable").toBool(true)}});
    }
    return out;
}

QJsonArray HmclVersionListService::forgeInstallers(const QString &gameVersion) const {
    // HMCL has two Forge lists: hmcl.glavo.site metadata and BMCLAPI. The BMCLAPI
    // endpoint is compact and already returns installer artifacts for one MC
    // version, so this C++ port uses it for the page-level per-version query.
    const QJsonArray raw = getArray({QUrl(QString("https://bmclapi2.bangbang93.com/forge/minecraft/%1").arg(gameVersion))});
    QJsonArray out;
    for (const QJsonValue &v : raw) {
        const QJsonObject o = v.toObject();
        const QString forgeVersion = o.value("version").toString();
        if (forgeVersion.isEmpty()) continue;
        bool hasInstaller = true;
        const QJsonArray files = o.value("files").toArray();
        if (!files.isEmpty()) {
            hasInstaller = false;
            for (const QJsonValue &fv : files) {
                const QJsonObject f = fv.toObject();
                if (f.value("category").toString().contains("installer", Qt::CaseInsensitive)
                    || f.value("format").toString().contains("jar", Qt::CaseInsensitive)) {
                    hasInstaller = true;
                    break;
                }
            }
        }
        if (!hasInstaller) continue;
        out.append(QJsonObject{{"loaderVersion", forgeVersion},
                               {"gameVersion", gameVersion},
                               {"releaseTime", o.value("modified").toString(o.value("date").toString())}});
    }
    return out;
}

QJsonArray HmclVersionListService::neoForgeInstallers(const QString &gameVersion) const {
    QJsonArray out;
    const QJsonObject obj = getObject(m_provider.candidatesFor("https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge"));
    QJsonArray versions;
    if (obj.value("versions").isArray()) versions = obj.value("versions").toArray();
    else if (obj.value("data").isArray()) versions = obj.value("data").toArray();

    for (const QJsonValue &v : versions) {
        const QString version = v.isString() ? v.toString() : v.toObject().value("version").toString();
        if (version.isEmpty()) continue;
        if (neoGameVersionFromArtifactVersion(version) != gameVersion) continue;
        out.append(QJsonObject{{"loaderVersion", version},
                               {"gameVersion", gameVersion},
                               {"releaseTime", QStringLiteral("NeoForge")}});
    }

    // NeoForge 1.20.1 used the old net.neoforged:forge coordinate.
    const QJsonObject oldObj = getObject(m_provider.candidatesFor("https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/forge"));
    QJsonArray oldVersions = oldObj.value("versions").toArray();
    if (gameVersion == "1.20.1") {
        for (const QJsonValue &v : oldVersions) {
            const QString version = v.isString() ? v.toString() : v.toObject().value("version").toString();
            if (!version.isEmpty()) out.append(QJsonObject{{"loaderVersion", version}, {"gameVersion", gameVersion}, {"releaseTime", "NeoForge legacy"}});
        }
    }
    return out;
}

QJsonArray HmclVersionListService::optiFineInstallers(const QString &gameVersion) const {
    Q_UNUSED(gameVersion)
    // HMCL only obtains OptiFine through BMCLAPI metadata. The current QML page
    // marks OptiFine as disabled, so keep the shape ready for later UI enabling.
    return emptyArray();
}

QJsonArray HmclVersionListService::liteLoaderInstallers(const QString &gameVersion) const {
    Q_UNUSED(gameVersion)
    return emptyArray();
}

QJsonObject HmclVersionListService::refreshCatalog() const {
    QJsonObject manifest = getObject(m_provider.versionListUrls());
    if (manifest.isEmpty()) return {};

    QJsonArray versions;
    const QJsonArray in = manifest.value("versions").toArray();
    for (int i = 0; i < in.size() && i < 300; ++i) {
        const QJsonObject item = in.at(i).toObject();
        versions.append(QJsonObject{{"id", item.value("id").toString()},
                                    {"versionType", item.value("type").toString()},
                                    {"releaseTime", item.value("releaseTime").toString()}});
    }

    const QJsonObject latest = manifest.value("latest").toObject();
    return QJsonObject{{"latestRelease", latest.value("release").toString()},
                       {"latestSnapshot", latest.value("snapshot").toString()},
                       {"gameVersions", versions},
                       {"fabricLoaders", fabricLoaders()},
                       {"quiltLoaders", quiltLoaders()},
                       {"forgeInstallers", QJsonArray{}},
                       {"neoforgeInstallers", QJsonArray{}},
                       {"optifineInstallers", QJsonArray{}},
                       {"liteloaderInstallers", QJsonArray{}}};
}

QJsonObject HmclVersionListService::loaderMetadata(const QString &gameVersion, const QString &loaderKind) const {
    QJsonObject out{{"loaderKind", loaderKind}};
    if (loaderKind.isEmpty() || loaderKind == "fabric") out.insert("fabricLoaders", fabricLoaders());
    if (loaderKind.isEmpty() || loaderKind == "quilt") out.insert("quiltLoaders", quiltLoaders());
    if (loaderKind.isEmpty() || loaderKind == "forge") out.insert("forgeInstallers", forgeInstallers(gameVersion));
    if (loaderKind.isEmpty() || loaderKind == "neoforge") out.insert("neoforgeInstallers", neoForgeInstallers(gameVersion));
    if (loaderKind.isEmpty() || loaderKind == "optifine") out.insert("optifineInstallers", optiFineInstallers(gameVersion));
    if (loaderKind.isEmpty() || loaderKind == "liteloader") out.insert("liteloaderInstallers", liteLoaderInstallers(gameVersion));
    return out;
}
