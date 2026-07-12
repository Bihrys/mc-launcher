#include "account/AccountService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPainter>
#include <QSaveFile>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

namespace {
QByteArray requestBytes(const QNetworkRequest &request, const QByteArray &method,
                        const QByteArray &body, int *status, QByteArray *apiLocation,
                        QString *errorMessage, int timeoutMs = 15000) {
    QNetworkAccessManager manager;
    QNetworkReply *reply = nullptr;
    if (method == "GET") reply = manager.get(request);
    else reply = manager.sendCustomRequest(request, method, body);

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();

    const bool timedOut = !timer.isActive();
    if (timedOut && !reply->isFinished()) reply->abort();
    if (status) *status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (apiLocation) *apiLocation = reply->rawHeader("x-authlib-injector-api-location");
    QByteArray data;
    if (!timedOut && reply->error() == QNetworkReply::NoError && reply->isReadable())
        data = reply->readAll();
    else if (errorMessage)
        *errorMessage = timedOut ? QStringLiteral("连接认证服务器超时。") : reply->errorString();
    reply->deleteLater();
    return data;
}

QString compactUuid(QString uuid) {
    uuid.remove('-');
    return uuid;
}

QString ensureSlash(QString url) {
    if (!url.endsWith('/')) url += '/';
    return url;
}

QString versionedLocalFileUrl(const QString &path) {
    QUrl url = QUrl::fromLocalFile(path);
    const QFileInfo info(path);
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("v"),
                       QString::number(info.exists() ? info.lastModified().toMSecsSinceEpoch()
                                                     : QDateTime::currentMSecsSinceEpoch()));
    url.setQuery(query);
    return url.toString(QUrl::FullyEncoded);
}

QString textureUrlFromProfile(const QJsonObject &profile) {
    const QJsonArray properties = profile.value("properties").toArray();
    for (const QJsonValue &value : properties) {
        const QJsonObject property = value.toObject();
        if (property.value("name").toString() != QStringLiteral("textures")) continue;
        const QByteArray payload = QByteArray::fromBase64(property.value("value").toString().toLatin1());
        const QJsonObject textures = QJsonDocument::fromJson(payload).object().value("textures").toObject();
        return textures.value("SKIN").toObject().value("url").toString();
    }
    return {};
}

qint32 javaUuidHash(const QString &uuid) {
    QByteArray raw = QByteArray::fromHex(compactUuid(uuid).toLatin1());
    if (raw.size() != 16) return qHash(uuid);
    auto be32 = [&raw](int offset) -> quint32 {
        return (quint32(quint8(raw[offset])) << 24)
             | (quint32(quint8(raw[offset + 1])) << 16)
             | (quint32(quint8(raw[offset + 2])) << 8)
             | quint32(quint8(raw[offset + 3]));
    };
    return qint32(be32(0) ^ be32(4) ^ be32(8) ^ be32(12));
}

bool isSlimSkin(const QImage &source) {
    if (source.isNull() || source.width() != 64 || source.height() != 64) return false;
    const QImage image = source.convertToFormat(QImage::Format_ARGB32);
    auto hasTransparency = [&image](int x0, int y0, int width, int height) {
        for (int y = y0; y < y0 + height; ++y) {
            for (int x = x0; x < x0 + width; ++x) {
                if (qAlpha(image.pixel(x, y)) != 255) return true;
            }
        }
        return false;
    };
    auto isBlack = [&image](int x0, int y0, int width, int height) {
        for (int y = y0; y < y0 + height; ++y) {
            for (int x = x0; x < x0 + width; ++x) {
                if (image.pixel(x, y) != qRgba(0, 0, 0, 255)) return false;
            }
        }
        return true;
    };
    return hasTransparency(50, 16, 2, 4)
        || hasTransparency(54, 20, 2, 12)
        || hasTransparency(42, 48, 2, 4)
        || hasTransparency(46, 52, 2, 12)
        || (isBlack(50, 16, 2, 4)
            && isBlack(54, 20, 2, 12)
            && isBlack(42, 48, 2, 4)
            && isBlack(46, 52, 2, 12));
}

}

QJsonArray AccountService::loadAccounts() const {
    return JsonUtil::readArrayFile(LauncherPaths::accountsFile(), {});
}

bool AccountService::saveAccounts(const QJsonArray &accounts) const {
    return JsonUtil::writeArrayFile(LauncherPaths::accountsFile(), accounts);
}

QString AccountService::offlineUuid(const QString &username) const {
    QByteArray bytes = QCryptographicHash::hash(("OfflinePlayer:" + username).toUtf8(), QCryptographicHash::Md5);
    if (bytes.size() != 16) return QString::fromLatin1(bytes.toHex());
    bytes[6] = char((quint8(bytes[6]) & 0x0f) | 0x30);
    bytes[8] = char((quint8(bytes[8]) & 0x3f) | 0x80);
    return QUuid::fromRfc4122(bytes).toString(QUuid::WithoutBraces);
}

