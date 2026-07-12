#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QString>
#include <QStringList>

// C++ counterpart of HMCLCore/game/LaunchOptions.
// Only values actually consumed by the Qt/C++ launcher are kept here.
struct LaunchOptions {
    bool valid = false;
    QString error;

    QString versionId;
    QString gameVersion;
    QString javaExecutable;
    QString workingDirectory;
    QString instanceDirectory;
    QString minecraftDirectory;
    QString nativeDirectory;
    QString assetsDirectory;
    QString assetIndexFile;
    QString assetIndexId;
    QString downloadSource;
    QString displayCommand;
    QString logFile;

    QString accountKind;
    QString accountName;
    QString accountUuid;
    QString authServerUrl;
    QString authlibInjectorPath;

    QString graphicsBackend = QStringLiteral("default");
    QString renderer = QStringLiteral("default");
    QStringList loaderKinds;
    QStringList nativeArchives;
    QJsonArray dependencyDownloads;

    int requiredJavaMajor = 0;
    int maxMemoryMiB = 0;
    bool detectWindow = true;

    QStringList arguments;
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();

    QJsonObject diagnostics() const {
        QJsonArray loaders;
        for (const QString &loader : loaderKinds) loaders.append(loader);
        return QJsonObject{
            {"valid", valid},
            {"error", error},
            {"versionId", versionId},
            {"gameVersion", gameVersion},
            {"javaExecutable", javaExecutable},
            {"workingDirectory", workingDirectory},
            {"instanceDirectory", instanceDirectory},
            {"minecraftDirectory", minecraftDirectory},
            {"nativeDirectory", nativeDirectory},
            {"assetsDirectory", assetsDirectory},
            {"assetIndexFile", assetIndexFile},
            {"assetIndexId", assetIndexId},
            {"downloadSource", downloadSource},
            {"displayCommand", displayCommand},
            {"logFile", logFile},
            {"accountKind", accountKind},
            {"accountName", accountName},
            {"accountUuid", accountUuid},
            {"authServerUrl", authServerUrl},
            {"authlibInjectorPath", authlibInjectorPath},
            {"graphicsBackend", graphicsBackend},
            {"renderer", renderer},
            {"loaderKinds", loaders},
            {"nativeArchiveCount", static_cast<int>(nativeArchives.size())},
            {"dependencyDownloadCount", dependencyDownloads.size()},
            {"requiredJavaMajor", requiredJavaMajor},
            {"maxMemoryMiB", maxMemoryMiB},
            {"detectWindow", detectWindow},
            {"argumentCount", static_cast<int>(arguments.size())}
        };
    }
};
