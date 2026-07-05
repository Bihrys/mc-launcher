#pragma once

#include <QJsonObject>
#include <QString>

class JavaService {
public:
    QJsonObject detect();
    QString downloadPlaceholder(const QString &distribution, const QString &major, const QString &packageType);
};