QString AccountService::avatarFromSkinImage(const QString &uuid, const QString &sourcePath) const {
    QImage skin(sourcePath);
    if (skin.isNull() || skin.width() < 64 || skin.height() < 32) return {};
    const int scale = qMax(1, skin.width() / 64);
    const int size = 64;
    const int faceOffset = qRound(size / 18.0);
    QImage avatar(size, size, QImage::Format_ARGB32_Premultiplied);
    avatar.fill(Qt::transparent);
    QPainter painter(&avatar);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, false);
    painter.drawImage(QRect(faceOffset, faceOffset, size - 2 * faceOffset, size - 2 * faceOffset),
                      skin, QRect(8 * scale, 8 * scale, 8 * scale, 8 * scale));
    painter.drawImage(QRect(0, 0, size, size),
                      skin, QRect(40 * scale, 8 * scale, 8 * scale, 8 * scale));
    painter.end();

    const QString root = LauncherPaths::cacheDir() + "/avatars";
    QDir().mkpath(root);
    const QString path = root + "/" + compactUuid(uuid) + ".png";
    if (!avatar.save(path, "PNG")) return {};
    return versionedLocalFileUrl(path);
}

QString AccountService::defaultAvatarForUuid(const QString &uuid) const {
    static const QStringList skins = {"alex", "ari", "efe", "kai", "makena", "noor", "steve", "sunny", "zuri"};
    int idx = javaUuidHash(uuid) % (skins.size() * 2);
    if (idx < 0) idx += skins.size() * 2;
    const QString model = idx < skins.size() ? QStringLiteral("slim") : QStringLiteral("wide");
    if (idx >= skins.size()) idx -= skins.size();
    const QString resource = QString(":/qt/qml/com/bihrys/launcher/qml/assets/img/skin/%1/%2.png")
                                 .arg(model, skins.at(idx));
    return avatarFromSkinImage(uuid, resource);
}

QString AccountService::avatarFromSkinUrl(const QString &uuid, const QString &skinUrl) const {
    if (skinUrl.isEmpty()) return defaultAvatarForUuid(uuid);
    const QString root = LauncherPaths::cacheDir() + "/skins";
    QDir().mkpath(root);
    const QString key = QString::fromLatin1(QCryptographicHash::hash(skinUrl.toUtf8(), QCryptographicHash::Sha1).toHex());
    const QString skinPath = root + "/" + key + ".png";
    if (!QFileInfo::exists(skinPath)) {
        QNetworkRequest request(QUrl(skinUrl));
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
        request.setRawHeader("User-Agent", "mc-launcher-qt-cpp HMCL-avatar");
        QString error;
        const QByteArray data = requestBytes(request, "GET", {}, nullptr, nullptr, &error, 10000);
        if (!data.isEmpty()) {
            QSaveFile file(skinPath);
            if (file.open(QIODevice::WriteOnly)) { file.write(data); file.commit(); }
        }
    }
    const QString result = avatarFromSkinImage(uuid, skinPath);
    return result.isEmpty() ? defaultAvatarForUuid(uuid) : result;
}

QString AccountService::offlineAvatarPreview(const QString &username) const {
    return defaultAvatarForUuid(offlineUuid(username.trimmed().isEmpty() ? QStringLiteral("Steve") : username.trimmed()));
}

QJsonObject AccountService::publicPayload(const QJsonArray &accounts) const {
    QJsonArray out;
    bool hasSelected = false;
    for (const auto &v : accounts) if (v.toObject().value("selected").toBool()) hasSelected = true;

    for (int i = 0; i < accounts.size(); ++i) {
        QJsonObject a = accounts.at(i).toObject();
        const QString kind = a.value("kind").toString("offline");
        const QString username = a.value("username").toString();
        const QString uuid = a.value("uuid").toString();
        const QString server = a.value("serverUrl").toString();
        const bool selected = a.value("selected").toBool(false) || (!hasSelected && i == 0);
        QString displayKind = "离线账户";
        if (kind == "microsoft") displayKind = "Microsoft";
        if (kind == "yggdrasil") displayKind = QUrl(server).host().isEmpty() ? "第三方账户" : QUrl(server).host();

        QString avatarUrl = a.value("avatarUrl").toString();
        if (kind == QStringLiteral("offline")) {
            const QString skinType = a.value("skinType").toString(QStringLiteral("default"));
            const QString skinPath = a.value("skinPath").toString();
            if (skinType == QStringLiteral("local")
                && !skinPath.isEmpty() && QFileInfo::exists(skinPath)) {
                avatarUrl = avatarFromSkinImage(uuid, skinPath);
            } else if (skinType == QStringLiteral("steve")
                       || skinType == QStringLiteral("alex")) {
                const QString skinModel = skinType == QStringLiteral("alex")
                                              ? QStringLiteral("slim") : QStringLiteral("wide");
                avatarUrl = avatarFromSkinImage(
                    uuid, QStringLiteral(
                        ":/qt/qml/com/bihrys/launcher/qml/assets/img/skin/%1/%2.png")
                              .arg(skinModel, skinType));
            } else if ((skinType == QStringLiteral("littleskin")
                        || skinType == QStringLiteral("csl"))
                       && !a.value("skinUrl").toString().isEmpty()) {
                avatarUrl = avatarFromSkinUrl(uuid, a.value("skinUrl").toString());
            } else {
                // Drop legacy Crafatar/remote placeholders. HMCL derives the
                // offline avatar from the UUID and bundled default skins.
                avatarUrl = defaultAvatarForUuid(uuid);
            }
        }
        if (avatarUrl.isEmpty()
            || (avatarUrl.startsWith(QStringLiteral("file:"))
                && !QFileInfo(QUrl(avatarUrl).toLocalFile()).exists())) {
            avatarUrl = defaultAvatarForUuid(uuid);
        }

        out.append(QJsonObject{
            {"username", username}, {"uuid", uuid}, {"kind", kind}, {"displayKind", displayKind},
            {"serverUrl", server}, {"avatarUrl", avatarUrl}, {"loginName", a.value("loginName").toString()},
            {"note", a.value("note").toString()}, {"identifier", kind + "|" + uuid + "|" + server},
            {"selected", selected},
            {"skinType", a.value("skinType").toString(QStringLiteral("default"))},
            {"skinModel", a.value("skinModel").toString(QStringLiteral("wide"))},
            {"skinPath", a.value("skinPath").toString()},
            {"capePath", a.value("capePath").toString()},
            {"skinCslApi", a.value("skinCslApi").toString()}
        });
    }
    return QJsonObject{{"accounts", out}};
}

