#pragma once

#include <QJsonObject>
#include <QString>

class LaunchService {
public:
    QJsonObject idle() const;
    QJsonObject launch(const QString &versionId, const QString &visibility, const QString &commandLine);
    QJsonObject cancelled() const;
};
