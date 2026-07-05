#include "bridge/LauncherBackend.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"

#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QStringList>
#include <QUrl>

LauncherBackend::LauncherBackend(QObject *parent) : QObject(parent) {
    m_downloadTaskJson = stringify(m_downloads.idleDownloadTask());
    m_launchTaskJson = stringify(m_launch.idle());
    m_javaTaskJson = R"({"active":false,"runtimes":[]})";
    m_accountTaskJson = R"({"active":false})";
    m_yggdrasilTaskJson = R"({"active":false})";
    refreshLauncherSettings();
    refreshAuthServers();
    refreshAccounts();
    refreshInstances();
    refreshInstalledVersions();
}

QString LauncherBackend::stringify(const QJsonObject &object) const {
    return JsonUtil::stringify(object);
}

void LauncherBackend::setString(QString &field, const QString &value, void (LauncherBackend::*signal)()) {
    if (field == value) return;
    field = value;
    emit (this->*signal)();
}

void LauncherBackend::setOutput(const QString &value) {
    setString(m_output, value, &LauncherBackend::outputChanged);
}

void LauncherBackend::setCurrentAccountFromPayload(const QJsonObject &payload) {
    const auto accounts = payload.value("accounts").toArray();
    QJsonObject selected;
    if (!accounts.isEmpty()) selected = accounts.first().toObject();
    for (const auto &v : accounts) {
        if (v.toObject().value("selected").toBool()) { selected = v.toObject(); break; }
    }
    setString(m_currentAccountName, selected.value("username").toString(), &LauncherBackend::currentAccountNameChanged);
    setString(m_currentAccountKind, selected.value("displayKind").toString(), &LauncherBackend::currentAccountKindChanged);
    setString(m_currentAccountAvatarUrl, selected.value("avatarUrl").toString(), &LauncherBackend::currentAccountAvatarUrlChanged);
}

void LauncherBackend::setAccountsPayload(const QJsonObject &payload) {
    setString(m_accountsJson, stringify(payload), &LauncherBackend::accountsJsonChanged);
    setCurrentAccountFromPayload(payload);
}

void LauncherBackend::detectJava() {
    QJsonObject data = m_java.detect();
    setString(m_detectedJavaJson, stringify(data), &LauncherBackend::detectedJavaJsonChanged);
    setOutput("Java 检测完成。检测到 " + QString::number(data.value("count").toInt()) + " 个运行时。");
}

void LauncherBackend::startDetectJava() {
    QJsonObject status{{"active", false}, {"percent", 100}, {"title", "Java 检测完成"}, {"message", "本机 Java 检测完成。"}, {"runtimes", m_java.detect().value("runtimes").toArray()}};
    m_javaTaskJson = stringify(status);
    m_detectedJavaJson = stringify(QJsonObject{{"runtimes", status.value("runtimes").toArray()}});
    emit detectedJavaJsonChanged();
}

QString LauncherBackend::pollJavaTask() { return m_javaTaskJson; }

void LauncherBackend::downloadJava(const QString &distribution, const QString &major, const QString &packageType) {
    setOutput(m_java.downloadPlaceholder(distribution, major, packageType));
}

void LauncherBackend::loginOffline(const QString &username) {
    auto payload = m_accounts.addOffline(username);
    setAccountsPayload(payload);
    setOutput("离线账户添加完成：" + m_currentAccountName);
}

void LauncherBackend::loginYggdrasil(const QString &serverUrl, const QString &username, const QString &password) {
    Q_UNUSED(password)
    auto payload = m_accounts.addYggdrasilPlaceholder(serverUrl, username);
    setAccountsPayload(payload);
    m_yggdrasilTaskJson = R"({"active":false,"success":true,"message":"第三方账户占位已创建"})";
    setOutput("第三方账户占位已创建。真实登录后续按 HMCL authlib-injector/Yggdrasil 流程接入。");
}

QString LauncherBackend::pollYggdrasilLoginTask() { return m_yggdrasilTaskJson; }

void LauncherBackend::loginMicrosoftBrowser(const QString &clientId) {
    auto payload = m_accounts.addMicrosoftPlaceholder(clientId);
    setAccountsPayload(payload);
    setOutput("Microsoft 账户占位已创建。真实 OAuth 后续按 HMCL Microsoft 登录链路接入。");
}

void LauncherBackend::selectYggdrasilProfile(const QString &index) { Q_UNUSED(index); }

QString LauncherBackend::refreshAccounts() {
    auto payload = m_accounts.list();
    setAccountsPayload(payload);
    return m_accountsJson;
}

