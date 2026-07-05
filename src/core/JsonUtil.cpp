#include "core/JsonUtil.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>

QString JsonUtil::stringify(const QJsonObject &object, QJsonDocument::JsonFormat format) {
    return QString::fromUtf8(QJsonDocument(object).toJson(format));
}

QString JsonUtil::stringify(const QJsonArray &array, QJsonDocument::JsonFormat format) {
    return QString::fromUtf8(QJsonDocument(array).toJson(format));
}

QJsonObject JsonUtil::objectFromString(const QString &text, const QJsonObject &fallback) {
    QJsonParseError error{};
    auto doc = QJsonDocument::fromJson(text.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject()) return fallback;
    return doc.object();
}

QJsonArray JsonUtil::arrayFromString(const QString &text, const QJsonArray &fallback) {
    QJsonParseError error{};
    auto doc = QJsonDocument::fromJson(text.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isArray()) return fallback;
    return doc.array();
}

QJsonObject JsonUtil::readObjectFile(const QString &path, const QJsonObject &fallback) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return fallback;
    return objectFromString(QString::fromUtf8(file.readAll()), fallback);
}

QJsonArray JsonUtil::readArrayFile(const QString &path, const QJsonArray &fallback) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return fallback;
    return arrayFromString(QString::fromUtf8(file.readAll()), fallback);
}

bool JsonUtil::writeObjectFile(const QString &path, const QJsonObject &object) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    return true;
}

bool JsonUtil::writeArrayFile(const QString &path, const QJsonArray &array) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
    return true;
}
