#include "game/InstanceService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"
#include "game/VersionRules.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QHash>
#include <QJsonValue>
#include <QProcess>
#include <QSet>
#include <QDesktopServices>
#include <QUrl>

namespace {

QString shellQuote(const QString &value) {
    QString out = value;
    out.replace("'", "'\\''");
    return QString("\'") + out + QString("\'");
}

QJsonObject readVersionObjectById(const QString &versionId) {
    const QString path = LauncherPaths::versionsDir() + "/" + versionId + "/" + versionId + ".json";
    return JsonUtil::readObjectFile(path, {});
}

QJsonObject mergeVersionJson(const QJsonObject &parent, const QJsonObject &child) {
    if (parent.isEmpty()) return child;
    QJsonObject out = parent;
    for (auto it = child.begin(); it != child.end(); ++it) {
        if (it.key() == "libraries") {
            QJsonArray libs = parent.value("libraries").toArray();
            for (const QJsonValue &v : child.value("libraries").toArray()) libs.append(v);
            out.insert("libraries", libs);
        } else if (it.key() == "arguments") {
            QJsonObject args = parent.value("arguments").toObject();
            QJsonObject childArgs = child.value("arguments").toObject();
            if (childArgs.contains("game")) {
                QJsonArray merged = args.value("game").toArray();
                for (const QJsonValue &v : childArgs.value("game").toArray()) merged.append(v);
                args.insert("game", merged);
            }
            if (childArgs.contains("jvm")) {
                QJsonArray merged = args.value("jvm").toArray();
                for (const QJsonValue &v : childArgs.value("jvm").toArray()) merged.append(v);
                args.insert("jvm", merged);
            }
            out.insert("arguments", args);
        } else {
            out.insert(it.key(), it.value());
        }
    }
    return out;
}

QStringList stringOrArray(const QJsonValue &value) {
    QStringList out;
    if (value.isString()) {
        out << value.toString();
    } else if (value.isArray()) {
        for (const QJsonValue &v : value.toArray()) {
            if (v.isString()) out << v.toString();
        }
    }
    return out;
}

QString replaceLaunchPlaceholders(QString value, const QHash<QString, QString> &vars) {
    for (auto it = vars.begin(); it != vars.end(); ++it) {
        value.replace("${" + it.key() + "}", it.value());
    }
    return value;
}

QStringList parseArgumentList(const QJsonArray &array, const QHash<QString, QString> &vars) {
    QStringList out;
    for (const QJsonValue &v : array) {
        if (v.isString()) {
            out << replaceLaunchPlaceholders(v.toString(), vars);
        } else if (v.isObject()) {
            const QJsonObject obj = v.toObject();
            if (!VersionRules::allowedByRules(obj.value("rules").toArray())) continue;
            for (const QString &item : stringOrArray(obj.value("value"))) {
                out << replaceLaunchPlaceholders(item, vars);
            }
        }
    }
    return out;
}

QString buildClasspath(const QString &versionId, const QJsonObject &versionJson) {
    QStringList entries;
    QSet<QString> seen;
    const QString librariesRoot = LauncherPaths::minecraftDir() + "/libraries";
    for (const QJsonValue &v : versionJson.value("libraries").toArray()) {
        const QJsonObject lib = v.toObject();
        if (!VersionRules::allowedByRules(lib.value("rules").toArray())) continue;
        QString rel = lib.value("downloads").toObject().value("artifact").toObject().value("path").toString();
        if (rel.isEmpty()) rel = VersionRules::libraryPathFromName(lib.value("name").toString());
        if (rel.isEmpty()) continue;
        const QString abs = librariesRoot + "/" + rel;
        if (QFileInfo::exists(abs) && !seen.contains(abs)) {
            entries << abs;
            seen.insert(abs);
        }
    }
    const QString clientJar = LauncherPaths::versionsDir() + "/" + versionId + "/" + versionId + ".jar";
    if (QFileInfo::exists(clientJar)) entries << clientJar;
    return entries.join(":");
}

} // namespace

QString InstanceService::versionDir(const QString &versionId) const {
    return LauncherPaths::versionsDir() + "/" + versionId;
}

