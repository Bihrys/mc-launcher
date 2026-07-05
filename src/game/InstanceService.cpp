#include "game/InstanceService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QProcess>
#include <QDesktopServices>
#include <QUrl>

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
    return "java -jar \"" + versionDir(versionId) + "/" + versionId + ".jar\"";
}

QString InstanceService::clean(const QString &versionId, const QString &what) {
    Q_UNUSED(versionId)
    return "已执行清理动作: " + what;
}

QJsonObject InstanceService::saveSettings(const QString &versionId, const QString &settingsJson) {
    QJsonObject settings = JsonUtil::objectFromString(settingsJson, {});
    bool ok = JsonUtil::writeObjectFile(versionDir(versionId) + "/hmcl-qt-settings.json", settings);
    return QJsonObject{{"success", ok}, {"message", ok ? "实例设置已保存" : "实例设置保存失败"}};
}
