#include "account/MicrosoftAuthService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"

#include <QDateTime>
#include <QEventLoop>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

namespace {
constexpr int kHttpTimeoutMs = 30000;
constexpr auto kScope = "XboxLive.signin offline_access";

struct HttpResponse {
    int status = 0;
    QByteArray body;
    QString error;
    bool timedOut = false;

    bool ok() const { return status >= 200 && status < 300 && !timedOut; }
};

HttpResponse requestOnce(const QNetworkRequest &networkRequest,
                         const QByteArray &method,
                         const QByteArray &body,
                         int timeoutMs) {
    QNetworkAccessManager manager;
    QNetworkReply *reply = nullptr;
    if (method == QByteArrayLiteral("GET")) {
        reply = manager.get(networkRequest);
    } else if (method == QByteArrayLiteral("POST")) {
        reply = manager.post(networkRequest, body);
    } else {
        reply = manager.sendCustomRequest(networkRequest, method, body);
    }

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();

    HttpResponse response;
    response.timedOut = !timer.isActive();
    if (response.timedOut && !reply->isFinished()) reply->abort();
    response.status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    response.body = reply->readAll();
    if (response.timedOut) {
        response.error = QStringLiteral("请求超时。");
    } else if (reply->error() != QNetworkReply::NoError && response.body.isEmpty()) {
        response.error = reply->errorString();
    }
    reply->deleteLater();
    return response;
}

bool shouldRetry(const HttpResponse &response) {
    return response.timedOut || response.status == 0 || response.status == 408
           || response.status == 429 || response.status >= 500;
}

HttpResponse request(const QNetworkRequest &networkRequest,
                     const QByteArray &method,
                     const QByteArray &body = {},
                     int timeoutMs = kHttpTimeoutMs,
                     int maxAttempts = 5) {
    HttpResponse response;
    const int attempts = qMax(1, maxAttempts);
    for (int attempt = 1; attempt <= attempts; ++attempt) {
        response = requestOnce(networkRequest, method, body, timeoutMs);
        if (!shouldRetry(response) || attempt == attempts) break;
        QThread::msleep(static_cast<unsigned long>(200 * attempt));
    }
    return response;
}

QNetworkRequest baseRequest(const QUrl &url) {
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setRawHeader("Accept", "application/json");
    req.setRawHeader("User-Agent", "mc-launcher-qt-cpp HMCL-microsoft-auth");
    return req;
}

HttpResponse postForm(const QUrl &url, const QList<QPair<QString, QString>> &fields) {
    QUrlQuery form;
    for (const auto &field : fields) form.addQueryItem(field.first, field.second);
    QNetworkRequest req = baseRequest(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader,
                  QStringLiteral("application/x-www-form-urlencoded"));
    return request(req, QByteArrayLiteral("POST"),
                   form.query(QUrl::FullyEncoded).toUtf8());
}

HttpResponse postJson(const QUrl &url, const QJsonObject &body) {
    QNetworkRequest req = baseRequest(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader,
                  QStringLiteral("application/json"));
    return request(req, QByteArrayLiteral("POST"),
                   QJsonDocument(body).toJson(QJsonDocument::Compact));
}

HttpResponse getBearer(const QUrl &url, const QString &token) {
    QNetworkRequest req = baseRequest(url);
    req.setRawHeader("Authorization", "Bearer " + token.toUtf8());
    return request(req, QByteArrayLiteral("GET"));
}

QJsonObject jsonObject(const HttpResponse &response) {
    QJsonParseError error{};
    const QJsonDocument document = QJsonDocument::fromJson(response.body, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) return {};
    return document.object();
}

QString compactError(const HttpResponse &response, const QJsonObject &payload,
                     const QString &fallback) {
    QString message = payload.value(QStringLiteral("error_description")).toString();
    if (message.isEmpty()) message = payload.value(QStringLiteral("errorMessage")).toString();
    if (message.isEmpty()) message = payload.value(QStringLiteral("Message")).toString();
    if (message.isEmpty()) message = payload.value(QStringLiteral("message")).toString();
    if (message.isEmpty()) message = response.error;
    if (message.isEmpty()) message = fallback;
    return message;
}

QJsonObject failure(const QString &stage, const QString &message, int status = 0,
                    const QString &code = {}) {
    QJsonObject result{{QStringLiteral("success"), false},
                       {QStringLiteral("stage"), stage},
                       {QStringLiteral("message"), message}};
    if (status > 0) result.insert(QStringLiteral("httpStatus"), status);
    if (!code.isEmpty()) result.insert(QStringLiteral("errorCode"), code);
    return result;
}

QString xboxMessage(qint64 xerr, const QString &fallback) {
    switch (xerr) {
    case 2148916227LL:
        return QStringLiteral("此 Xbox 账户已被封禁，Microsoft 登录无法继续。");
    case 2148916233LL:
        return QStringLiteral("此 Microsoft 账户尚未创建 Xbox 账户。请先登录 Xbox 官网完成账户创建。");
    case 2148916235LL:
        return QStringLiteral("Xbox Live 在此账户所属国家或地区不可用。");
    case 2148916238LL:
        return QStringLiteral("这是未成年账户，必须先加入 Microsoft 家庭并由成人账户完成授权。");
    default:
        return fallback.isEmpty()
            ? QStringLiteral("Xbox Live 授权失败（XErr=%1）。").arg(xerr)
            : fallback;
    }
}

QString normalizedUuid(QString value) {
    value.remove('-');
    if (value.size() == 32) {
        const QUuid uuid = QUuid::fromString(QStringLiteral("{%1}").arg(value));
        if (!uuid.isNull()) return uuid.toString(QUuid::WithoutBraces);
    }
    return value;
}

QString firstXuiValue(const QJsonObject &payload, const QString &key) {
    const QJsonArray xui = payload.value(QStringLiteral("DisplayClaims"))
                               .toObject()
                               .value(QStringLiteral("xui"))
                               .toArray();
    if (xui.isEmpty()) return {};
    return xui.first().toObject().value(key).toString();
}

QJsonObject parseOAuthToken(const HttpResponse &response, const QString &stage) {
    const QJsonObject payload = jsonObject(response);
    if (!response.ok() || payload.value(QStringLiteral("access_token")).toString().isEmpty()) {
        const QString code = payload.value(QStringLiteral("error")).toString();
        return failure(stage,
                       compactError(response, payload,
                                    QStringLiteral("Microsoft OAuth 未返回访问令牌。")),
                       response.status, code);
    }
    return QJsonObject{{QStringLiteral("success"), true},
                       {QStringLiteral("accessToken"), payload.value(QStringLiteral("access_token"))},
                       {QStringLiteral("refreshToken"), payload.value(QStringLiteral("refresh_token"))},
                       {QStringLiteral("expiresIn"), payload.value(QStringLiteral("expires_in"))}};
}

QString configPath() {
    return LauncherPaths::configDir() + QStringLiteral("/microsoft-oauth.json");
}
} // namespace