QString InstanceService::iconForVersion(const QString &versionId, const QString &type) const {
    Q_UNUSED(type)
    if (versionId.contains("fabric", Qt::CaseInsensitive)) return "fabric";
    if (versionId.contains("quilt", Qt::CaseInsensitive)) return "quilt";
    if (versionId.contains("neoforge", Qt::CaseInsensitive)) return "neoforge";
    if (versionId.contains("forge", Qt::CaseInsensitive)) return "forge";
    if (versionId.contains("optifine", Qt::CaseInsensitive)) return "optifine";
    return "grass";
}

QJsonObject InstanceService::readVersionJson(const QString &versionId) const {
    const QString path = versionDir(versionId) + "/" + versionId + ".json";
    return JsonUtil::readObjectFile(path, {});
}

QJsonArray InstanceService::scanVersions() const {
    QJsonArray arr;
    QDir dir(LauncherPaths::versionsDir());
    if (!dir.exists()) return arr;
    const auto entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QFileInfo &info : entries) {
        const QString id = info.fileName();
        const QJsonObject json = readVersionJson(id);
        const QString type = json.value("type").toString("release");
        const QString inherits = json.value("inheritsFrom").toString();
        const QString gameVersion = inherits.isEmpty() ? id : inherits;
        QString loaderSummary = "原版";
        if (id.contains("fabric", Qt::CaseInsensitive)) loaderSummary = "Fabric";
        else if (id.contains("quilt", Qt::CaseInsensitive)) loaderSummary = "Quilt";
        else if (id.contains("neoforge", Qt::CaseInsensitive)) loaderSummary = "NeoForge";
        else if (id.contains("forge", Qt::CaseInsensitive)) loaderSummary = "Forge";
        arr.append(QJsonObject{
            {"id", id}, {"title", id}, {"name", id}, {"subtitle", gameVersion}, {"tag", type},
            {"versionType", type}, {"gameVersion", gameVersion}, {"loaderSummary", loaderSummary},
            {"iconName", iconForVersion(id, type)}, {"selected", false}, {"canUpdate", false},
            {"path", info.absoluteFilePath()}
        });
    }
    return arr;
}

QJsonObject InstanceService::list() {
    const QJsonArray instances = scanVersions();
    QString selected;
    if (!instances.isEmpty()) selected = instances.first().toObject().value("id").toString();
    QJsonArray marked;
    for (int i = 0; i < instances.size(); ++i) {
        QJsonObject item = instances.at(i).toObject();
        item["selected"] = item.value("id").toString() == selected;
        marked.append(item);
    }
    QJsonArray profiles;
    profiles.append(QJsonObject{{"id", "default"}, {"name", "默认游戏目录"}, {"path", LauncherPaths::minecraftDir()}, {"selected", true}});
    return QJsonObject{{"instances", marked}, {"profiles", profiles}, {"selectedInstance", selected}};
}

QJsonObject InstanceService::installedVersions() {
    QJsonArray versions = scanVersions();
    for (int i = 0; i < versions.size(); ++i) {
        QJsonObject v = versions.at(i).toObject();
        v.insert("installed", true);
        versions[i] = v;
    }
    return QJsonObject{{"versions", versions}};
}

