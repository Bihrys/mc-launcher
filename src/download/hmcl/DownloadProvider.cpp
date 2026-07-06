#include "download/hmcl/DownloadProvider.h"

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
    const QString s = source.trimmed().toLower();
    if (s.contains("bmcl") || s.contains("mirror") || s.contains("china") || s == "bmclapi") {
        return HmclDownloadProvider(Kind::BMCLAPI);
    }
    // HMCL also has an AutoDownloadProvider. For this C++ port, "auto" keeps
    // Mojang as the canonical source and every injected URL can still be tried
    // by selecting BMCLAPI from settings/front-end later.
    return HmclDownloadProvider(Kind::Mojang);
}

int HmclDownloadProvider::concurrency() const {
    if (m_kind == Kind::Mojang) return 6;
    const int cores = QThread::idealThreadCount() > 0 ? QThread::idealThreadCount() : 4;
    return qMax(cores * 2, 6);
}

QList<QUrl> HmclDownloadProvider::versionListUrls() const {
    if (m_kind == Kind::BMCLAPI)
        return {QUrl(m_apiRoot + "/mc/game/version_manifest_v2.json"),
                QUrl(m_apiRoot + "/mc/game/version_manifest.json")};
    return {QUrl("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"),
            QUrl("https://piston-meta.mojang.com/mc/game/version_manifest.json")};
}

QList<QUrl> HmclDownloadProvider::assetObjectCandidates(const QString &assetLocation) const {
    if (m_kind == Kind::BMCLAPI)
        return {QUrl(m_apiRoot + "/assets/" + assetLocation),
                QUrl("https://resources.download.minecraft.net/" + assetLocation)};
    return {QUrl("https://resources.download.minecraft.net/" + assetLocation)};
}

QString HmclDownloadProvider::replaceByTable(const QString &baseUrl, bool fallbackTable) const {
    return applyReplacement(baseUrl, fallbackTable ? fallbackReplacements() : primaryReplacements(m_apiRoot));
}

QString HmclDownloadProvider::injectUrl(const QString &baseUrl) const {
    if (m_kind == Kind::Mojang) return baseUrl;
    const QString replaced = replaceByTable(baseUrl, false);
    return replaced.isEmpty() ? baseUrl : replaced;
}

QList<QUrl> HmclDownloadProvider::candidatesFor(const QString &baseUrl) const {
    if (baseUrl.trimmed().isEmpty()) return {};
    if (m_kind == Kind::Mojang) return {QUrl(baseUrl)};

    const QString primary = replaceByTable(baseUrl, false);
    if (!primary.isEmpty()) return {QUrl(primary), QUrl(baseUrl)};

    const QString fallback = replaceByTable(baseUrl, true);
    if (!fallback.isEmpty()) return {QUrl(baseUrl), QUrl(fallback)};

    return {QUrl(baseUrl)};
}
