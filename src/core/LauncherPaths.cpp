#include "core/LauncherPaths.h"

#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>

QString LauncherPaths::homeDir() {
    return QDir::homePath();
}

QString LauncherPaths::configDir() {
    QString base = qEnvironmentVariable("XDG_CONFIG_HOME");
    if (base.isEmpty()) base = QDir::homePath() + "/.config";
    return base + "/mc-launcher-qt-cpp";
}

QString LauncherPaths::dataDir() {
    QString base = qEnvironmentVariable("XDG_DATA_HOME");
    if (base.isEmpty()) base = QDir::homePath() + "/.local/share";
    return base + "/mc-launcher-qt-cpp";
}

QString LauncherPaths::cacheDir() {
    QString base = qEnvironmentVariable("XDG_CACHE_HOME");
    if (base.isEmpty()) base = QDir::homePath() + "/.cache";
    return base + "/mc-launcher-qt-cpp";
}

QString LauncherPaths::logsDir() {
    return dataDir() + "/logs";
}

QString LauncherPaths::minecraftDir() {
    QString mc = QDir::homePath() + "/.minecraft";
    if (QFileInfo::exists(mc)) return mc;
    return dataDir() + "/minecraft";
}

QString LauncherPaths::versionsDir() {
    return minecraftDir() + "/versions";
}

QString LauncherPaths::accountsFile() {
    return configDir() + "/accounts.json";
}

QString LauncherPaths::authServersFile() {
    return configDir() + "/auth_servers.json";
}

QString LauncherPaths::settingsFile() {
    return configDir() + "/launcher_settings.json";
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