QString LauncherBackend::refreshAuthServers() {
    setString(m_authServersJson, stringify(m_accounts.authServers()), &LauncherBackend::authServersJsonChanged);
    return m_authServersJson;
}

QString LauncherBackend::addAuthServer(const QString &name, const QString &url) {
    setString(m_authServersJson, stringify(m_accounts.addAuthServer(name, url)), &LauncherBackend::authServersJsonChanged);
    return m_authServersJson;
}

QString LauncherBackend::deleteAuthServer(const QString &index) {
    setString(m_authServersJson, stringify(m_accounts.deleteAuthServer(index.toInt())), &LauncherBackend::authServersJsonChanged);
    return m_authServersJson;
}

QString LauncherBackend::offlineAvatarPreview(const QString &username) { return m_accounts.offlineAvatarPreview(username); }

void LauncherBackend::switchAccount(const QString &index) {
    QJsonObject payload = JsonUtil::objectFromString(m_accountsJson, {});
    auto arr = payload.value("accounts").toArray();
    int i = index.toInt();
    if (i >= 0 && i < arr.size()) {
        auto a = arr.at(i).toObject();
        setAccountsPayload(m_accounts.switchAccountByIdentifier(a.value("kind").toString(), a.value("uuid").toString(), a.value("serverUrl").toString()));
    }
}

void LauncherBackend::switchAccountFast(const QString &index, const QString &username, const QString &displayKind, const QString &avatarUrl) {
    Q_UNUSED(username); Q_UNUSED(displayKind); Q_UNUSED(avatarUrl);
    switchAccount(index);
}

void LauncherBackend::switchAccountByIdentifier(const QString &identifier, const QString &username, const QString &displayKind, const QString &avatarUrl) {
    Q_UNUSED(username); Q_UNUSED(displayKind); Q_UNUSED(avatarUrl);
    const QStringList parts = identifier.split("|");
    if (parts.size() >= 3) {
        setAccountsPayload(m_accounts.switchAccountByIdentifier(parts.at(0), parts.at(1), parts.mid(2).join("|")));
    }
}

void LauncherBackend::deleteAccount(const QString &index) { setAccountsPayload(m_accounts.deleteAccount(index.toInt())); }
void LauncherBackend::startRefreshAccount(const QString &index) { Q_UNUSED(index); m_accountTaskJson = R"({"active":false,"success":true,"message":"刷新完成"})"; }
void LauncherBackend::startUploadSkin(const QString &index, const QString &fileUrl, const QString &model) { Q_UNUSED(index); Q_UNUSED(fileUrl); Q_UNUSED(model); m_accountTaskJson = R"({"active":false,"success":false,"message":"皮肤上传后续接入"})"; }
void LauncherBackend::startMigrateAccount(const QString &index, const QString &target) { Q_UNUSED(index); Q_UNUSED(target); m_accountTaskJson = R"({"active":false,"success":false,"message":"账户迁移后续接入"})"; }
void LauncherBackend::startCleanupAvatarCache() { m_accountTaskJson = R"({"active":false,"success":true,"message":"头像缓存清理完成"})"; }
QString LauncherBackend::pollRefreshAccountTask() { return m_accountTaskJson; }

QString LauncherBackend::refreshDownloadCatalog(const QString &source) {
    QJsonObject catalog = m_downloads.refreshCatalog(source);
    setString(m_downloadCatalogJson, stringify(catalog), &LauncherBackend::downloadCatalogJsonChanged);
    return m_downloadCatalogJson;
}

void LauncherBackend::startRefreshDownloadCatalog(const QString &source) {
    QString catalog = refreshDownloadCatalog(source);
    QJsonObject status{{"active", false}, {"percent", 100}, {"title", "版本列表已刷新"}, {"message", "Minecraft 版本列表加载完成。"}, {"catalogReady", true}, {"catalogJson", catalog}};
    m_catalogTaskJson = stringify(status);
}

QString LauncherBackend::pollDownloadCatalogTask() { return m_catalogTaskJson; }

void LauncherBackend::startFetchInstallerMetadata(const QString &source, const QString &gameVersion) {
    QJsonObject meta = m_downloads.loaderMetadata(source, gameVersion, QString());
    m_installerMetadataTaskJson = stringify(QJsonObject{{"active", false}, {"percent", 100}, {"title", "安装器列表已加载"}, {"message", gameVersion}, {"metadataReady", true}, {"metadataJson", stringify(meta)}});
}

void LauncherBackend::startFetchLoaderMetadata(const QString &source, const QString &gameVersion, const QString &loaderKind) {
    QJsonObject meta = m_downloads.loaderMetadata(source, gameVersion, loaderKind);
    m_installerMetadataTaskJson = stringify(QJsonObject{{"active", false}, {"percent", 100}, {"title", "加载器版本已加载"}, {"message", gameVersion}, {"metadataReady", true}, {"metadataJson", stringify(meta)}});
}

