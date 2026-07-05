#include "account/AccountService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"

#include <QCryptographicHash>
#include <QJsonArray>
#include <QUrl>

QJsonArray AccountService::loadAccounts() const {
    return JsonUtil::readArrayFile(LauncherPaths::accountsFile(), {});
}

bool AccountService::saveAccounts(const QJsonArray &accounts) const {
    return JsonUtil::writeArrayFile(LauncherPaths::accountsFile(), accounts);
}

QString AccountService::offlineUuid(const QString &username) const {
    auto h = QCryptographicHash::hash(("OfflinePlayer:" + username).toUtf8(), QCryptographicHash::Md5).toHex();
    QString s = QString::fromLatin1(h);
    if (s.size() >= 32) return s.mid(0,8)+"-"+s.mid(8,4)+"-"+s.mid(12,4)+"-"+s.mid(16,4)+"-"+s.mid(20,12);
    return s;
}

QString AccountService::offlineAvatarPreview(const QString &username) const {
    Q_UNUSED(username)
    // Do not hit crafatar from the hot UI path. Crafatar 521 responses block/retry in QQuickImage
    // and make the launcher feel stuttery. QML already has HMCL-style text fallback avatars.
    return QString();
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

        // Only expose a stored local/file/qrc avatar. Never synthesize an online avatar URL here.
        QString avatarUrl = a.value("avatarUrl").toString();
        if (avatarUrl.startsWith("https://crafatar.com/")) avatarUrl.clear();

        out.append(QJsonObject{
            {"username", username}, {"uuid", uuid}, {"kind", kind}, {"displayKind", displayKind},
            {"serverUrl", server}, {"avatarUrl", avatarUrl},
            {"note", a.value("note").toString()}, {"identifier", kind + "|" + uuid + "|" + server}, {"selected", selected}
        });
    }
    return QJsonObject{{"accounts", out}};
}

QJsonObject AccountService::list() {
    auto accounts = loadAccounts();
    return publicPayload(accounts);
}

QJsonObject AccountService::authServers() {
    QJsonArray fallback;
    fallback.append(QJsonObject{{"name", "LittleSkin"}, {"url", "https://littleskin.cn/api/yggdrasil"}, {"host", "littleskin.cn"}});
    QJsonArray servers = JsonUtil::readArrayFile(LauncherPaths::authServersFile(), fallback);
    if (servers.isEmpty()) servers = fallback;
    JsonUtil::writeArrayFile(LauncherPaths::authServersFile(), servers);
    return QJsonObject{{"servers", servers}};
}

QJsonObject AccountService::addAuthServer(const QString &name, const QString &url) {
    QJsonArray servers = authServers().value("servers").toArray();
    QUrl u(url);
    servers.append(QJsonObject{{"name", name.trimmed()}, {"url", url.trimmed()}, {"host", u.host()}});
    JsonUtil::writeArrayFile(LauncherPaths::authServersFile(), servers);
    return QJsonObject{{"servers", servers}};
}

QJsonObject AccountService::deleteAuthServer(int index) {
    QJsonArray servers = authServers().value("servers").toArray();
    if (index >= 0 && index < servers.size()) servers.removeAt(index);
    JsonUtil::writeArrayFile(LauncherPaths::authServersFile(), servers);
    return QJsonObject{{"servers", servers}};
}

QJsonObject AccountService::addOffline(const QString &username) {
    QString name = username.trimmed().isEmpty() ? "Steve" : username.trimmed();
    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) {
        QJsonObject a = accounts.at(i).toObject();
        a["selected"] = false;
        accounts[i] = a;
    }
    const QString uuid = offlineUuid(name);
    accounts.append(QJsonObject{{"kind", "offline"}, {"username", name}, {"uuid", uuid}, {"accessToken", "0"}, {"selected", true}, {"avatarUrl", ""}, {"note", "离线账户"}});
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::addYggdrasilPlaceholder(const QString &serverUrl, const QString &username) {
    QString name = username.trimmed().isEmpty() ? "YggdrasilPlayer" : username.trimmed();
    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) { auto a = accounts.at(i).toObject(); a["selected"] = false; accounts[i] = a; }
    const QString uuid = offlineUuid(serverUrl + name);
    accounts.append(QJsonObject{{"kind", "yggdrasil"}, {"username", name}, {"uuid", uuid}, {"serverUrl", serverUrl.trimmed()}, {"selected", true}, {"avatarUrl", ""}, {"note", "C++ 重构骨架：第三方登录接口占位，后续按 HMCL authlib-injector 流程接入"}});
    saveAccounts(accounts);
    return publicPayload(accounts);
}

QJsonObject AccountService::addMicrosoftPlaceholder(const QString &clientId) {
    QString name = clientId.trimmed().isEmpty() ? "MicrosoftUser" : "MicrosoftUser";
    QJsonArray accounts = loadAccounts();
    for (int i = 0; i < accounts.size(); ++i) { auto a = accounts.at(i).toObject(); a["selected"] = false; accounts[i] = a; }
    const QString uuid = offlineUuid("microsoft:" + clientId);
    accounts.append(QJsonObject{{"kind", "microsoft"}, {"username", name}, {"uuid", uuid}, {"selected", true}, {"avatarUrl", ""}, {"note", "C++ 重构骨架：Microsoft OAuth 后续按 HMCL MicrosoftAccountFactory 接入"}});
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
    if (!selected && !accounts.isEmpty()) { auto a = accounts.at(0).toObject(); a["selected"] = true; accounts[0] = a; }
    saveAccounts(accounts);
    return publicPayload(accounts);
}