QStringList MicrosoftAuthService::redirectUris() {
    // Microsoft ignores the port when matching localhost loopback redirects.
    // Register one path-stable URI; the launcher may then bind any free port
    // in HMCL's 29111-29115 range without adding duplicate portal entries.
    return {QStringLiteral("http://localhost/auth-response")};
}

QString MicrosoftAuthService::configuredClientId(QString *source) {
    const QString environment = qEnvironmentVariable("MC_LAUNCHER_MICROSOFT_CLIENT_ID").trimmed();
    if (!environment.isEmpty()) {
        if (source) *source = QStringLiteral("environment");
        return environment;
    }

    const QJsonObject config = JsonUtil::readObjectFile(configPath(), {});
    const QString fileValue = config.value(QStringLiteral("clientId")).toString().trimmed();
    if (!fileValue.isEmpty()) {
        if (source) *source = QStringLiteral("config");
        return fileValue;
    }

#ifdef MC_LAUNCHER_MICROSOFT_CLIENT_ID
    const QString compiled = QStringLiteral(MC_LAUNCHER_MICROSOFT_CLIENT_ID).trimmed();
    if (!compiled.isEmpty()) {
        if (source) *source = QStringLiteral("compiled");
        return compiled;
    }
#endif

    if (source) source->clear();
    return {};
}

