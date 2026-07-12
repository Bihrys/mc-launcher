#include "download/hmcl/DownloadProvider.h"

#include <QLocale>
#include <QPair>
#include <QThread>

#include <utility>

namespace {

using Replacement = QPair<QString, QString>;

QList<Replacement> primaryReplacements(const QString &apiRoot) {
    return {
        {"https://bmclapi2.bangbang93.com", apiRoot},
        {"https://launchermeta.mojang.com", apiRoot},
        {"https://piston-meta.mojang.com", apiRoot},
        {"https://piston-data.mojang.com", apiRoot},
        {"https://launcher.mojang.com", apiRoot},
        {"https://libraries.minecraft.net", apiRoot + "/libraries"},
        {"http://files.minecraftforge.net/maven", apiRoot + "/maven"},
        {"https://files.minecraftforge.net/maven", apiRoot + "/maven"},
        {"https://maven.minecraftforge.net", apiRoot + "/maven"},
        {"https://maven.neoforged.net/releases/", apiRoot + "/maven/"},
        {"http://dl.liteloader.com/versions/versions.json", apiRoot + "/maven/../versions.json"},
        {"http://dl.liteloader.com/versions", apiRoot + "/maven"},
        {"https://meta.fabricmc.net", apiRoot + "/fabric-meta"},
        {"https://maven.fabricmc.net", apiRoot + "/maven"},
        {"https://maven.quiltmc.org/repository/release", apiRoot + "/maven"},
        {"https://meta.quiltmc.org", apiRoot + "/quilt-meta"},
        {"https://authlib-injector.yushi.moe", apiRoot + "/mirrors/authlib-injector"},
        {"https://repo1.maven.org/maven2", "https://mirrors.cloud.tencent.com/nexus/repository/maven-public"},
        {"https://repo.maven.apache.org/maven2", "https://mirrors.cloud.tencent.com/nexus/repository/maven-public"},
        {"https://hmcl.glavo.site/metadata/cleanroom", "https://alist.8mi.tech/d/Glavo/HMCL/metadata/cleanroom"},
        {"https://hmcl.glavo.site/metadata/fmllibs", "https://alist.8mi.tech/d/Glavo/HMCL/metadata/fmllibs"},
        {"https://zkitefly.github.io/unlisted-versions-of-minecraft", "https://alist.8mi.tech/d/Glavo/HMCL/metadata/unlisted-versions-of-minecraft"},
    };
}

QList<Replacement> fallbackReplacements() {
    return {
        {"https://api.modrinth.com", "https://mod.mcimirror.top/modrinth"},
        {"https://cdn.modrinth.com", "https://mod.mcimirror.top"},
        {"https://api.curseforge.com", "https://mod.mcimirror.top/curseforge"},
        {"https://edge.forgecdn.net", "https://mod.mcimirror.top"},
    };
}

bool autoPrefersMirror() {
    // HMCL DEFAULT: mirror first in Mainland China, official first elsewhere.
    return QLocale::system().territory() == QLocale::China;
}

QString applyReplacement(const QString &baseUrl, const QList<Replacement> &table) {
    for (const Replacement &r : table) {
        if (baseUrl.startsWith(r.first)) {
            QString suffix = baseUrl.mid(r.first.size());
            QString target = r.second;
            if (target.endsWith('/') && suffix.startsWith('/')) suffix.remove(0, 1);
            return target + suffix;
        }
    }
    return QString();
}

} // namespace

HmclDownloadProvider::HmclDownloadProvider(Kind kind, QString apiRoot)
    : m_kind(kind), m_apiRoot(std::move(apiRoot)) {}

HmclDownloadProvider HmclDownloadProvider::fromSource(const QString &source) {
    // HMCL DownloadSource: DEFAULT / OFFICIAL / MIRROR.
    // The QML settings serialize them as balanced / official / bmclapi.
    const QString s = source.trimmed().toLower();
    if (s.isEmpty() || s == "auto" || s == "balanced" || s == "default")
        return HmclDownloadProvider(Kind::Auto);
    if (s == "official" || s == "mojang")
        return HmclDownloadProvider(Kind::Mojang);
    if (s == "bmclapi" || s == "mirror" || s.contains("bmcl") || s.contains("china"))
        return HmclDownloadProvider(Kind::BMCLAPI);
    return HmclDownloadProvider(Kind::Auto);
}