QJsonObject AccountService::list() { return publicPayload(loadAccounts()); }

QJsonObject AccountService::authServers() {
    QJsonArray fallback;
    fallback.append(QJsonObject{
        {"name", "LittleSkin"},
        {"url", "https://littleskin.cn/api/yggdrasil/"},
        {"host", "littleskin.cn"},
        {"links", QJsonObject{{"homepage", "https://littleskin.cn/"},
                              {"register", "https://littleskin.cn/auth/register"}}},
        {"nonEmailLogin", false}
    });
    QJsonArray servers = JsonUtil::readArrayFile(LauncherPaths::authServersFile(), fallback);
    if (servers.isEmpty()) servers = fallback;
    JsonUtil::writeArrayFile(LauncherPaths::authServersFile(), servers);
    return QJsonObject{{"servers", servers}};
}

QString AccountService::normalizeAuthServer(const QString &input, QJsonObject *metadata,
                                            QString *errorMessage) const {
    QString text = input.trimmed();
    if (!text.contains("://")) text.prepend("https://");
    QUrl url(text);
    if (!url.isValid() || url.host().isEmpty()) {
        if (errorMessage) *errorMessage = QStringLiteral("认证服务器地址无效。");
        return {};
    }
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "mc-launcher-qt-cpp HMCL-authlib-injector");
    int status = 0;
    QByteArray location;
    QString error;
    QByteArray data = requestBytes(request, "GET", {}, &status, &location, &error);
    if (!location.isEmpty()) {
        QUrl redirected = url.resolved(QUrl(QString::fromUtf8(location)));
        if (redirected.isValid()) {
            url = redirected;
            request.setUrl(url);
            data = requestBytes(request, "GET", {}, &status, nullptr, &error);
        }
    }
    if (data.isEmpty()) {
        if (errorMessage) *errorMessage = error.isEmpty() ? QString("认证服务器返回 HTTP %1。").arg(status) : error;
        return {};
    }
    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(data, &parseError);
    if (!document.isObject()) {
        if (errorMessage) *errorMessage = QStringLiteral("认证服务器元数据不是有效 JSON。");
        return {};
    }
    if (metadata) *metadata = document.object();
    return ensureSlash(url.toString(QUrl::FullyEncoded));
}

QJsonObject AccountService::probeAuthServer(const QString &url) const {
    QJsonObject metadata;
    QString error;
    const QString normalized = normalizeAuthServer(url, &metadata, &error);
    if (normalized.isEmpty()) return QJsonObject{{"success", false}, {"message", error}};
    const QJsonObject meta = metadata.value("meta").toObject();
    const QString name = meta.value("serverName").toString(QUrl(normalized).host());
    const QJsonObject links = meta.value("links").toObject();
    return QJsonObject{{"success", true}, {"url", normalized}, {"name", name},
                       {"host", QUrl(normalized).host()}, {"links", links},
                       {"nonEmailLogin", meta.value("feature.non_email_login").toBool(false)},
                       {"httpWarning", QUrl(normalized).scheme() != QStringLiteral("https")}};
}

QJsonObject AccountService::addAuthServer(const QString &name, const QString &url) {
    QJsonObject probed = probeAuthServer(url);
    if (!probed.value("success").toBool()) return QJsonObject{{"servers", authServers().value("servers")}, {"error", probed.value("message")}};
    QJsonArray servers = authServers().value("servers").toArray();
    const QString normalized = probed.value("url").toString();
    for (const QJsonValue &v : servers) if (v.toObject().value("url").toString() == normalized) return QJsonObject{{"servers", servers}};
    servers.append(QJsonObject{
        {"name", name.trimmed().isEmpty() ? probed.value("name") : QJsonValue(name.trimmed())},
        {"url", normalized},
        {"host", probed.value("host")},
        {"links", probed.value("links")},
        {"nonEmailLogin", probed.value("nonEmailLogin")}
    });
    JsonUtil::writeArrayFile(LauncherPaths::authServersFile(), servers);
    return QJsonObject{{"servers", servers}};
}

QJsonObject AccountService::deleteAuthServer(int index) {
    QJsonArray servers = authServers().value("servers").toArray();
    if (index >= 0 && index < servers.size()) servers.removeAt(index);
    JsonUtil::writeArrayFile(LauncherPaths::authServersFile(), servers);
    return QJsonObject{{"servers", servers}};
}

