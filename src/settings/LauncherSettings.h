#pragma once

#include <QJsonObject>
#include <QString>

class LauncherSettings {
public:
    QJsonObject load();
    bool save(const QJsonObject &settings);
    QJsonObject defaults() const;
    QJsonObject update(const QString &key, const QString &rawValue);
    QJsonObject appearanceOptions() const;
    QJsonObject systemMemory() const;

private:
    static void merge(QJsonObject &base, const QJsonObject &overlay);
    static QJsonValue parseValue(const QString &key, const QString &rawValue);
};
