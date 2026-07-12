#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QMutex>
#include <QString>

#include <atomic>
#include <memory>

class AccountService {
public:
    QJsonObject list();
    QJsonObject selectedAccountForLaunch() const;
    QJsonObject authServers();
    QJsonObject probeAuthServer(const QString &url) const;
    QJsonObject addAuthServer(const QString &name, const QString &url);
    QJsonObject deleteAuthServer(int index);
    QJsonObject addOffline(const QString &username, const QString &uuid = QString());
    QJsonObject setOfflineSkin(int index, const QString &fileUrl,
                               const QString &capeFileUrl, const QString &model,
                               const QString &cslApi,
                               const QString &skinType = QStringLiteral("default"));
    QJsonObject authenticateYggdrasil(const QString &serverUrl,
                                      const QString &username,
                                      const QString &password);
    QJsonObject selectPendingYggdrasilProfile(int index);
    QJsonObject refreshAccount(int index);
    QJsonObject reauthenticateYggdrasil(int index, const QString &password);
    QJsonObject uploadSkin(int index, const QString &fileUrl, const QString &model);
    QJsonObject cleanupAvatarCache();
    QJsonObject microsoftClientConfiguration() const;
    QJsonObject authenticateMicrosoftAuthorizationCode(const QString &clientId,
                                                       const QString &authorizationCode,
                                                       const QString &redirectUri,
                                                       const QString &codeVerifier);
    QJsonObject requestMicrosoftDeviceCode(const QString &clientId) const;
    QJsonObject authenticateMicrosoftDeviceCode(
        const QString &clientId, const QString &deviceCode,
        int intervalSeconds, int expiresInSeconds,
        const std::shared_ptr<std::atomic_bool> &cancelled);
    QJsonObject switchAccountByIdentifier(const QString &kind, const QString &uuid, const QString &serverUrl);
    QJsonObject deleteAccount(int index);
    QString offlineAvatarPreview(const QString &username) const;

private:
    QJsonArray loadAccounts() const;
    bool saveAccounts(const QJsonArray &accounts) const;
    QString offlineUuid(const QString &username) const;
    QJsonObject publicPayload(const QJsonArray &accounts) const;
    QJsonObject selectedOrFirst(QJsonArray &accounts) const;

    QString normalizeAuthServer(const QString &url, QJsonObject *metadata = nullptr,
                                QString *errorMessage = nullptr) const;
    QJsonObject postJson(const QUrl &url, const QJsonObject &body,
                         QString *errorMessage = nullptr) const;
    QJsonObject getJson(const QUrl &url, QString *errorMessage = nullptr) const;
    QString defaultAvatarForUuid(const QString &uuid) const;
    QString avatarFromSkinUrl(const QString &uuid, const QString &skinUrl) const;
    QString avatarFromSkinImage(const QString &uuid, const QString &sourcePath) const;
    QString profileSkinUrl(const QString &serverUrl, const QString &uuid) const;
    QJsonObject saveMicrosoftLoginResult(const QJsonObject &result);
    QJsonObject saveYggdrasilAccount(const QString &serverUrl,
                                     const QString &loginName,
                                     const QString &accessToken,
                                     const QString &clientToken,
                                     const QJsonObject &profile);

    mutable QMutex m_pendingMutex;
    QJsonObject m_pendingYggdrasil;
};
