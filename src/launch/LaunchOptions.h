#pragma once

#include <QJsonObject>
#include <QProcessEnvironment>
#include <QString>
#include <QStringList>

struct LaunchOptions {
    bool valid = false;
    QString error;

    QString versionId;
    QString gameVersion;
    QString javaExecutable;
    QString workingDirectory;
    QString displayCommand;
    QString logFile;
    QString accountKind;
    QString accountName;
    QString accountUuid;
    QString authServerUrl;
    QString authlibInjectorPath;
    int requiredJavaMajor = 0;

    QStringList arguments;
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();

    QJsonObject diagnostics() const {
        return QJsonObject{
            {"valid", valid},
            {"error", error},
            {"versionId", versionId},
            {"gameVersion", gameVersion},
            {"javaExecutable", javaExecutable},
            {"workingDirectory", workingDirectory},
            {"displayCommand", displayCommand},
            {"logFile", logFile},
            {"accountKind", accountKind},
            {"accountName", accountName},
            {"accountUuid", accountUuid},
            {"authServerUrl", authServerUrl},
            {"authlibInjectorPath", authlibInjectorPath},
            {"requiredJavaMajor", requiredJavaMajor},
            {"argumentCount", static_cast<int>(arguments.size())}
        };
    }
};
