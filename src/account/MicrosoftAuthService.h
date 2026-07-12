#pragma once

#include <QJsonObject>
#include <QString>
#include <QStringList>

#include <atomic>
#include <memory>

class MicrosoftAuthService {
public:
    static QJsonObject configuration();
    static QString configuredClientId(QString *source = nullptr);
    static QStringList redirectUris();

    QJsonObject exchangeAuthorizationCode(const QString &clientId,
                                          const QString &authorizationCode,
                                          const QString &redirectUri,
                                          const QString &codeVerifier) const;
    QJsonObject requestDeviceCode(const QString &clientId) const;
    QJsonObject completeDeviceCode(const QString &clientId,
                                   const QString &deviceCode,
                                   int intervalSeconds,
                                   int expiresInSeconds,
                                   const std::shared_ptr<std::atomic_bool> &cancelled) const;
    QJsonObject refresh(const QString &clientId, const QString &refreshToken) const;

private:
    QJsonObject authenticateMinecraft(const QString &clientId,
                                      const QString &liveAccessToken,
                                      const QString &liveRefreshToken) const;
};
