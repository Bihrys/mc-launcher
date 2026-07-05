#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

class InstanceService {
public:
    QJsonObject list();
    QJsonObject installedVersions();
    QJsonObject detail(const QString &versionId);
    QJsonObject files(const QString &versionId, const QString &kind);
    QJsonObject select(const QString &versionId);
    QJsonObject rename(const QString &versionId, const QString &newName);
    QJsonObject duplicate(const QString &versionId, const QString &newName, bool copySaves);
    QJsonObject remove(const QString &versionId);
    QString openFolder(const QString &versionId, const QString &subFolder = QString());
    QString generateLaunchCommand(const QString &versionId);
    QString clean(const QString &versionId, const QString &what);
    QJsonObject saveSettings(const QString &versionId, const QString &settingsJson);

private:
    QJsonArray scanVersions() const;
    QString versionDir(const QString &versionId) const;
    QString iconForVersion(const QString &versionId, const QString &type = QString()) const;
    QJsonObject readVersionJson(const QString &versionId) const;
};