QJsonObject AccountService::addOffline(const QString &username, const QString &customUuid) {
    const QString name = username.trimmed().isEmpty() ? QStringLiteral("Steve") : username.trimmed();
    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) { QJsonObject a = accounts.at(i).toObject(); a["selected"] = false; accounts[i] = a; }
    QString uuid = customUuid.trimmed();
    if (uuid.isEmpty()) uuid = offlineUuid(name);
    uuid = QUuid(uuid).toString(QUuid::WithoutBraces);
    if (uuid.isEmpty()) uuid = offlineUuid(name);
    const QString avatar = defaultAvatarForUuid(uuid);
    accounts.append(QJsonObject{{"kind", "offline"}, {"username", name}, {"uuid", uuid},
                                {"accessToken", "0"}, {"selected", true}, {"avatarUrl", avatar}, {"note", "离线账户"}});
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::postJson(const QUrl &url, const QJsonObject &body, QString *errorMessage) const {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "mc-launcher-qt-cpp HMCL-yggdrasil");
    int status = 0;
    const QByteArray data = requestBytes(request, "POST", QJsonDocument(body).toJson(QJsonDocument::Compact), &status, nullptr, errorMessage);
    if (data.isEmpty()) {
        if (status == 204) return QJsonObject{};
        return {};
    }
    const QJsonObject result = QJsonDocument::fromJson(data).object();
    if (!result.value("error").toString().isEmpty() && errorMessage)
        *errorMessage = result.value("errorMessage").toString(result.value("error").toString());
    return result;
}

QJsonObject AccountService::getJson(const QUrl &url, QString *errorMessage) const {
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "mc-launcher-qt-cpp HMCL-yggdrasil");
    const QByteArray data = requestBytes(request, "GET", {}, nullptr, nullptr, errorMessage);
    return QJsonDocument::fromJson(data).object();
}

QString AccountService::profileSkinUrl(const QString &serverUrl, const QString &uuid) const {
    QString error;
    QUrl url(ensureSlash(serverUrl) + "sessionserver/session/minecraft/profile/" + compactUuid(uuid));
    QUrlQuery query; query.addQueryItem("unsigned", "false"); url.setQuery(query);
    return textureUrlFromProfile(getJson(url, &error));
}