QString HmclDownloadProvider::id() const {
    switch (m_kind) {
    case Kind::Auto: return QStringLiteral("auto");
    case Kind::BMCLAPI: return QStringLiteral("bmclapi");
    case Kind::Mojang: return QStringLiteral("mojang");
    }
    return QStringLiteral("auto");
}

int HmclDownloadProvider::concurrency() const {
    // Match HMCL FetchTask.DEFAULT_CONCURRENCY: CPU * 4, capped at 64.
    // Minecraft asset installation contains thousands of small files; a fixed
    // pool of six connections looks fast at first and then collapses during the
    // small-file tail because network latency dominates transfer time.
    const int cores = QThread::idealThreadCount() > 0 ? QThread::idealThreadCount() : 4;
    return qBound(4, cores * 4, 64);
}

QList<QUrl> HmclDownloadProvider::versionListUrls() const {
    const QUrl officialV2("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json");
    const QUrl officialV1("https://piston-meta.mojang.com/mc/game/version_manifest.json");
    const QUrl mirrorV2(m_apiRoot + "/mc/game/version_manifest_v2.json");
    const QUrl mirrorV1(m_apiRoot + "/mc/game/version_manifest.json");
    if (m_kind == Kind::BMCLAPI) return {mirrorV2, mirrorV1, officialV2, officialV1};
    if (m_kind == Kind::Auto) {
        return autoPrefersMirror()
                ? QList<QUrl>{mirrorV2, officialV2, mirrorV1, officialV1}
                : QList<QUrl>{officialV2, mirrorV2, officialV1, mirrorV1};
    }
    return {officialV2, officialV1};
}

QList<QUrl> HmclDownloadProvider::assetObjectCandidates(const QString &assetLocation) const {
    const QUrl official("https://resources.download.minecraft.net/" + assetLocation);
    const QUrl mirror(m_apiRoot + "/assets/" + assetLocation);
    if (m_kind == Kind::BMCLAPI) return {mirror, official};
    if (m_kind == Kind::Auto) return autoPrefersMirror() ? QList<QUrl>{mirror, official} : QList<QUrl>{official, mirror};
    return {official};
}

QString HmclDownloadProvider::replaceByTable(const QString &baseUrl, bool fallbackTable) const {
    return applyReplacement(baseUrl, fallbackTable ? fallbackReplacements() : primaryReplacements(m_apiRoot));
}

QString HmclDownloadProvider::injectUrl(const QString &baseUrl) const {
    if (m_kind != Kind::BMCLAPI) return baseUrl;
    const QString replaced = replaceByTable(baseUrl, false);
    return replaced.isEmpty() ? baseUrl : replaced;
}

QList<QUrl> HmclDownloadProvider::candidatesFor(const QString &baseUrl) const {
    if (baseUrl.trimmed().isEmpty()) return {};

    const QString primary = replaceByTable(baseUrl, false);
    const QString fallback = replaceByTable(baseUrl, true);
    QList<QUrl> urls;
    auto appendUnique = [&urls](const QString &value) {
        if (value.isEmpty()) return;
        const QUrl url(value);
        if (url.isValid() && !urls.contains(url)) urls.append(url);
    };

    if (m_kind == Kind::BMCLAPI) {
        appendUnique(primary);
        appendUnique(baseUrl);
        appendUnique(fallback);
    } else if (m_kind == Kind::Auto && autoPrefersMirror()) {
        appendUnique(primary);
        appendUnique(baseUrl);
        appendUnique(fallback);
    } else {
        appendUnique(baseUrl);
        if (m_kind == Kind::Auto) {
            appendUnique(primary);
            appendUnique(fallback);
        }
    }
    return urls;
}
