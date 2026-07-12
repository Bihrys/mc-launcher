#include "download/hmcl/VersionListService.h"

#include "core/LauncherPaths.h"
#include "logging/AppLogger.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QTimer>

#include <utility>

namespace {

QString neoGameVersionFromArtifactVersion(const QString &version) {
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

QString metadataCacheRoot() {
    const QString root = LauncherPaths::cacheDir() + "/metadata";
    LauncherPaths::ensureDir(root);
    return root;
}

QString catalogSnapshotPath() {
    return metadataCacheRoot() + "/minecraft-version-catalog-v2.json";
}

QJsonObject readCatalogSnapshot() {
    QFile file(catalogSnapshotPath());
    if (!file.open(QIODevice::ReadOnly)) return {};
    QJsonParseError error{};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) return {};
    const QJsonObject catalog = document.object();
    return catalog.value("gameVersions").toArray().isEmpty() ? QJsonObject{} : catalog;
}

void writeCatalogSnapshot(const QJsonObject &catalog) {
    if (catalog.value("gameVersions").toArray().isEmpty()) return;
    QSaveFile file(catalogSnapshotPath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    file.write(QJsonDocument(catalog).toJson(QJsonDocument::Compact));
    file.commit();
}

QString cacheKeyForUrl(const QUrl &url) {
    const QByteArray encoded = url.toEncoded(QUrl::FullyEncoded);
    return QString::fromLatin1(QCryptographicHash::hash(encoded, QCryptographicHash::Sha1).toHex());
}

QString dataPathForUrl(const QUrl &url) {
    return metadataCacheRoot() + "/" + cacheKeyForUrl(url) + ".json";
}

QString metaPathForUrl(const QUrl &url) {
    return metadataCacheRoot() + "/" + cacheKeyForUrl(url) + ".meta.json";
}

QJsonObject readMeta(const QUrl &url) {
    QFile file(metaPathForUrl(url));
    if (!file.open(QIODevice::ReadOnly)) return {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    return document.isObject() ? document.object() : QJsonObject{};
}

void writeCache(const QUrl &url, const QByteArray &data, QNetworkReply *reply) {
    QSaveFile dataFile(dataPathForUrl(url));
    if (dataFile.open(QIODevice::WriteOnly)) {
        dataFile.write(data);
        dataFile.commit();
    }

    QJsonObject meta{
        {"url", url.toString(QUrl::FullyEncoded)},
        {"savedAt", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
        {"etag", QString::fromLatin1(reply->rawHeader("ETag"))},
        {"lastModified", QString::fromLatin1(reply->rawHeader("Last-Modified"))}
    };
    QSaveFile metaFile(metaPathForUrl(url));
    if (metaFile.open(QIODevice::WriteOnly)) {
        metaFile.write(QJsonDocument(meta).toJson(QJsonDocument::Compact));
        metaFile.commit();
    }
}

QJsonObject catalogFromManifest(const QJsonObject &manifest) {
    if (manifest.isEmpty()) return {};

    QJsonArray versions;
    const QJsonArray input = manifest.value("versions").toArray();
    for (int i = 0; i < input.size(); ++i) {
        const QJsonObject item = input.at(i).toObject();
        const QString id = item.value("id").toString();
        if (id.isEmpty()) continue;
        versions.append(QJsonObject{{"id", id},
                                    {"versionType", item.value("type").toString()},
                                    {"releaseTime", item.value("releaseTime").toString()}});
    }
    if (versions.isEmpty()) return {};

    const QJsonObject latest = manifest.value("latest").toObject();
    return QJsonObject{{"latestRelease", latest.value("release").toString()},
                       {"latestSnapshot", latest.value("snapshot").toString()},
                       {"gameVersions", versions},
                       {"fabricLoaders", QJsonArray{}},
                       {"quiltLoaders", QJsonArray{}},
                       {"forgeInstallers", QJsonArray{}},
                       {"neoforgeInstallers", QJsonArray{}},
                       {"optifineInstallers", QJsonArray{}},
                       {"liteloaderInstallers", QJsonArray{}}};
}

} // namespace

HmclVersionListService::HmclVersionListService(HmclDownloadProvider provider)
    : m_provider(std::move(provider)) {}

QByteArray HmclVersionListService::cachedBytesFor(const QUrl &url) const {
    QFile file(dataPathForUrl(url));
    if (!file.open(QIODevice::ReadOnly)) return {};
    return file.readAll();
}

QByteArray HmclVersionListService::httpGetFirst(const QList<QUrl> &urls, int timeoutMs) const {
    QNetworkAccessManager manager;
    for (const QUrl &url : urls) {
        if (!url.isValid()) continue;
        const QString safeUrl = url.toString(QUrl::RemoveQuery | QUrl::RemoveFragment);
        const QJsonObject cacheMeta = readMeta(url);

        AppLogger::info("download.metadata", "request_started", QString(), {
            {"url", safeUrl}, {"hasCache", QFileInfo::exists(dataPathForUrl(url))}
        });

        QNetworkRequest req(url);
        req.setRawHeader("User-Agent", "mc-launcher-qt-cpp/0.1 HMCL-download-port");
        const QString etag = cacheMeta.value("etag").toString();
        const QString lastModified = cacheMeta.value("lastModified").toString();
        if (!etag.isEmpty()) req.setRawHeader("If-None-Match", etag.toLatin1());
        if (!lastModified.isEmpty()) req.setRawHeader("If-Modified-Since", lastModified.toLatin1());
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

        const bool timedOut = !timer.isActive();
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QString errorText = reply->errorString();

        if (!timedOut && httpStatus == 304) {
            const QByteArray cached = cachedBytesFor(url);
            reply->deleteLater();
            if (!cached.isEmpty()) {
                AppLogger::info("download.metadata", "cache_revalidated", QString(), {
                    {"url", safeUrl}, {"httpStatus", httpStatus},
                    {"bytes", static_cast<double>(cached.size())}
                });
                return cached;
            }
        }

        if (!timedOut && reply->error() == QNetworkReply::NoError && reply->isReadable()) {
            const QByteArray data = reply->readAll();
            if (!data.isEmpty()) {
                writeCache(url, data, reply);
                reply->deleteLater();
                AppLogger::info("download.metadata", "request_finished", QString(), {
                    {"url", safeUrl}, {"httpStatus", httpStatus},
                    {"bytes", static_cast<double>(data.size())}, {"cached", true}
                });
                return data;
            }
        } else if (timedOut && !reply->isFinished()) {
            reply->abort();
        }

        AppLogger::warning("download.metadata",
                           timedOut ? "request_timed_out" : "request_failed",
                           errorText,
                           {{"url", safeUrl}, {"httpStatus", httpStatus},
                            {"timeoutMs", timeoutMs}});
        reply->deleteLater();
    }

    // HMCL falls back to cached metadata when every provider fails. Do the same
    // instead of turning a transient network failure into an empty page.
    for (const QUrl &url : urls) {
        const QByteArray cached = cachedBytesFor(url);
        if (!cached.isEmpty()) {
            AppLogger::warning("download.metadata", "stale_cache_used", QString(), {
                {"url", url.toString(QUrl::RemoveQuery | QUrl::RemoveFragment)},
                {"bytes", static_cast<double>(cached.size())}
            });
            return cached;
        }
    }
    return {};
}

QJsonObject HmclVersionListService::getObject(const QList<QUrl> &urls, bool *requestOk) const {
    if (requestOk) *requestOk = false;
    const QByteArray data = httpGetFirst(urls);
    if (data.isEmpty()) return {};
    QJsonParseError error{};
    const QJsonDocument document = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) {
        AppLogger::warning("download.metadata", "json_object_parse_failed", error.errorString(), {
            {"bytes", static_cast<double>(data.size())}
        });
        return {};
    }
    if (requestOk) *requestOk = true;
    return document.object();
}

QJsonArray HmclVersionListService::getArray(const QList<QUrl> &urls, bool *requestOk) const {
    if (requestOk) *requestOk = false;
    const QByteArray data = httpGetFirst(urls);
    if (data.isEmpty()) return {};
    QJsonParseError error{};
    const QJsonDocument document = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError || !document.isArray()) {
        AppLogger::warning("download.metadata", "json_array_parse_failed", error.errorString(), {
            {"bytes", static_cast<double>(data.size())}
        });
        return {};
    }
    if (requestOk) *requestOk = true;
    return document.array();
}

QJsonObject HmclVersionListService::cachedCatalog() const {
    // A provider-independent parsed snapshot gives HMCL-like instant entry
    // even after the user switches between official/balanced/mirror sources.
    const QJsonObject snapshot = readCatalogSnapshot();
    if (!snapshot.isEmpty()) {
        AppLogger::info("download.metadata", "catalog_snapshot_loaded", QString(), {
            {"path", catalogSnapshotPath()},
            {"versions", snapshot.value("gameVersions").toArray().size()}
        });
        return snapshot;
    }

    for (const QUrl &url : m_provider.versionListUrls()) {
        const QByteArray data = cachedBytesFor(url);
        if (data.isEmpty()) continue;
        QJsonParseError error{};
        const QJsonDocument document = QJsonDocument::fromJson(data, &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) continue;
        const QJsonObject catalog = catalogFromManifest(document.object());
        if (!catalog.isEmpty()) {
            writeCatalogSnapshot(catalog);
            AppLogger::info("download.metadata", "catalog_cache_loaded", QString(), {
                {"url", url.toString(QUrl::RemoveQuery | QUrl::RemoveFragment)},
                {"versions", catalog.value("gameVersions").toArray().size()},
                {"bytes", static_cast<double>(data.size())}
            });
            return catalog;
        }
    }
    return {};
}

QJsonArray HmclVersionListService::fabricLoaders(bool *requestOk) const {
    const QJsonArray raw = getArray(m_provider.candidatesFor("https://meta.fabricmc.net/v2/versions/loader"), requestOk);
    QJsonArray out;
    for (const QJsonValue &v : raw) {
        const QJsonObject o = v.toObject();
        const QString version = o.value("version").toString();
        if (version.isEmpty()) continue;
        out.append(QJsonObject{{"version", version}, {"stable", o.value("stable").toBool()}});
    }
    return out;
}

QJsonArray HmclVersionListService::fabricApiVersions(const QString &gameVersion,
                                                      bool *requestOk) const {
    // Exact HMCL FabricAPIVersionList source: Modrinth project P7dR8mSH.
    // Use both the project id and slug endpoints. Some mirrors only implement
    // one form, while the official API accepts both.
    QList<QUrl> urls;
    auto appendUnique = [&urls](const QList<QUrl> &values) {
        for (const QUrl &url : values) {
            if (url.isValid() && !urls.contains(url)) urls.append(url);
        }
    };
    const QString encodedGame = QString::fromLatin1(
        QUrl::toPercentEncoding(QStringLiteral("[\"%1\"]").arg(gameVersion)));
    const QString encodedLoaders = QStringLiteral("%5B%22fabric%22%5D");
    const QString filteredQuery = QStringLiteral(
        "?game_versions=%1&loaders=%2&include_changelog=false")
                                      .arg(encodedGame, encodedLoaders);
    // Ask Modrinth for just the selected Minecraft version first. This keeps
    // the response small enough for slower BMCLAPI/Modrinth mirrors and is
    // equivalent to HMCL's repository-side filtering.
    appendUnique(m_provider.candidatesFor(
        QStringLiteral("https://api.modrinth.com/v2/project/P7dR8mSH/version") + filteredQuery));
    appendUnique(m_provider.candidatesFor(
        QStringLiteral("https://api.modrinth.com/v2/project/fabric-api/version") + filteredQuery));
    // Compatibility fallbacks for mirrors that do not support filter query
    // parameters or only recognize the project id form.
    appendUnique(m_provider.candidatesFor(
        QStringLiteral("https://api.modrinth.com/v2/project/P7dR8mSH/version?include_changelog=false")));
    appendUnique(m_provider.candidatesFor(
        QStringLiteral("https://api.modrinth.com/v2/project/fabric-api/version?include_changelog=false")));
    appendUnique(m_provider.candidatesFor(
        QStringLiteral("https://api.modrinth.com/v2/project/P7dR8mSH/version")));

    bool ok = false;
    const QJsonArray versions = getArray(urls, &ok);
    if (requestOk) *requestOk = ok;
    if (!ok) return {};

    QJsonArray out;
    for (const QJsonValue &value : versions) {
        const QJsonObject version = value.toObject();
        const QJsonArray games = version.value("game_versions").toArray();
        bool supportsGame = false;
        for (const QJsonValue &game : games) {
            if (game.toString() == gameVersion) {
                supportsGame = true;
                break;
            }
        }
        if (!supportsGame) continue;

        QJsonObject selectedFile;
        const QJsonArray files = version.value("files").toArray();
        for (const QJsonValue &fileValue : files) {
            const QJsonObject file = fileValue.toObject();
            if (selectedFile.isEmpty() || file.value("primary").toBool(false)) {
                selectedFile = file;
                if (file.value("primary").toBool(false)) break;
            }
        }
        const QString url = selectedFile.value("url").toString();
        const QString versionNumber = version.value("version_number").toString();
        if (url.isEmpty() || versionNumber.isEmpty()) continue;

        const QJsonObject hashes = selectedFile.value("hashes").toObject();
        out.append(QJsonObject{
            {"version", versionNumber},
            {"fullVersion", version.value("name").toString(versionNumber)},
            {"releaseTime", version.value("date_published").toString()},
            {"fileUrl", url},
            {"fileName", selectedFile.value("filename").toString(
                 QStringLiteral("fabric-api-%1.jar").arg(versionNumber))},
            {"sha1", hashes.value("sha1").toString()},
            {"sha512", hashes.value("sha512").toString()},
            {"size", selectedFile.value("size").toDouble()},
            {"stable", version.value("version_type").toString() == QStringLiteral("release")}
        });
    }

    AppLogger::info("download.metadata", "fabric_api_versions_loaded", QString(), {
        {"gameVersion", gameVersion}, {"count", out.size()}
    });
    return out;
}

QJsonArray HmclVersionListService::quiltLoaders(bool *requestOk) const {
    const QJsonArray raw = getArray(m_provider.candidatesFor("https://meta.quiltmc.org/v3/versions/loader"), requestOk);
    QJsonArray out;
    for (const QJsonValue &v : raw) {
        const QJsonObject o = v.toObject();
        const QString version = o.value("version").toString();
        if (version.isEmpty()) continue;
        out.append(QJsonObject{{"version", version}, {"stable", o.value("stable").toBool(true)}});
    }
    return out;
}

QJsonArray HmclVersionListService::forgeInstallers(const QString &gameVersion, bool *requestOk) const {
    const QJsonArray raw = getArray({QUrl(QString("https://bmclapi2.bangbang93.com/forge/minecraft/%1").arg(gameVersion))}, requestOk);
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

QJsonArray HmclVersionListService::neoForgeInstallers(const QString &gameVersion, bool *requestOk) const {
    QJsonArray out;
    bool primaryOk = false;
    const QJsonObject obj = getObject(m_provider.candidatesFor("https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge"), &primaryOk);
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

    bool legacyOk = false;
    if (gameVersion == "1.20.1") {
        const QJsonObject oldObj = getObject(
            m_provider.candidatesFor("https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/forge"),
            &legacyOk);
        const QJsonArray oldVersions = oldObj.value("versions").toArray();
        for (const QJsonValue &v : oldVersions) {
            const QString version = v.isString()
                ? v.toString() : v.toObject().value("version").toString();
            if (!version.isEmpty()) {
                out.append(QJsonObject{{"loaderVersion", version},
                                       {"gameVersion", gameVersion},
                                       {"releaseTime", "NeoForge legacy"}});
            }
        }
    }
    if (requestOk) *requestOk = primaryOk || legacyOk;
    return out;
}

QJsonArray HmclVersionListService::optiFineInstallers(const QString &gameVersion) const {
    Q_UNUSED(gameVersion)
    return emptyArray();
}

QJsonArray HmclVersionListService::liteLoaderInstallers(const QString &gameVersion) const {
    Q_UNUSED(gameVersion)
    return emptyArray();
}

QJsonObject HmclVersionListService::refreshCatalog() const {
    bool manifestOk = false;
    const QJsonObject manifest = getObject(m_provider.versionListUrls(), &manifestOk);
    if (!manifestOk) return {};
    const QJsonObject catalog = catalogFromManifest(manifest);
    writeCatalogSnapshot(catalog);
    return catalog;
}

QJsonObject HmclVersionListService::loaderMetadata(const QString &gameVersion,
                                                   const QString &loaderKind) const {
    QJsonObject out{{"loaderKind", loaderKind}};
    bool ok = true;

    if (loaderKind.isEmpty() || loaderKind == "fabric") {
        bool requestOk = false;
        const QJsonArray values = fabricLoaders(&requestOk);
        if (!requestOk) ok = false;
        out.insert("fabricLoaders", values);
    }
    if (loaderKind.isEmpty() || loaderKind == "fabric-api") {
        bool requestOk = false;
        const QJsonArray values = fabricApiVersions(gameVersion, &requestOk);
        if (!requestOk) ok = false;
        out.insert("fabricApiVersions", values);
    }
    if (loaderKind.isEmpty() || loaderKind == "quilt") {
        bool requestOk = false;
        const QJsonArray values = quiltLoaders(&requestOk);
        if (!requestOk) ok = false;
        out.insert("quiltLoaders", values);
    }
    if (loaderKind.isEmpty() || loaderKind == "forge") {
        bool requestOk = false;
        const QJsonArray values = forgeInstallers(gameVersion, &requestOk);
        if (!requestOk) ok = false;
        out.insert("forgeInstallers", values);
    }
    if (loaderKind.isEmpty() || loaderKind == "neoforge") {
        bool requestOk = false;
        const QJsonArray values = neoForgeInstallers(gameVersion, &requestOk);
        if (!requestOk) ok = false;
        out.insert("neoforgeInstallers", values);
    }
    if (loaderKind.isEmpty() || loaderKind == "optifine")
        out.insert("optifineInstallers", optiFineInstallers(gameVersion));
    if (loaderKind.isEmpty() || loaderKind == "liteloader")
        out.insert("liteloaderInstallers", liteLoaderInstallers(gameVersion));

    return ok ? out : QJsonObject{};
}