QJsonObject InstanceService::detail(const QString &versionId) {
    const QString id = versionId.trimmed();
    const QString dir = versionDir(id);
    QJsonObject json = readVersionJson(id);
    const QString inherits = json.value("inheritsFrom").toString();
    const QString gameVersion = inherits.isEmpty() ? id : inherits;
    const QString mainClass = json.value("mainClass").toString();
    QJsonArray folders;
    const QList<QPair<QString, QString>> map = {
        {"root", "版本目录"}, {"mods", "mods"}, {"resourcepacks", "resourcepacks"}, {"shaderpacks", "shaderpacks"}, {"saves", "saves"}, {"logs", "logs"}
    };
    for (auto pair : map) {
        QString sub = pair.first == "root" ? dir : LauncherPaths::minecraftDir() + "/" + pair.first;
        QDir d(sub);
        folders.append(QJsonObject{{"key", pair.first}, {"title", pair.second}, {"path", sub}, {"exists", d.exists()}, {"itemCount", d.exists() ? d.entryList(QDir::NoDotAndDotDot | QDir::AllEntries).size() : 0}});
    }
    QJsonArray loaders;
    QString lower = id.toLower();
    if (lower.contains("fabric")) loaders.append(QJsonObject{{"kind", "Fabric"}, {"version", id}});
    if (lower.contains("quilt")) loaders.append(QJsonObject{{"kind", "Quilt"}, {"version", id}});
    if (lower.contains("forge")) loaders.append(QJsonObject{{"kind", lower.contains("neoforge") ? "NeoForge" : "Forge"}, {"version", id}});

    QJsonObject settings{{"javaPath", ""}, {"minMemoryMb", 256}, {"maxMemoryMb", 4096}, {"jvmArgs", ""}, {"gameArgs", ""}, {"width", 854}, {"height", 480}, {"fullscreen", false}, {"isolated", false}, {"runDirectory", LauncherPaths::minecraftDir()}, {"server", ""}};
    const QString settingsPath = dir + "/hmcl-qt-settings.json";
    QJsonObject saved = JsonUtil::readObjectFile(settingsPath, {});
    for (auto it = saved.begin(); it != saved.end(); ++it) settings.insert(it.key(), it.value());

    return QJsonObject{
        {"versionId", id}, {"versionJson", dir + "/" + id + ".json"}, {"clientJar", dir + "/" + id + ".jar"},
        {"mainClass", mainClass}, {"inheritsFrom", inherits}, {"folders", folders}, {"loaders", loaders},
        {"settings", settings},
        {"summary", QJsonObject{{"title", id}, {"subtitle", gameVersion}, {"gameVersion", gameVersion}, {"versionType", json.value("type").toString("release")}, {"loaderSummary", loaders.isEmpty() ? "原版" : loaders.first().toObject().value("kind").toString()}, {"javaMajor", 17}, {"path", dir}, {"runDirectory", LauncherPaths::minecraftDir()}, {"iconName", iconForVersion(id)}, {"isIsolated", false}, {"isModpack", false}}}
    };
}

QJsonObject InstanceService::files(const QString &versionId, const QString &kind) {
    QString folder;
    QString key;
    if (kind == "mods") { folder = LauncherPaths::minecraftDir() + "/mods"; key = "mods"; }
    else if (kind == "resourcepacks") { folder = LauncherPaths::minecraftDir() + "/resourcepacks"; key = "resourcepacks"; }
    else { folder = LauncherPaths::minecraftDir() + "/saves"; key = "worlds"; }
    Q_UNUSED(versionId)
    QJsonArray rows;
    QDir dir(folder);
    if (dir.exists()) {
        const auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
        for (const auto &e : entries) {
            rows.append(QJsonObject{{"name", e.fileName()}, {"fileName", e.fileName()}, {"path", e.absoluteFilePath()}, {"enabled", !e.fileName().endsWith(".disabled")}, {"size", static_cast<qint64>(e.size())}, {"modified", e.lastModified().toString(Qt::ISODate)}});
        }
    }
    return QJsonObject{{key, rows}};
}

QJsonObject InstanceService::select(const QString &versionId) {
    Q_UNUSED(versionId)
    return list();
}

QJsonObject InstanceService::rename(const QString &versionId, const QString &newName) {
    QString oldDir = versionDir(versionId);
    QString newDir = LauncherPaths::versionsDir() + "/" + newName.trimmed();
    bool ok = !newName.trimmed().isEmpty() && QDir().rename(oldDir, newDir);
    return QJsonObject{{"success", ok}, {"message", ok ? "已重命名实例" : "重命名失败"}};
}

QJsonObject InstanceService::duplicate(const QString &versionId, const QString &newName, bool copySaves) {
    Q_UNUSED(copySaves)
    QString src = versionDir(versionId);
    QString dst = LauncherPaths::versionsDir() + "/" + newName.trimmed();
    QDir().mkpath(dst);
    QFile::copy(src + "/" + versionId + ".json", dst + "/" + newName.trimmed() + ".json");
    QFile::copy(src + "/" + versionId + ".jar", dst + "/" + newName.trimmed() + ".jar");
    return QJsonObject{{"success", true}, {"message", "已复制实例骨架"}};
}

QJsonObject InstanceService::remove(const QString &versionId) {
    bool ok = QDir(versionDir(versionId)).removeRecursively();
    return QJsonObject{{"success", ok}, {"message", ok ? "已删除实例" : "删除失败"}};
}

QString InstanceService::openFolder(const QString &versionId, const QString &subFolder) {
    QString path = versionDir(versionId);
    if (!subFolder.isEmpty() && subFolder != "root") path = LauncherPaths::minecraftDir() + "/" + subFolder;
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    return path;
}

