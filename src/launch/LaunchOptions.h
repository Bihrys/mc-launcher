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

    int requiredJavaMajor = 0;
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
            {"requiredJavaMajor", requiredJavaMajor},
            {"detectWindow", detectWindow},
            {"argumentCount", static_cast<int>(arguments.size())}
        };
    }
};