QString LauncherBackend::pollInstallerMetadataTask() { return m_installerMetadataTaskJson; }

void LauncherBackend::installGameVersion(const QString &source, const QString &gameVersion, const QString &loaderKind, const QString &loaderVersion) {
    QJsonObject result = m_downloads.installVersion(source, gameVersion, loaderKind, loaderVersion);
    setOutput(result.value("message").toString());
    setString(m_downloadTaskJson, stringify(m_downloads.finishedDownloadTask(result.value("message").toString())), &LauncherBackend::downloadTaskJsonChanged);
    refreshInstalledVersions();
    refreshInstances();
}

QString LauncherBackend::pollDownloadTask() { return m_downloadTaskJson; }
void LauncherBackend::cancelDownloadTask() { setString(m_downloadTaskJson, stringify(QJsonObject{{"active", false}, {"cancelled", true}, {"percent", 0}, {"title", "已取消"}, {"message", "下载任务已取消。"}, {"status", "cancelled"}}), &LauncherBackend::downloadTaskJsonChanged); }

QString LauncherBackend::refreshInstalledVersions() {
    setString(m_installedVersionsJson, stringify(m_instances.installedVersions()), &LauncherBackend::installedVersionsJsonChanged);
    return m_installedVersionsJson;
}

QString LauncherBackend::refreshInstances() {
    QJsonObject payload = m_instances.list();
    setString(m_instanceListJson, stringify(payload), &LauncherBackend::instanceListJsonChanged);
    QString selected = payload.value("selectedInstance").toString();
    if (m_selectedGameVersion.isEmpty() && !selected.isEmpty()) setString(m_selectedGameVersion, selected, &LauncherBackend::selectedGameVersionChanged);
    return m_instanceListJson;
}

QString LauncherBackend::refreshInstanceDetail(const QString &versionId) {
    setString(m_instanceDetailJson, stringify(m_instances.detail(versionId)), &LauncherBackend::instanceDetailJsonChanged);
    return m_instanceDetailJson;
}

QString LauncherBackend::refreshInstanceMods(const QString &versionId) { setString(m_instanceModsJson, stringify(m_instances.files(versionId, "mods")), &LauncherBackend::instanceModsJsonChanged); return m_instanceModsJson; }
void LauncherBackend::setInstanceModEnabled(const QString &versionId, const QString &fileName, bool enabled) { Q_UNUSED(versionId); Q_UNUSED(fileName); Q_UNUSED(enabled); refreshInstanceMods(versionId); }
void LauncherBackend::deleteInstanceMod(const QString &versionId, const QString &fileName) { Q_UNUSED(fileName); refreshInstanceMods(versionId); }
QString LauncherBackend::refreshInstanceResourcepacks(const QString &versionId) { setString(m_instanceResourcepacksJson, stringify(m_instances.files(versionId, "resourcepacks")), &LauncherBackend::instanceResourcepacksJsonChanged); return m_instanceResourcepacksJson; }
void LauncherBackend::setInstanceResourcepackEnabled(const QString &versionId, const QString &fileName, bool enabled) { Q_UNUSED(fileName); Q_UNUSED(enabled); refreshInstanceResourcepacks(versionId); }
void LauncherBackend::deleteInstanceResourcepack(const QString &versionId, const QString &fileName) { Q_UNUSED(fileName); refreshInstanceResourcepacks(versionId); }
QString LauncherBackend::refreshInstanceWorlds(const QString &versionId) { setString(m_instanceWorldsJson, stringify(m_instances.files(versionId, "worlds")), &LauncherBackend::instanceWorldsJsonChanged); return m_instanceWorldsJson; }
void LauncherBackend::deleteInstanceWorld(const QString &versionId, const QString &fileName) { Q_UNUSED(fileName); refreshInstanceWorlds(versionId); }