QString InstanceService::generateLaunchCommand(const QString &versionId) {
    const QString id = versionId.trimmed();
    if (id.isEmpty()) return QString();

    QJsonObject child = readVersionJson(id);
    if (child.isEmpty()) {
        return QString("echo ") + shellQuote(QString("版本不存在或缺少 version.json: ") + id);
    }

    const QString parentId = child.value("inheritsFrom").toString();
    QJsonObject versionJson = parentId.isEmpty() ? child : mergeVersionJson(readVersionObjectById(parentId), child);
    const QString mainClass = versionJson.value("mainClass").toString("net.minecraft.client.main.Main");
    const QString clientJar = versionDir(id) + "/" + id + ".jar";
    QFileInfo jarInfo(clientJar);
    if (!jarInfo.exists() || jarInfo.size() <= 0) {
        return QString("echo ") + shellQuote(QString("版本 ") + id + QString(" 不是完整安装。当前 C++ 骨架只创建了空 jar/空 version.json，不能真正启动。请后续接入 HMCL 的 GameInstallTask 下载 libraries、assets 和 client.jar。"));
    }

    const QString classpath = buildClasspath(id, versionJson);
    if (classpath.isEmpty()) {
        return QString("echo ") + shellQuote(QString("版本 ") + id + QString(" 缺少 classpath。请检查 libraries 是否已下载。路径: ") + LauncherPaths::minecraftDir() + QString("/libraries"));
    }

    const QString assetIndex = versionJson.value("assetIndex").toObject().value("id").toString(versionJson.value("assets").toString("legacy"));
    const QString gameDir = LauncherPaths::minecraftDir();
    const QString nativesDir = versionDir(id) + "/natives";
    QDir().mkpath(nativesDir);

    QHash<QString, QString> vars;
    vars.insert("auth_player_name", "Steve");
    vars.insert("version_name", id);
    vars.insert("game_directory", gameDir);
    vars.insert("assets_root", gameDir + "/assets");
    vars.insert("assets_index_name", assetIndex);
    vars.insert("auth_uuid", "00000000-0000-0000-0000-000000000000");
    vars.insert("auth_access_token", "0");
    vars.insert("clientid", "0");
    vars.insert("auth_xuid", "0");
    vars.insert("user_type", "legacy");
    vars.insert("version_type", versionJson.value("type").toString("release"));
    vars.insert("natives_directory", nativesDir);
    vars.insert("launcher_name", "mc-launcher-qt-cpp");
    vars.insert("launcher_version", "0.1.0");
    vars.insert("classpath", classpath);

    QStringList args;
    args << "java" << "-Xmx2G" << (QString("-Djava.library.path=") + nativesDir);

    const QJsonObject arguments = versionJson.value("arguments").toObject();
    QStringList jvmArgs = parseArgumentList(arguments.value("jvm").toArray(), vars);
    if (!jvmArgs.isEmpty()) args << jvmArgs;
    else args << "-cp" << classpath;

    args << mainClass;

    QStringList gameArgs = parseArgumentList(arguments.value("game").toArray(), vars);
    if (!gameArgs.isEmpty()) {
        args << gameArgs;
    } else {
        const QString legacyArgs = versionJson.value("minecraftArguments").toString();
        if (!legacyArgs.isEmpty()) {
            for (const QString &part : legacyArgs.split(' ', Qt::SkipEmptyParts)) args << replaceLaunchPlaceholders(part, vars);
        } else {
            args << "--username" << "Steve"
                 << "--version" << id
                 << "--gameDir" << gameDir
                 << "--assetsDir" << gameDir + "/assets"
                 << "--assetIndex" << assetIndex
                 << "--uuid" << "00000000-0000-0000-0000-000000000000"
                 << "--accessToken" << "0"
                 << "--userType" << "legacy"
                 << "--versionType" << versionJson.value("type").toString("release");
        }
    }

    QStringList quoted;
    for (const QString &arg : args) quoted << shellQuote(arg);
    return quoted.join(' ');
}

QString InstanceService::clean(const QString &versionId, const QString &what) {
    Q_UNUSED(versionId)
    return QString("已执行清理动作: ") + what;
}

QJsonObject InstanceService::saveSettings(const QString &versionId, const QString &settingsJson) {
    QJsonObject settings = JsonUtil::objectFromString(settingsJson, {});
    bool ok = JsonUtil::writeObjectFile(versionDir(versionId) + "/hmcl-qt-settings.json", settings);
    return QJsonObject{{"success", ok}, {"message", ok ? "实例设置已保存" : "实例设置保存失败"}};
}