QJsonObject AccountService::saveYggdrasilAccount(const QString &serverUrl,
                                                  const QString &loginName,
                                                  const QString &accessToken,
                                                  const QString &clientToken,
                                                  const QJsonObject &profile) {
    const QString username = profile.value("name").toString();
    QString uuid = profile.value("id").toString();
    if (uuid.size() == 32) uuid = QUuid::fromString("{" + uuid + "}").toString(QUuid::WithoutBraces);
    const QString skinUrl = profileSkinUrl(serverUrl, uuid);
    const QString avatar = avatarFromSkinUrl(uuid, skinUrl);

    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) { QJsonObject a = accounts.at(i).toObject(); a["selected"] = false; accounts[i] = a; }
    accounts.append(QJsonObject{{"kind", "yggdrasil"}, {"username", username}, {"loginName", loginName},
                                {"uuid", uuid}, {"serverUrl", ensureSlash(serverUrl)}, {"accessToken", accessToken},
                                {"clientToken", clientToken}, {"selected", true}, {"skinUrl", skinUrl},
                                {"avatarUrl", avatar}, {"note", "authlib-injector/Yggdrasil"}});
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::setOfflineSkin(int index, const QString &fileUrl,
                                                   const QString &capeFileUrl,
                                                   const QString &model,
                                                   const QString &cslApi,
                                                   const QString &skinType) {
    QJsonArray accounts = loadAccounts();
    if (index < 0 || index >= accounts.size()) return publicPayload(accounts);
    QJsonObject account = accounts.at(index).toObject();
    if (account.value("kind").toString() != QStringLiteral("offline")) return publicPayload(accounts);

    const QString uuid = account.value("uuid").toString();
    const QString normalizedType = skinType.trimmed().toLower();
    account.insert("skinType", normalizedType.isEmpty() ? QStringLiteral("default") : normalizedType);
    account.insert("skinModel", model == QStringLiteral("slim") ? QStringLiteral("slim")
                                                                 : QStringLiteral("wide"));
    account.insert("skinCslApi", cslApi.trimmed());
    account.remove("skinPath");
    account.remove("capePath");
    account.remove("skinUrl");

    QString avatar;
    if (normalizedType == QStringLiteral("local")) {
        const QString local = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
        const QString localCape = QUrl(capeFileUrl).isLocalFile()
                                      ? QUrl(capeFileUrl).toLocalFile() : capeFileUrl;
        if (!local.isEmpty() && QFileInfo::exists(local)) {
            const QString root = LauncherPaths::cacheDir() + "/offline-skins";
            QDir().mkpath(root);
            const QString target = root + "/" + compactUuid(uuid) + ".png";
            if (QFileInfo(local).canonicalFilePath() != QFileInfo(target).canonicalFilePath()) {
                QFile::remove(target);
                if (QFile::copy(local, target)) account.insert("skinPath", target);
            } else {
                account.insert("skinPath", target);
            }
            avatar = avatarFromSkinImage(uuid, account.value("skinPath").toString());
            if (!localCape.isEmpty() && QFileInfo::exists(localCape)) {
                const QString capeTarget = root + "/" + compactUuid(uuid) + "-cape.png";
                if (QFileInfo(localCape).canonicalFilePath() != QFileInfo(capeTarget).canonicalFilePath()) {
                    QFile::remove(capeTarget);
                    if (QFile::copy(localCape, capeTarget)) account.insert("capePath", capeTarget);
                } else {
                    account.insert("capePath", capeTarget);
                }
            }
        }
    } else if (normalizedType == QStringLiteral("steve")
               || normalizedType == QStringLiteral("alex")) {
        const QString skinName = normalizedType;
        const QString skinModel = skinName == QStringLiteral("alex")
                                      ? QStringLiteral("slim") : QStringLiteral("wide");
        account.insert("skinModel", skinModel);
        const QString resource = QStringLiteral(
            ":/qt/qml/com/bihrys/launcher/qml/assets/img/skin/%1/%2.png")
                                     .arg(skinModel, skinName);
        avatar = avatarFromSkinImage(uuid, resource);
    } else if (normalizedType == QStringLiteral("littleskin")
               || normalizedType == QStringLiteral("csl")) {
        QString api = normalizedType == QStringLiteral("littleskin")
                          ? QStringLiteral("https://littleskin.cn/csl")
                          : cslApi.trimmed();
        if (!api.contains("://")) api.prepend(QStringLiteral("https://"));
        while (api.endsWith('/')) api.chop(1);
        account.insert("skinCslApi", api);

        QString error;
        const QString username = account.value("username").toString();
        const QJsonObject skinJson = getJson(QUrl(api + "/" +
                                                  QString::fromUtf8(QUrl::toPercentEncoding(username)) +
                                                  ".json"), &error);
        const QJsonObject textures = skinJson.value("textures").toObject(
            skinJson.value("skins").toObject());
        QString hash;
        if (!textures.value("slim").toString().isEmpty()) {
            hash = textures.value("slim").toString();
            account.insert("skinModel", "slim");
        } else if (!textures.value("default").toString().isEmpty()) {
            hash = textures.value("default").toString();
            account.insert("skinModel", "wide");
        } else {
            hash = skinJson.value("skin").toString();
        }
        if (!hash.isEmpty()) {
            const QString remoteSkinUrl = api + "/textures/" + hash;
            account.insert("skinUrl", remoteSkinUrl);
            avatar = avatarFromSkinUrl(uuid, remoteSkinUrl);
        }
    } else {
        account.remove("skinUrl");
    }

    if (avatar.isEmpty()) avatar = defaultAvatarForUuid(uuid);
    account.insert("avatarUrl", avatar);
    accounts[index] = account;
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::authenticateYggdrasil(const QString &serverUrl,
                                                   const QString &username,
                                                   const QString &password) {
    QJsonObject metadata;
    QString error;
    const QString normalized = normalizeAuthServer(serverUrl, &metadata, &error);
    if (normalized.isEmpty()) return QJsonObject{{"success", false}, {"message", error}};
    const QString clientToken = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QJsonObject request{{"agent", QJsonObject{{"name", "Minecraft"}, {"version", 1}}},
                              {"username", username}, {"password", password},
                              {"clientToken", clientToken}, {"requestUser", true}};
    const QJsonObject response = postJson(QUrl(normalized + "authserver/authenticate"), request, &error);
    if (response.isEmpty() || !response.value("error").toString().isEmpty())
        return QJsonObject{{"success", false}, {"message", error.isEmpty() ? QStringLiteral("第三方认证失败。") : error}};

    const QString accessToken = response.value("accessToken").toString();
    const QString returnedClientToken = response.value("clientToken").toString(clientToken);
    const QJsonObject selected = response.value("selectedProfile").toObject();
    const QJsonArray profiles = response.value("availableProfiles").toArray();
    if (!selected.isEmpty()) {
        return QJsonObject{{"success", true}, {"requiresProfileSelection", false},
                           {"accounts", saveYggdrasilAccount(normalized, username, accessToken, returnedClientToken, selected).value("accounts")},
                           {"message", QString("登录成功：%1").arg(selected.value("name").toString())}};
    }
    if (profiles.size() == 1) {
        const QJsonObject profile = profiles.first().toObject();
        const QJsonObject refreshRequest{{"accessToken", accessToken}, {"clientToken", returnedClientToken},
            {"requestUser", true}, {"selectedProfile", QJsonObject{{"id", profile.value("id")}, {"name", profile.value("name")}}}};
        const QJsonObject refreshed = postJson(QUrl(normalized + "authserver/refresh"), refreshRequest, &error);
        const QJsonObject chosen = refreshed.value("selectedProfile").toObject();
        if (chosen.isEmpty()) return QJsonObject{{"success", false}, {"message", error.isEmpty() ? QStringLiteral("角色选择失败。") : error}};
        return QJsonObject{{"success", true}, {"requiresProfileSelection", false},
                           {"accounts", saveYggdrasilAccount(normalized, username, refreshed.value("accessToken").toString(accessToken),
                                                             refreshed.value("clientToken").toString(returnedClientToken), chosen).value("accounts")},
                           {"message", QString("登录成功：%1").arg(chosen.value("name").toString())}};
    }
    if (profiles.isEmpty()) return QJsonObject{{"success", false}, {"message", QStringLiteral("此账户没有可用角色。")}};

    QJsonArray publicProfiles;
    for (const QJsonValue &v : profiles) {
        const QJsonObject profile = v.toObject();
        QString uuid = profile.value("id").toString();
        if (uuid.size() == 32) uuid = QUuid::fromString("{" + uuid + "}").toString(QUuid::WithoutBraces);
        const QString skinUrl = profileSkinUrl(normalized, uuid);
        publicProfiles.append(QJsonObject{{"name", profile.value("name")}, {"id", profile.value("id")},
                                          {"uuid", uuid},
                                          {"avatarUrl", avatarFromSkinUrl(uuid, skinUrl)}});
    }
    {
        QMutexLocker locker(&m_pendingMutex);
        m_pendingYggdrasil = QJsonObject{{"serverUrl", normalized}, {"username", username},
                                         {"accessToken", accessToken}, {"clientToken", returnedClientToken},
                                         {"profiles", profiles}};
    }
    return QJsonObject{{"success", true}, {"requiresProfileSelection", true},
                       {"serverUrl", normalized}, {"username", username}, {"profiles", publicProfiles},
                       {"message", QStringLiteral("请选择要使用的角色。")}};
}

QJsonObject AccountService::selectPendingYggdrasilProfile(int index) {
    QJsonObject pending;
    {
        QMutexLocker locker(&m_pendingMutex);
        pending = m_pendingYggdrasil;
    }
    const QJsonArray profiles = pending.value("profiles").toArray();
    if (index < 0 || index >= profiles.size()) return QJsonObject{{"success", false}, {"message", QStringLiteral("角色索引无效。")}};
    const QJsonObject profile = profiles.at(index).toObject();
    const QJsonObject request{{"accessToken", pending.value("accessToken")}, {"clientToken", pending.value("clientToken")},
        {"requestUser", true}, {"selectedProfile", QJsonObject{{"id", profile.value("id")}, {"name", profile.value("name")}}}};
    QString error;
    const QString server = pending.value("serverUrl").toString();
    const QJsonObject response = postJson(QUrl(server + "authserver/refresh"), request, &error);
    const QJsonObject selected = response.value("selectedProfile").toObject();
    if (selected.isEmpty()) return QJsonObject{{"success", false}, {"message", error.isEmpty() ? QStringLiteral("角色选择失败。") : error}};
    const QJsonObject payload = saveYggdrasilAccount(server, pending.value("username").toString(),
                                                     response.value("accessToken").toString(pending.value("accessToken").toString()),
                                                     response.value("clientToken").toString(pending.value("clientToken").toString()), selected);
    { QMutexLocker locker(&m_pendingMutex); m_pendingYggdrasil = {}; }
    return QJsonObject{{"success", true}, {"accounts", payload.value("accounts")},
                       {"message", QString("登录成功：%1").arg(selected.value("name").toString())}};
}

QJsonObject AccountService::refreshAccount(int index) {
    QJsonArray accounts = loadAccounts();
    if (index < 0 || index >= accounts.size()) {
        return QJsonObject{{"success", false}, {"message", QStringLiteral("账户索引无效。")}};
    }

    QJsonObject account = accounts.at(index).toObject();
    const QString kind = account.value("kind").toString();
    if (kind == QStringLiteral("offline")) {
        const QString skinPath = account.value("skinPath").toString();
        const QString uuid = account.value("uuid").toString();
        account.insert("avatarUrl", !skinPath.isEmpty() && QFileInfo::exists(skinPath)
                                      ? avatarFromSkinImage(uuid, skinPath)
                                      : defaultAvatarForUuid(uuid));
        accounts[index] = account;
        saveAccounts(accounts);
        return QJsonObject{{"success", true}, {"accounts", publicPayload(accounts).value("accounts")},
                           {"message", QStringLiteral("离线账户已刷新。")}};
    }

    if (kind != QStringLiteral("yggdrasil")) {
        return QJsonObject{{"success", false}, {"requiresPassword", false},
                           {"message", QStringLiteral("此账户暂不支持刷新。")}};
    }

    const QString server = ensureSlash(account.value("serverUrl").toString());
    const QJsonObject request{{"accessToken", account.value("accessToken")},
                              {"clientToken", account.value("clientToken")},
                              {"requestUser", true}};
    QString error;
    const QJsonObject response = postJson(QUrl(server + "authserver/refresh"), request, &error);
    if (response.isEmpty() || !response.value("error").toString().isEmpty()) {
        return QJsonObject{{"success", false}, {"requiresPassword", true},
                           {"message", error.isEmpty()
                               ? QStringLiteral("登录状态已失效，请重新输入密码。") : error}};
    }

    account.insert("accessToken", response.value("accessToken").toString(account.value("accessToken").toString()));
    account.insert("clientToken", response.value("clientToken").toString(account.value("clientToken").toString()));
    const QJsonObject selected = response.value("selectedProfile").toObject();
    if (!selected.isEmpty()) {
        account.insert("username", selected.value("name").toString(account.value("username").toString()));
        QString uuid = selected.value("id").toString(account.value("uuid").toString());
        if (uuid.size() == 32)
            uuid = QUuid::fromString("{" + uuid + "}").toString(QUuid::WithoutBraces);
        account.insert("uuid", uuid);
    }
    const QString skinUrl = profileSkinUrl(server, account.value("uuid").toString());
    account.insert("skinUrl", skinUrl);
    account.insert("avatarUrl", avatarFromSkinUrl(account.value("uuid").toString(), skinUrl));
    accounts[index] = account;
    saveAccounts(accounts);
    return QJsonObject{{"success", true}, {"accounts", publicPayload(accounts).value("accounts")},
                       {"message", QStringLiteral("账户已刷新。")}};
}

QJsonObject AccountService::reauthenticateYggdrasil(int index, const QString &password) {
    QJsonArray accounts = loadAccounts();
    if (index < 0 || index >= accounts.size()) {
        return QJsonObject{{"success", false}, {"message", QStringLiteral("账户索引无效。")}};
    }
    QJsonObject account = accounts.at(index).toObject();
    if (account.value("kind").toString() != QStringLiteral("yggdrasil")) {
        return QJsonObject{{"success", false}, {"message", QStringLiteral("这不是第三方认证账户。")}};
    }

    QJsonObject metadata;
    QString error;
    const QString server = normalizeAuthServer(account.value("serverUrl").toString(), &metadata, &error);
    if (server.isEmpty()) return QJsonObject{{"success", false}, {"message", error}};

    const QString clientToken = account.value("clientToken").toString(
        QUuid::createUuid().toString(QUuid::WithoutBraces));
    const QString loginName = account.value("loginName").toString(account.value("username").toString());
    const QJsonObject request{{"agent", QJsonObject{{"name", "Minecraft"}, {"version", 1}}},
                              {"username", loginName}, {"password", password},
                              {"clientToken", clientToken}, {"requestUser", true}};
    QJsonObject response = postJson(QUrl(server + "authserver/authenticate"), request, &error);
    if (response.isEmpty() || !response.value("error").toString().isEmpty()) {
        return QJsonObject{{"success", false}, {"message", error.isEmpty()
            ? QStringLiteral("第三方认证失败。") : error}};
    }

    QString accessToken = response.value("accessToken").toString();
    QString returnedClientToken = response.value("clientToken").toString(clientToken);
    QJsonObject selected = response.value("selectedProfile").toObject();
    if (selected.isEmpty()) {
        const QString current = compactUuid(account.value("uuid").toString());
        const QJsonArray profiles = response.value("availableProfiles").toArray();
        for (const QJsonValue &value : profiles) {
            const QJsonObject candidate = value.toObject();
            if (compactUuid(candidate.value("id").toString()) == current) {
                selected = candidate;
                break;
            }
        }
        if (selected.isEmpty() && profiles.size() == 1) selected = profiles.first().toObject();
        if (selected.isEmpty()) {
            return QJsonObject{{"success", false},
                               {"message", QStringLiteral("认证成功，但未找到原角色。请删除账户后重新登录并选择角色。")}};
        }
        const QJsonObject refreshRequest{{"accessToken", accessToken},
            {"clientToken", returnedClientToken}, {"requestUser", true},
            {"selectedProfile", QJsonObject{{"id", selected.value("id")},
                                             {"name", selected.value("name")}}}};
        const QJsonObject refreshed = postJson(QUrl(server + "authserver/refresh"), refreshRequest, &error);
        if (!refreshed.isEmpty()) {
            response = refreshed;
            accessToken = response.value("accessToken").toString(accessToken);
            returnedClientToken = response.value("clientToken").toString(returnedClientToken);
            selected = response.value("selectedProfile").toObject(selected);
        }
    }

    QString uuid = selected.value("id").toString(account.value("uuid").toString());
    if (uuid.size() == 32)
        uuid = QUuid::fromString("{" + uuid + "}").toString(QUuid::WithoutBraces);
    account.insert("username", selected.value("name").toString(account.value("username").toString()));
    account.insert("uuid", uuid);
    account.insert("serverUrl", server);
    account.insert("accessToken", accessToken);
    account.insert("clientToken", returnedClientToken);
    const QString skinUrl = profileSkinUrl(server, uuid);
    account.insert("skinUrl", skinUrl);
    account.insert("avatarUrl", avatarFromSkinUrl(uuid, skinUrl));
    accounts[index] = account;
    saveAccounts(accounts);
    return QJsonObject{{"success", true}, {"accounts", publicPayload(accounts).value("accounts")},
                       {"message", QStringLiteral("账户重新登录完成。")}};
}

QJsonObject AccountService::uploadSkin(int index, const QString &fileUrl,
                                       const QString &model) {
    QJsonArray accounts = loadAccounts();
    if (index < 0 || index >= accounts.size()) {
        return QJsonObject{{"success", false}, {"message", QStringLiteral("账户索引无效。")}};
    }
    QJsonObject account = accounts.at(index).toObject();
    if (account.value("kind").toString() != QStringLiteral("yggdrasil")) {
        return QJsonObject{{"success", false},
                           {"message", QStringLiteral("此账户不支持第三方皮肤上传。")}};
    }

    const QString local = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    const QImage image(local);
    if (image.isNull() || image.width() != 64
        || (image.height() != 32 && image.height() != 64)) {
        return QJsonObject{{"success", false},
                           {"message", QStringLiteral("皮肤必须是 64×32 或 64×64 的 PNG 图片。")}};
    }

    const QString server = ensureSlash(account.value("serverUrl").toString());
    const QString uuid = compactUuid(account.value("uuid").toString());
    QUrl uploadUrl(server + "api/user/profile/" + uuid + "/skin");
    QNetworkRequest request(uploadUrl);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "mc-launcher-qt-cpp HMCL-skin-upload");
    request.setRawHeader("Authorization",
                         "Bearer " + account.value("accessToken").toString().toUtf8());

    auto *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    QHttpPart modelPart;
    modelPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                        QVariant(QStringLiteral("form-data; name=\"model\"")));
    const bool slimModel = isSlimSkin(image) || model == QStringLiteral("slim");
    modelPart.setBody(slimModel ? QByteArray("slim") : QByteArray());
    multiPart->append(modelPart);

    auto *skinFile = new QFile(local);
    if (!skinFile->open(QIODevice::ReadOnly)) {
        delete skinFile;
        delete multiPart;
        return QJsonObject{{"success", false},
                           {"message", QStringLiteral("无法读取皮肤文件。")}};
    }
    QHttpPart filePart;
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(QStringLiteral("image/png")));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QVariant(QStringLiteral("form-data; name=\"file\"; filename=\"skin.png\"")));
    filePart.setBodyDevice(skinFile);
    skinFile->setParent(multiPart);
    multiPart->append(filePart);

    QNetworkAccessManager manager;
    QNetworkReply *reply = manager.put(request, multiPart);
    multiPart->setParent(reply);
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    timer.start(30000);
    loop.exec();

    const bool timedOut = !timer.isActive();
    if (timedOut && !reply->isFinished()) reply->abort();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QString networkError = reply->errorString();
    const QByteArray responseBody = (!timedOut && reply->isReadable()) ? reply->readAll() : QByteArray();
    const bool success = !timedOut && reply->error() == QNetworkReply::NoError
                         && status >= 200 && status < 300;
    reply->deleteLater();
    if (!success) {
        QString message = timedOut ? QStringLiteral("上传皮肤超时。") : networkError;
        if (!responseBody.isEmpty()) message += QStringLiteral("：") + QString::fromUtf8(responseBody.left(512));
        return QJsonObject{{"success", false}, {"message", message}};
    }

    const QString skinUrl = profileSkinUrl(server, account.value("uuid").toString());
    account.insert("skinUrl", skinUrl);
    account.insert("avatarUrl", avatarFromSkinUrl(account.value("uuid").toString(), skinUrl));
    accounts[index] = account;
    saveAccounts(accounts);
    return QJsonObject{{"success", true}, {"accounts", publicPayload(accounts).value("accounts")},
                       {"message", QStringLiteral("皮肤上传完成。")}};
}