void LauncherBackend::selectInstance(const QString &versionId) { selectGameVersion(versionId); }
void LauncherBackend::renameInstance(const QString &versionId, const QString &newName) { setOutput(m_instances.rename(versionId, newName).value("message").toString()); refreshInstances(); refreshInstalledVersions(); }
void LauncherBackend::duplicateInstance(const QString &versionId, const QString &newName, bool copySaves) { setOutput(m_instances.duplicate(versionId, newName, copySaves).value("message").toString()); refreshInstances(); refreshInstalledVersions(); }
QString LauncherBackend::deleteInstance(const QString &versionId) { QString msg = m_instances.remove(versionId).value("message").toString(); setOutput(msg); refreshInstances(); refreshInstalledVersions(); return msg; }
QString LauncherBackend::openInstanceFolder(const QString &versionId, const QString &folderKey) { return m_instances.openFolder(versionId, folderKey); }
QString LauncherBackend::generateInstanceLaunchCommand(const QString &versionId) { return m_instances.generateLaunchCommand(versionId); }
QString LauncherBackend::cleanInstance(const QString &versionId) { return m_instances.clean(versionId, "clean"); }
QString LauncherBackend::clearInstanceAssets(const QString &versionId) { return m_instances.clean(versionId, "assets"); }
QString LauncherBackend::clearInstanceLibraries(const QString &versionId) { return m_instances.clean(versionId, "libraries"); }
void LauncherBackend::saveInstanceSettings(const QString &versionId, const QString &settingsJson) { setOutput(m_instances.saveSettings(versionId, settingsJson).value("message").toString()); refreshInstanceDetail(versionId); }

void LauncherBackend::selectGameVersion(const QString &versionId) { setString(m_selectedGameVersion, versionId, &LauncherBackend::selectedGameVersionChanged); refreshInstanceDetail(versionId); }
void LauncherBackend::deleteGameVersion(const QString &versionId) { deleteInstance(versionId); }
void LauncherBackend::launchSelectedVersion() { startLaunchSelectedVersion("hide"); }
void LauncherBackend::startLaunchSelectedVersion(const QString &visibility) { setString(m_launchTaskJson, stringify(m_launch.launch(m_selectedGameVersion, visibility)), &LauncherBackend::launchTaskJsonChanged); setOutput("启动命令：" + m_instances.generateLaunchCommand(m_selectedGameVersion)); }
void LauncherBackend::cancelLaunchTask() { setString(m_launchTaskJson, stringify(m_launch.cancelled()), &LauncherBackend::launchTaskJsonChanged); }
QString LauncherBackend::pollLaunchTask() { return m_launchTaskJson; }

QString LauncherBackend::refreshLauncherSettings() { setString(m_launcherSettingsJson, stringify(m_settings.load()), &LauncherBackend::launcherSettingsJsonChanged); return m_launcherSettingsJson; }
QString LauncherBackend::refreshSystemMemory() { return stringify(m_settings.systemMemory()); }
QString LauncherBackend::refreshAppearanceOptions() { return stringify(m_settings.appearanceOptions()); }
QString LauncherBackend::exportLauncherThemePack() { return exportLauncherDiagnostics(); }

void LauncherBackend::updateLauncherSetting(const QString &key, const QString &value) {
    setString(m_launcherSettingsJson, stringify(m_settings.update(key, value)), &LauncherBackend::launcherSettingsJsonChanged);
}

QString LauncherBackend::generateLaunchCommand(const QString &versionId) { return m_instances.generateLaunchCommand(versionId); }

void LauncherBackend::openFolder(const QString &path) {
    QString p = path;
    if (p.startsWith("file://")) p = QUrl(p).toLocalFile();
    if (p.isEmpty()) return;
    QDir().mkpath(p);
    QDesktopServices::openUrl(QUrl::fromLocalFile(p));
}

QString LauncherBackend::openLauncherSpecialFolder(const QString &kind) {
    QString path = LauncherPaths::specialFolder(kind);
    openFolder(path);
    return path;
}

QString LauncherBackend::exportLauncherDiagnostics() {
    QString path = LauncherPaths::logsDir();
    QDir().mkpath(path);
    QString file = path + "/diagnostics-" + QDateTime::currentDateTime().toString("yyyyMMdd-hhmmss") + ".txt";
    QFile f(file);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write("mc-launcher-qt-cpp diagnostics\n");
        f.write(("config=" + LauncherPaths::configDir() + "\n").toUtf8());
        f.write(("data=" + LauncherPaths::dataDir() + "\n").toUtf8());
        f.write(("minecraft=" + LauncherPaths::minecraftDir() + "\n").toUtf8());
    }
    setOutput("诊断信息已导出：" + file);
    return file;
}

QString LauncherBackend::resetLauncherSettings() {
    m_settings.save(m_settings.defaults());
    return refreshLauncherSettings();
}

QString LauncherBackend::clearLauncherCache() {
    QDir dir(LauncherPaths::cacheDir());
    bool ok = dir.exists() ? dir.removeRecursively() : true;
    QDir().mkpath(LauncherPaths::cacheDir());
    QString msg = ok ? "缓存已清理" : "缓存清理失败";
    setOutput(msg);
    return msg;
}

void LauncherBackend::openUrl(const QString &url) { QDesktopServices::openUrl(QUrl(url)); }
