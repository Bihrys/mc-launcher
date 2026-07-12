#include "core/LauncherPaths.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QStringList>

namespace {

QString xdgConfigHome() {
    QString base = qEnvironmentVariable("XDG_CONFIG_HOME");
    if (base.isEmpty()) base = QDir::homePath() + "/.config";
    return QDir::cleanPath(base);
}

QString xdgDataHome() {
    QString base = qEnvironmentVariable("XDG_DATA_HOME");
    if (base.isEmpty()) base = QDir::homePath() + "/.local/share";
    return QDir::cleanPath(base);
}

QString migrateFile(const QString &target, const QStringList &legacyCandidates) {
    if (QFileInfo::isFile(target)) return target;
    for (const QString &legacy : legacyCandidates) {
        if (!QFileInfo::isFile(legacy)) continue;
        QDir().mkpath(QFileInfo(target).absolutePath());
        if (QFile::copy(legacy, target)) return target;
    }
    return target;
}

} // namespace

QString LauncherPaths::homeDir() {
    return QDir::homePath();
}

QString LauncherPaths::configDir() {
    return xdgConfigHome() + "/mc-launcher-qt-cpp";
}

QString LauncherPaths::dataDir() {
    return xdgDataHome() + "/mc-launcher-qt-cpp";
}

QString LauncherPaths::cacheDir() {
    QString base = qEnvironmentVariable("XDG_CACHE_HOME");
    if (base.isEmpty()) base = QDir::homePath() + "/.cache";
    return QDir::cleanPath(base) + "/mc-launcher-qt-cpp";
}

QString LauncherPaths::logsDir() {
    return dataDir() + "/logs";
}

QString LauncherPaths::minecraftDir() {
    // Keep the repository deterministic. The old implementation silently
    // switched to ~/.minecraft merely because that directory existed, while
    // downloads and HMCL testing used ~/.local/share/mc-launcher/minecraft.
    // That split libraries/assets across two repositories and caused startup
    // crashes from missing asset objects.
    const QString override = qEnvironmentVariable("MC_LAUNCHER_MINECRAFT_DIR").trimmed();
    if (!override.isEmpty()) return QDir(override).absolutePath();

    const QString canonical = xdgDataHome() + "/mc-launcher/minecraft";
    const QString oldCppRoot = xdgDataHome() + "/mc-launcher-qt-cpp/minecraft";

    if (QFileInfo::isDir(canonical)) return canonical;
    if (QFileInfo::isDir(oldCppRoot)) return oldCppRoot;

    // New installations use the same project-owned directory seen by HMCL in
    // the user's test log. Never auto-adopt ~/.minecraft.
    return canonical;
}

QString LauncherPaths::versionsDir() {
    return minecraftDir() + "/versions";
}

QString LauncherPaths::accountsFile() {
    const QString target = configDir() + "/accounts.json";
    return migrateFile(target, {
        xdgConfigHome() + "/mc-launcher/accounts.json",
        xdgDataHome() + "/mc-launcher/accounts.json"
    });
}

QString LauncherPaths::authServersFile() {
    const QString target = configDir() + "/auth_servers.json";
    return migrateFile(target, {
        xdgConfigHome() + "/mc-launcher/auth_servers.json"
    });
}

QString LauncherPaths::settingsFile() {
    const QString target = configDir() + "/launcher_settings.json";
    return migrateFile(target, {
        xdgConfigHome() + "/mc-launcher/launcher_settings.json"
    });
}

QString LauncherPaths::specialFolder(const QString &kind) {
    if (kind == "config") return configDir();
    if (kind == "data") return dataDir();
    if (kind == "cache") return cacheDir();
    if (kind == "logs") return logsDir();
    if (kind == "minecraft") return minecraftDir();
    if (kind == "versions") return versionsDir();
    if (kind == "accounts") return QFileInfo(accountsFile()).absolutePath();
    return dataDir();
}

bool LauncherPaths::ensureDir(const QString &path) {
    return QDir().mkpath(path);
}
