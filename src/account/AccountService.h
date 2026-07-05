#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

class AccountService {
public:
    QJsonObject list();
    QJsonObject authServers();
    QJsonObject addAuthServer(const QString &name, const QString &url);
    QJsonObject deleteAuthServer(int index);
    QJsonObject addOffline(const QString &username);
    QJsonObject addYggdrasilPlaceholder(const QString &serverUrl, const QString &username);
    QJsonObject addMicrosoftPlaceholder(const QString &clientId);
    QJsonObject switchAccountByIdentifier(const QString &kind, const QString &uuid, const QString &serverUrl);
    QJsonObject deleteAccount(int index);
    QString offlineAvatarPreview(const QString &username) const;

private:
    QJsonArray loadAccounts() const;
    bool saveAccounts(const QJsonArray &accounts) const;
    QString offlineUuid(const QString &username) const;
    QJsonObject publicPayload(const QJsonArray &accounts) const;
    QJsonObject selectedOrFirst(QJsonArray &accounts) const;
};