QJsonObject MicrosoftAuthService::configuration() {
    QString source;
    const QString clientId = configuredClientId(&source);
    QJsonArray redirects;
    for (const QString &uri : redirectUris()) redirects.append(uri);
    return QJsonObject{{QStringLiteral("configured"), !clientId.isEmpty()},
                       {QStringLiteral("clientId"), clientId},
                       {QStringLiteral("source"), source},
                       {QStringLiteral("configPath"), configPath()},
                       {QStringLiteral("redirectUris"), redirects},
                       {QStringLiteral("deviceRedirectUri"),
                        QStringLiteral("https://login.microsoftonline.com/common/oauth2/nativeclient")}};
}

QJsonObject MicrosoftAuthService::exchangeAuthorizationCode(
    const QString &clientId, const QString &authorizationCode,
    const QString &redirectUri, const QString &codeVerifier) const {
    const HttpResponse response = postForm(
        QUrl(QStringLiteral("https://login.live.com/oauth20_token.srf")),
        {{QStringLiteral("client_id"), clientId},
         {QStringLiteral("code"), authorizationCode},
         {QStringLiteral("grant_type"), QStringLiteral("authorization_code")},
         {QStringLiteral("redirect_uri"), redirectUri},
         {QStringLiteral("scope"), QString::fromLatin1(kScope)},
         {QStringLiteral("code_verifier"), codeVerifier}});

    const QJsonObject token = parseOAuthToken(response, QStringLiteral("oauth"));
    if (!token.value(QStringLiteral("success")).toBool()) return token;
    return authenticateMinecraft(clientId,
                                 token.value(QStringLiteral("accessToken")).toString(),
                                 token.value(QStringLiteral("refreshToken")).toString());
}

QJsonObject MicrosoftAuthService::requestDeviceCode(const QString &clientId) const {
    const HttpResponse response = postForm(
        QUrl(QStringLiteral("https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")),
        {{QStringLiteral("client_id"), clientId},
         {QStringLiteral("scope"), QString::fromLatin1(kScope)}});
    const QJsonObject payload = jsonObject(response);
    if (!response.ok() || payload.value(QStringLiteral("device_code")).toString().isEmpty()) {
        return failure(QStringLiteral("deviceCode"),
                       compactError(response, payload,
                                    QStringLiteral("无法获取 Microsoft 设备代码。")),
                       response.status,
                       payload.value(QStringLiteral("error")).toString());
    }
    return QJsonObject{{QStringLiteral("success"), true},
                       {QStringLiteral("deviceCode"), payload.value(QStringLiteral("device_code"))},
                       {QStringLiteral("userCode"), payload.value(QStringLiteral("user_code"))},
                       {QStringLiteral("verificationUri"), payload.value(QStringLiteral("verification_uri"))},
                       {QStringLiteral("expiresIn"), payload.value(QStringLiteral("expires_in")).toInt(900)},
                       {QStringLiteral("interval"), payload.value(QStringLiteral("interval")).toInt(5)},
                       {QStringLiteral("message"), payload.value(QStringLiteral("message"))}};
}