QJsonObject AccountService::cleanupAvatarCache() {
    QDir(LauncherPaths::cacheDir() + "/avatars").removeRecursively();
    QDir(LauncherPaths::cacheDir() + "/skins").removeRecursively();
    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) {
        QJsonObject account = accounts.at(i).toObject();
        const QString uuid = account.value("uuid").toString();
        if (account.value("kind").toString() == QStringLiteral("yggdrasil")) {
            QString skinUrl = profileSkinUrl(account.value("serverUrl").toString(), uuid);
            account.insert("skinUrl", skinUrl);
            account.insert("avatarUrl", avatarFromSkinUrl(uuid, skinUrl));
        } else {
            const QString skinType = account.value("skinType").toString(QStringLiteral("default"));
            const QString skinPath = account.value("skinPath").toString();
            QString avatar;
            if (skinType == QStringLiteral("local")
                && !skinPath.isEmpty() && QFileInfo::exists(skinPath)) {
                avatar = avatarFromSkinImage(uuid, skinPath);
            } else if (skinType == QStringLiteral("steve")
                       || skinType == QStringLiteral("alex")) {
                const QString skinModel = skinType == QStringLiteral("alex")
                                              ? QStringLiteral("slim") : QStringLiteral("wide");
                avatar = avatarFromSkinImage(
                    uuid, QStringLiteral(
                        ":/qt/qml/com/bihrys/launcher/qml/assets/img/skin/%1/%2.png")
                              .arg(skinModel, skinType));
            } else if ((skinType == QStringLiteral("littleskin")
                        || skinType == QStringLiteral("csl"))
                       && !account.value("skinUrl").toString().isEmpty()) {
                avatar = avatarFromSkinUrl(uuid, account.value("skinUrl").toString());
            }
            account.insert("avatarUrl", avatar.isEmpty() ? defaultAvatarForUuid(uuid) : avatar);
        }
        accounts[i] = account;
    }
    saveAccounts(accounts);
    return QJsonObject{{"success", true}, {"accounts", publicPayload(accounts).value("accounts")},
                       {"message", QStringLiteral("头像缓存清理完成。")}};
}

