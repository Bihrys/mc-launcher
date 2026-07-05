#pragma once

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QString>

class JsonUtil {
public:
    static QString stringify(const QJsonObject &object, QJsonDocument::JsonFormat format = QJsonDocument::Compact);
    static QString stringify(const QJsonArray &array, QJsonDocument::JsonFormat format = QJsonDocument::Compact);
    static QJsonObject objectFromString(const QString &text, const QJsonObject &fallback = {});
    static QJsonArray arrayFromString(const QString &text, const QJsonArray &fallback = {});
    static QJsonObject readObjectFile(const QString &path, const QJsonObject &fallback = {});
    static QJsonArray readArrayFile(const QString &path, const QJsonArray &fallback = {});
    static bool writeObjectFile(const QString &path, const QJsonObject &object);
    static bool writeArrayFile(const QString &path, const QJsonArray &array);
};
