#pragma once

#include <QString>

class LauncherPaths {
public:
    static QString homeDir();
    static QString configDir();
    static QString dataDir();
    static QString cacheDir();
    static QString logsDir();
    static QString minecraftDir();
    static QString versionsDir();
    static QString accountsFile();
    static QString authServersFile();
    static QString settingsFile();
    static QString specialFolder(const QString &kind);
    static bool ensureDir(const QString &path);
};