QJsonObject AccountService::addMicrosoftPlaceholder(const QString &clientId) {
    const QString name = QStringLiteral("MicrosoftUser");
    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) { QJsonObject a = accounts.at(i).toObject(); a["selected"] = false; accounts[i] = a; }
    const QString uuid = offlineUuid("microsoft:" + clientId);
    accounts.append(QJsonObject{{"kind", "microsoft"}, {"username", name}, {"uuid", uuid}, {"selected", true},
                                {"avatarUrl", defaultAvatarForUuid(uuid)}, {"note", "Microsoft OAuth 待接入"}});
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::switchAccountByIdentifier(const QString &kind, const QString &uuid, const QString &serverUrl) {
    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) {
        QJsonObject a = accounts.at(i).toObject();
        a["selected"] = a.value("kind").toString() == kind && a.value("uuid").toString() == uuid && a.value("serverUrl").toString() == serverUrl;
        accounts[i] = a;
    }
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::deleteAccount(int index) {
    QJsonArray accounts = loadAccounts();
    if (index >= 0 && index < accounts.size()) accounts.removeAt(index);
    bool selected = false;
    for (const auto &v : accounts) if (v.toObject().value("selected").toBool()) selected = true;
    if (!selected && !accounts.isEmpty()) { QJsonObject a = accounts.at(0).toObject(); a["selected"] = true; accounts[0] = a; }
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::selectedOrFirst(QJsonArray &accounts) const {
    for (const QJsonValue &v : accounts) if (v.toObject().value("selected").toBool()) return v.toObject();
    return accounts.isEmpty() ? QJsonObject{} : accounts.first().toObject();
}