QJsonObject MicrosoftAuthService::completeDeviceCode(
    const QString &clientId, const QString &deviceCode, int intervalSeconds,
    int expiresInSeconds, const std::shared_ptr<std::atomic_bool> &cancelled) const {
    const qint64 deadline = QDateTime::currentMSecsSinceEpoch()
                           + qMax(60, expiresInSeconds) * 1000LL;
    int interval = qMax(1, intervalSeconds);

    while (QDateTime::currentMSecsSinceEpoch() < deadline) {
        if (cancelled && cancelled->load()) {
            return failure(QStringLiteral("cancelled"), QStringLiteral("Microsoft 登录已取消。"));
        }
        QThread::sleep(static_cast<unsigned long>(interval));
        if (cancelled && cancelled->load()) {
            return failure(QStringLiteral("cancelled"), QStringLiteral("Microsoft 登录已取消。"));
        }

        const HttpResponse response = postForm(
            QUrl(QStringLiteral("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")),
            {{QStringLiteral("grant_type"),
              QStringLiteral("urn:ietf:params:oauth:grant-type:device_code")},
             {QStringLiteral("client_id"), clientId},
             {QStringLiteral("device_code"), deviceCode}});
        const QJsonObject payload = jsonObject(response);
        const QString oauthError = payload.value(QStringLiteral("error")).toString();

        if (response.ok() && !payload.value(QStringLiteral("access_token")).toString().isEmpty()) {
            return authenticateMinecraft(
                clientId,
                payload.value(QStringLiteral("access_token")).toString(),
                payload.value(QStringLiteral("refresh_token")).toString());
        }
        if (oauthError == QStringLiteral("authorization_pending")) continue;
        if (oauthError == QStringLiteral("slow_down")) {
            interval += 5;
            continue;
        }
        if (oauthError == QStringLiteral("authorization_declined")) {
            return failure(QStringLiteral("deviceCode"),
                           QStringLiteral("用户拒绝了 Microsoft 设备登录授权。"),
                           response.status, oauthError);
        }
        if (oauthError == QStringLiteral("expired_token")) {
            return failure(QStringLiteral("deviceCode"),
                           QStringLiteral("Microsoft 设备代码已过期，请重新登录。"),
                           response.status, oauthError);
        }
        return failure(QStringLiteral("deviceCode"),
                       compactError(response, payload,
                                    QStringLiteral("Microsoft 设备登录失败。")),
                       response.status, oauthError);
    }
    return failure(QStringLiteral("deviceCode"),
                   QStringLiteral("Microsoft 设备代码已过期，请重新登录。"));
}

QJsonObject MicrosoftAuthService::refresh(const QString &clientId,
                                          const QString &refreshToken) const {
    if (refreshToken.trimmed().isEmpty()) {
        return failure(QStringLiteral("refresh"),
                       QStringLiteral("此 Microsoft 账户没有可用的刷新令牌，请重新登录。"));
    }
    const HttpResponse response = postForm(
        QUrl(QStringLiteral("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")),
        {{QStringLiteral("client_id"), clientId},
         {QStringLiteral("refresh_token"), refreshToken},
         {QStringLiteral("grant_type"), QStringLiteral("refresh_token")},
         {QStringLiteral("scope"), QString::fromLatin1(kScope)}});
    const QJsonObject token = parseOAuthToken(response, QStringLiteral("refresh"));
    if (!token.value(QStringLiteral("success")).toBool()) return token;
    const QString nextRefresh = token.value(QStringLiteral("refreshToken")).toString(refreshToken);
    return authenticateMinecraft(clientId,
                                 token.value(QStringLiteral("accessToken")).toString(),
                                 nextRefresh);
}

QJsonObject MicrosoftAuthService::authenticateMinecraft(
    const QString &clientId, const QString &liveAccessToken,
    const QString &liveRefreshToken) const {
    const HttpResponse xboxResponse = postJson(
        QUrl(QStringLiteral("https://user.auth.xboxlive.com/user/authenticate")),
        QJsonObject{
            {QStringLiteral("Properties"),
             QJsonObject{{QStringLiteral("AuthMethod"), QStringLiteral("RPS")},
                         {QStringLiteral("SiteName"), QStringLiteral("user.auth.xboxlive.com")},
                         {QStringLiteral("RpsTicket"), QStringLiteral("d=") + liveAccessToken}}},
            {QStringLiteral("RelyingParty"), QStringLiteral("http://auth.xboxlive.com")},
            {QStringLiteral("TokenType"), QStringLiteral("JWT")}});
    const QJsonObject xbox = jsonObject(xboxResponse);
    const QString xboxToken = xbox.value(QStringLiteral("Token")).toString();
    const QString uhs = firstXuiValue(xbox, QStringLiteral("uhs"));
    const QString xuid = firstXuiValue(xbox, QStringLiteral("xid"));
    if (!xboxResponse.ok() || xboxToken.isEmpty() || uhs.isEmpty()) {
        const qint64 xerr = xbox.value(QStringLiteral("XErr")).toVariant().toLongLong();
        return failure(QStringLiteral("xboxLive"),
                       xboxMessage(xerr, compactError(
                           xboxResponse, xbox, QStringLiteral("Xbox Live 登录失败。"))),
                       xboxResponse.status,
                       xerr > 0 ? QString::number(xerr) : QString());
    }

    const HttpResponse xstsResponse = postJson(
        QUrl(QStringLiteral("https://xsts.auth.xboxlive.com/xsts/authorize")),
        QJsonObject{
            {QStringLiteral("Properties"),
             QJsonObject{{QStringLiteral("SandboxId"), QStringLiteral("RETAIL")},
                         {QStringLiteral("UserTokens"), QJsonArray{xboxToken}}}},
            {QStringLiteral("RelyingParty"),
             QStringLiteral("rp://api.minecraftservices.com/")},
            {QStringLiteral("TokenType"), QStringLiteral("JWT")}});
    const QJsonObject xsts = jsonObject(xstsResponse);
    const QString xstsToken = xsts.value(QStringLiteral("Token")).toString();
    const QString xstsUhs = firstXuiValue(xsts, QStringLiteral("uhs"));
    if (!xstsResponse.ok() || xstsToken.isEmpty() || xstsUhs.isEmpty()) {
        const qint64 xerr = xsts.value(QStringLiteral("XErr")).toVariant().toLongLong();
        return failure(QStringLiteral("xsts"),
                       xboxMessage(xerr, compactError(
                           xstsResponse, xsts, QStringLiteral("XSTS 授权失败。"))),
                       xstsResponse.status,
                       xerr > 0 ? QString::number(xerr) : QString());
    }
    if (xstsUhs != uhs) {
        return failure(QStringLiteral("xsts"),
                       QStringLiteral("Xbox Live 与 XSTS 返回的用户哈希不一致。"));
    }

    const HttpResponse minecraftLoginResponse = postJson(
        QUrl(QStringLiteral("https://api.minecraftservices.com/authentication/login_with_xbox")),
        QJsonObject{{QStringLiteral("identityToken"),
                     QStringLiteral("XBL3.0 x=%1;%2").arg(uhs, xstsToken)}});
    const QJsonObject minecraftLogin = jsonObject(minecraftLoginResponse);
    const QString minecraftAccessToken =
        minecraftLogin.value(QStringLiteral("access_token")).toString();
    if (!minecraftLoginResponse.ok() || minecraftAccessToken.isEmpty()) {
        const QString responseText = QString::fromUtf8(minecraftLoginResponse.body);
        if (minecraftLoginResponse.status == 403
            && (responseText.contains(QStringLiteral("Invalid app registration"), Qt::CaseInsensitive)
                || responseText.contains(QStringLiteral("AppRegInfo"), Qt::CaseInsensitive))) {
            return failure(
                QStringLiteral("appRegistration"),
                QStringLiteral("Microsoft OAuth 与 Xbox 登录已完成，但此 Client ID 尚未获准调用 Minecraft Services。仅在 Microsoft Entra 注册应用并不一定足够；还需要按 Minecraft 应用审核流程提交此 Application (client) ID。"),
                minecraftLoginResponse.status,
                QStringLiteral("InvalidAppRegistration"));
        }
        return failure(QStringLiteral("minecraftLogin"),
                       compactError(minecraftLoginResponse, minecraftLogin,
                                    QStringLiteral("Minecraft Services 登录失败。")),
                       minecraftLoginResponse.status,
                       minecraftLogin.value(QStringLiteral("error")).toString());
    }

    const HttpResponse entitlementResponse = getBearer(
        QUrl(QStringLiteral("https://api.minecraftservices.com/entitlements/mcstore")),
        minecraftAccessToken);
    if (!entitlementResponse.ok()) {
        return failure(QStringLiteral("entitlements"),
                       QStringLiteral("无法验证 Minecraft Java Edition 所有权。"),
                       entitlementResponse.status);
    }

    const HttpResponse profileResponse = getBearer(
        QUrl(QStringLiteral("https://api.minecraftservices.com/minecraft/profile")),
        minecraftAccessToken);
    const QJsonObject profile = jsonObject(profileResponse);
    if (!profileResponse.ok()) {
        if (profileResponse.status == 404) {
            const HttpResponse licenseResponse = getBearer(
                QUrl(QStringLiteral("https://api.minecraftservices.com/entitlements/license")),
                minecraftAccessToken);
            const QJsonArray licenseItems = jsonObject(licenseResponse)
                                                .value(QStringLiteral("items"))
                                                .toArray();
            bool ownsJavaEdition = false;
            for (const QJsonValue &value : licenseItems) {
                if (value.toObject().value(QStringLiteral("name")).toString()
                    == QStringLiteral("game_minecraft")) {
                    ownsJavaEdition = true;
                    break;
                }
            }
            if (!licenseResponse.ok() || !ownsJavaEdition) {
                return failure(QStringLiteral("license"),
                               QStringLiteral("该 Microsoft 账户未检测到 Minecraft Java Edition 许可证。"),
                               licenseResponse.status > 0 ? licenseResponse.status
                                                          : profileResponse.status);
            }
            return failure(QStringLiteral("profile"),
                           QStringLiteral("该账户拥有 Minecraft Java Edition，但尚未创建 Java 版游戏档案。请先在官方启动器或 Minecraft 官网创建角色名。"),
                           profileResponse.status);
        }
        return failure(QStringLiteral("profile"),
                       compactError(profileResponse, profile,
                                    QStringLiteral("无法读取 Minecraft 游戏档案。")),
                       profileResponse.status,
                       profile.value(QStringLiteral("error")).toString());
    }

    const QString profileId = profile.value(QStringLiteral("id")).toString();
    const QString profileName = profile.value(QStringLiteral("name")).toString();
    if (profileId.isEmpty() || profileName.isEmpty()) {
        return failure(QStringLiteral("profile"),
                       QStringLiteral("Minecraft 游戏档案缺少角色名或 UUID。"));
    }

    QString skinUrl;
    const QJsonArray skins = profile.value(QStringLiteral("skins")).toArray();
    if (!skins.isEmpty()) skinUrl = skins.first().toObject().value(QStringLiteral("url")).toString();

    const qint64 expiresIn = minecraftLogin.value(QStringLiteral("expires_in")).toVariant().toLongLong();
    const QJsonObject account{
        {QStringLiteral("kind"), QStringLiteral("microsoft")},
        {QStringLiteral("username"), profileName},
        {QStringLiteral("uuid"), normalizedUuid(profileId)},
        {QStringLiteral("accessToken"), minecraftAccessToken},
        {QStringLiteral("refreshToken"), liveRefreshToken},
        {QStringLiteral("clientId"), clientId},
        {QStringLiteral("xuid"), xuid},
        {QStringLiteral("skinUrl"), skinUrl},
        {QStringLiteral("tokenExpiresAt"),
         QDateTime::currentMSecsSinceEpoch() + qMax<qint64>(60, expiresIn) * 1000LL},
        {QStringLiteral("note"), QStringLiteral("Microsoft 正版账户")}};

    return QJsonObject{{QStringLiteral("success"), true},
                       {QStringLiteral("account"), account},
                       {QStringLiteral("message"),
                        QStringLiteral("Microsoft 登录成功：%1").arg(profileName)}};
}
