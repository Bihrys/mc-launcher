#include "bridge/LauncherBackend.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"
#include "logging/AppLogger.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QPointer>
#include <QRegularExpression>
#include <QSysInfo>
#include <QStringConverter>
#include <QTextStream>
#include <QStringList>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>

namespace {
bool isValidVersionName(const QString &name) {
    if (name.isEmpty() || name == QStringLiteral(".")
            || name == QStringLiteral("..") || name == QStringLiteral("~")) {
        return false;
    }

    for (qsizetype i = 0; i < name.size(); ++i) {
        const QChar ch = name.at(i);
        const ushort value = ch.unicode();
        const bool highSurrogate = value >= 0xd800 && value <= 0xdbff;
        const bool lowSurrogate = value >= 0xdc00 && value <= 0xdfff;
        if (highSurrogate) {
            if (i + 1 >= name.size()) return false;
            const ushort next = name.at(i + 1).unicode();
            if (next < 0xdc00 || next > 0xdfff) return false;
            ++i;
            continue;
        }
        if (lowSurrogate || value == 0
                || value < 0x20 || (value >= 0x7f && value <= 0x9f)
                || ch == u'/' || ch == u':' || ch == u'!'
                || value == 0xfffd || value == 0xfffe || value == 0xffff) {
            return false;
        }
#ifdef Q_OS_WIN
        if (ch == u'<' || ch == u'>' || ch == u'"' || ch == u'\\'
                || ch == u'|' || ch == u'?' || ch == u'*') {
            return false;
        }
#endif
    }

#ifdef Q_OS_WIN
    if (name.endsWith(u'.') || name.back().isSpace()) return false;
#endif
    return true;
}

QByteArray tailOfFile(const QString &path, qint64 maxBytes = 512 * 1024) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    if (file.size() > maxBytes) file.seek(file.size() - maxBytes);
    return file.readAll();
}
}

LauncherBackend::LauncherBackend(QObject *parent) : QObject(parent) {
    AppLogScope scope("backend", "LauncherBackend.constructor");
    setObjectName("launcherBackend");

    connect(&m_launch, &LaunchService::statusChanged, this,
            [this](const QJsonObject &status) {
        setString(m_launchTaskJson, stringify(status),
                  &LauncherBackend::launchTaskJsonChanged);
        const QString state = status.value("status").toString();
        if (state == QStringLiteral("failed")) {
            setOutput(status.value("message").toString(QStringLiteral("游戏启动失败。")));
        } else if (state == QStringLiteral("gameRunning")) {
            setOutput(QString("游戏 %1 已启动。日志：%2")
                          .arg(m_selectedGameVersion,
                               status.value("gameLogFile").toString()));
        } else if (state == QStringLiteral("gameExited")) {
            setOutput(QStringLiteral("游戏已正常退出。"));
        }
    });

    m_downloadTaskJson = stringify(m_downloads.idleDownloadTask());
    m_launchTaskJson = stringify(m_launch.idle());
    m_javaTaskJson = R"({"active":false,"runtimes":[]})";
    m_accountTaskJson = R"({"active":false})";
    m_yggdrasilTaskJson = R"({"active":false})";
    m_authServerProbeTaskJson = R"({"active":false})";

    refreshLauncherSettings();
    refreshAuthServers();
    refreshAccounts();
    refreshInstances();
    refreshInstalledVersions();

    AppLogger::info("backend", "LauncherBackend.ready", QString(), {
        {"selectedGameVersion", m_selectedGameVersion},
        {"currentAccountName", m_currentAccountName},
        {"logFile", AppLogger::latestLogFile()}
    });
}

QString LauncherBackend::logFilePath() const { return AppLogger::latestLogFile(); }
QString LauncherBackend::sessionLogFilePath() const { return AppLogger::sessionLogFile(); }
QString LauncherBackend::crashLogFilePath() const { return AppLogger::crashLogFile(); }

QString LauncherBackend::stringify(const QJsonObject &object) const {
    return JsonUtil::stringify(object);
}

QString LauncherBackend::fieldName(const QString *field) const {
    if (field == &m_output) return "output";
    if (field == &m_currentAccountName) return "currentAccountName";
    if (field == &m_currentAccountKind) return "currentAccountKind";
    if (field == &m_currentAccountAvatarUrl) return "currentAccountAvatarUrl";
    if (field == &m_accountsJson) return "accountsJson";
    if (field == &m_pendingYggdrasilProfilesJson) return "pendingYggdrasilProfilesJson";
    if (field == &m_authServersJson) return "authServersJson";
    if (field == &m_downloadCatalogJson) return "downloadCatalogJson";
    if (field == &m_downloadTaskJson) return "downloadTaskJson";
    if (field == &m_installedVersionsJson) return "installedVersionsJson";
    if (field == &m_instanceListJson) return "instanceListJson";
    if (field == &m_instanceDetailJson) return "instanceDetailJson";
    if (field == &m_selectedGameVersion) return "selectedGameVersion";
    if (field == &m_launchTaskJson) return "launchTaskJson";
    if (field == &m_launcherSettingsJson) return "launcherSettingsJson";
    if (field == &m_detectedJavaJson) return "detectedJavaJson";
    if (field == &m_instanceModsJson) return "instanceModsJson";
    if (field == &m_instanceResourcepacksJson) return "instanceResourcepacksJson";
    if (field == &m_instanceWorldsJson) return "instanceWorldsJson";
    return "unknown";
}

QString LauncherBackend::summarizeFieldValue(const QString *field, const QString &value) const {
    const QString name = fieldName(field);
    if (name.endsWith("Json")) return AppLogger::summarizeJson(value);
    if (name == "output") return AppLogger::redactText(value.left(1200));
    if (name.contains("AvatarUrl")) {
        QUrl url(value);
        url.setQuery(QString());
        url.setFragment(QString());
        return url.toString();
    }
    return AppLogger::redactText(value.left(500));
}

void LauncherBackend::setString(QString &field, const QString &value,
                                void (LauncherBackend::*signal)()) {
    if (field == value) return;
    const QString property = fieldName(&field);
    const int oldLength = field.size();
    const QString oldSummary = summarizeFieldValue(&field, field);
    field = value;
    emit (this->*signal)();
    AppLogger::info("backend.state", "property_changed", QString(), {
        {"property", property},
        {"oldLength", oldLength},
        {"newLength", value.size()},
        {"old", oldSummary},
        {"new", summarizeFieldValue(&field, value)}
    });
}

void LauncherBackend::setOutput(const QString &value) {
    setString(m_output, value, &LauncherBackend::outputChanged);
}

void LauncherBackend::setCurrentAccountFromPayload(const QJsonObject &payload) {
    AppLogScope scope("backend", "setCurrentAccountFromPayload", {
        {"accountCount", payload.value("accounts").toArray().size()}
    });
    const auto accounts = payload.value("accounts").toArray();
    QJsonObject selected;
    if (!accounts.isEmpty()) selected = accounts.first().toObject();
    for (const auto &value : accounts) {
        if (value.toObject().value("selected").toBool()) {
            selected = value.toObject();
            break;
        }
    }
    setString(m_currentAccountName, selected.value("username").toString(),
              &LauncherBackend::currentAccountNameChanged);
    setString(m_currentAccountKind, selected.value("displayKind").toString(),
              &LauncherBackend::currentAccountKindChanged);
    setString(m_currentAccountAvatarUrl, selected.value("avatarUrl").toString(),
              &LauncherBackend::currentAccountAvatarUrlChanged);
}

void LauncherBackend::setAccountsPayload(const QJsonObject &payload) {
    AppLogScope scope("backend", "setAccountsPayload", {
        {"accountCount", payload.value("accounts").toArray().size()}
    });
    setString(m_accountsJson, stringify(payload), &LauncherBackend::accountsJsonChanged);
    setCurrentAccountFromPayload(payload);
}

void LauncherBackend::finishJavaOperation(const QJsonObject &result,
                                          const QString &fallbackTitle) {
    const bool cancelled = result.value("cancelled").toBool(false);
    const bool success = result.value("success").toBool(false) && !cancelled;
    const QString message = result.value("message").toString(
        cancelled ? QStringLiteral("Java 操作已取消。")
                  : (success ? fallbackTitle : QStringLiteral("Java 操作失败。")));

    if (result.value("runtimes").isArray()) {
        setString(m_detectedJavaJson, stringify(result),
                  &LauncherBackend::detectedJavaJsonChanged);
    }

    QJsonArray stages;
    if (success) {
        stages.append(QJsonObject{{"id", "hmcl.java.finished"},
                                  {"title", fallbackTitle},
                                  {"status", "success"},
                                  {"count", 1}, {"total", 1}});
    } else if (cancelled) {
        stages.append(QJsonObject{{"id", "hmcl.java.cancelled"},
                                  {"title", "已取消"},
                                  {"status", "failed"},
                                  {"count", 0}, {"total", 1}});
    } else {
        stages.append(QJsonObject{{"id", "hmcl.java.failed"},
                                  {"title", "Java 操作失败"},
                                  {"status", "failed"},
                                  {"count", 0}, {"total", 1}});
    }

    m_javaTaskJson = stringify(QJsonObject{
        {"kind", "java"}, {"active", false}, {"success", success},
        {"cancelled", cancelled}, {"canCancel", false},
        {"status", cancelled ? "cancelled" : (success ? "finished" : "failed")},
        {"percent", success ? 100 : 0},
        {"title", cancelled ? QStringLiteral("Java 下载已取消")
                             : (success ? fallbackTitle : QStringLiteral("Java 操作失败"))},
        {"message", message}, {"speed", 0}, {"speedText", "0 B/s"},
        {"files", QJsonArray{}}, {"stages", stages},
        {"runtimes", result.value("runtimes").toArray()},
        {"disabled", result.value("disabled").toArray()},
        {"result", result}
    });
    setOutput(message);
    AppLogger::info("backend.state", "java_task_changed", QString(), {
        {"success", success}, {"cancelled", cancelled},
        {"runtimeCount", result.value("runtimes").toArray().size()},
        {"disabledCount", result.value("disabled").toArray().size()},
        {"summary", AppLogger::summarizeJson(m_javaTaskJson)}
    });
}

void LauncherBackend::startJavaOperation(const QString &title,
                                         const QString &message,
                                         std::function<QJsonObject()> operation) {
    const quint64 requestSerial = ++m_javaRequestSerial;
    m_javaCancellation.reset();
    m_javaTaskJson = stringify(QJsonObject{
        {"kind", "java"}, {"active", true}, {"success", false},
        {"cancelled", false}, {"canCancel", false}, {"status", "preparing"},
        {"percent", 5}, {"title", title}, {"message", message},
        {"speed", 0}, {"speedText", "0 B/s"}, {"files", QJsonArray{}},
        {"stages", QJsonArray{QJsonObject{{"id", "hmcl.java.operation"},
                                           {"title", message}, {"status", "running"},
                                           {"count", 0}, {"total", 1}}}}
    });
    AppLogger::info("backend.state", "java_task_changed", QString(), {
        {"requestSerial", static_cast<double>(requestSerial)},
        {"summary", AppLogger::summarizeJson(m_javaTaskJson)}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, requestSerial, title]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (requestSerial != m_javaRequestSerial) {
            AppLogger::info("backend.java", "java_result_ignored", QString(), {
                {"requestSerial", static_cast<double>(requestSerial)},
                {"currentSerial", static_cast<double>(m_javaRequestSerial)}
            });
            return;
        }
        finishJavaOperation(result, title);
    });
    watcher->setFuture(QtConcurrent::run(std::move(operation)));
}

void LauncherBackend::detectJava() {
    startDetectJava();
}

void LauncherBackend::startDetectJava() {
    AppLogScope scope("backend", "startDetectJava");
    startJavaOperation(QStringLiteral("Java 检测完成"),
                       QStringLiteral("正在搜索本机 Java 运行时。"),
                       []() {
        JavaService service;
        QJsonObject result = service.detect(true);
        result.insert("message", QStringLiteral("本机 Java 检测完成。"));
        return result;
    });
}

QString LauncherBackend::pollJavaTask() { return m_javaTaskJson; }

void LauncherBackend::downloadJava(const QString &distribution,
                                   const QString &major,
                                   const QString &packageType) {
    AppLogScope scope("backend", "downloadJava", {
        {"distribution", distribution}, {"major", major}, {"packageType", packageType}
    });
    bool ok = false;
    const int javaMajor = major.trimmed().toInt(&ok);
    if (!ok || javaMajor <= 0) {
        finishJavaOperation(QJsonObject{{"success", false},
                                        {"message", QStringLiteral("Java 主版本无效。")}},
                            QStringLiteral("Java 下载完成"));
        return;
    }

    const quint64 requestSerial = ++m_javaRequestSerial;
    const QString dist = distribution;
    const QString package = packageType;
    m_javaCancellation = std::make_shared<std::atomic_bool>(false);
    const auto cancellation = m_javaCancellation;

    m_javaTaskJson = stringify(QJsonObject{
        {"kind", "java"}, {"active", true}, {"success", false},
        {"cancelled", false}, {"canCancel", true}, {"status", "preparing"},
        {"percent", 2}, {"title", QString("准备下载 Java %1").arg(javaMajor)},
        {"message", QStringLiteral("正在获取下载信息。")},
        {"speed", 0}, {"speedText", "0 B/s"}, {"files", QJsonArray{}},
        {"stages", QJsonArray{QJsonObject{{"id", "hmcl.java.metadata"},
                                           {"title", "获取 Java 下载信息"},
                                           {"status", "running"},
                                           {"count", 0}, {"total", 1}}}}
    });

    QPointer<LauncherBackend> guard(this);
    auto progressCallback = [guard, requestSerial](const QJsonObject &status) {
        if (!guard) return;
        QMetaObject::invokeMethod(guard, [guard, requestSerial, status]() {
            if (!guard || requestSerial != guard->m_javaRequestSerial) return;
            // The global task dialog polls this value. Do not synchronously
            // flush a disk log for every network buffer; that I/O was capable
            // of reducing throughput during long Java downloads.
            guard->m_javaTaskJson = guard->stringify(status);
        }, Qt::QueuedConnection);
    };

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, requestSerial]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (requestSerial != m_javaRequestSerial) return;
        m_javaCancellation.reset();
        finishJavaOperation(result, QStringLiteral("Java 下载完成"));
    });
    watcher->setFuture(QtConcurrent::run(
        [dist, javaMajor, package, progressCallback, cancellation]() {
            JavaService service;
            return service.downloadJava(dist, javaMajor, package,
                                        progressCallback, cancellation);
        }));
}

void LauncherBackend::cancelJavaTask() {
    AppLogScope scope("backend", "cancelJavaTask");
    if (m_javaCancellation) m_javaCancellation->store(true);

    QJsonObject status = JsonUtil::objectFromString(m_javaTaskJson, {});
    if (!status.value("active").toBool()) return;
    status.insert("status", "cancelling");
    status.insert("title", "正在取消 Java 下载");
    status.insert("message", "正在中止网络请求并清理临时文件。" );
    status.insert("canCancel", false);
    m_javaTaskJson = stringify(status);
}

void LauncherBackend::addJavaPath(const QString &path) {
    AppLogScope scope("backend", "addJavaPath", {{"path", path}});
    const QString value = path;
    startJavaOperation(QStringLiteral("Java 已添加"),
                       QStringLiteral("正在检查所选 Java。"),
                       [value]() {
        JavaService service;
        return service.addJavaPath(value);
    });
}

void LauncherBackend::installJavaArchive(const QString &archivePath) {
    AppLogScope scope("backend", "installJavaArchive", {{"archive", archivePath}});
    const QString value = archivePath;
    startJavaOperation(QStringLiteral("Java 安装完成"),
                       QStringLiteral("正在解压并验证 Java 压缩包。"),
                       [value]() {
        JavaService service;
        return service.installJavaArchive(value);
    });
}

void LauncherBackend::disableJava(const QString &path) {
    AppLogScope scope("backend", "disableJava", {{"path", path}});
    const QString value = path;
    startJavaOperation(QStringLiteral("Java 已禁用"),
                       QStringLiteral("正在更新 Java 禁用列表。"),
                       [value]() {
        JavaService service;
        return service.disableJava(value);
    });
}

void LauncherBackend::restoreJava(const QString &path) {
    AppLogScope scope("backend", "restoreJava", {{"path", path}});
    const QString value = path;
    startJavaOperation(QStringLiteral("Java 已恢复"),
                       QStringLiteral("正在恢复 Java。"),
                       [value]() {
        JavaService service;
        return service.restoreJava(value);
    });
}

void LauncherBackend::removeDisabledJava(const QString &path) {
    AppLogScope scope("backend", "removeDisabledJava", {{"path", path}});
    const QString value = path;
    startJavaOperation(QStringLiteral("禁用记录已移除"),
                       QStringLiteral("正在移除无效 Java 记录。"),
                       [value]() {
        JavaService service;
        return service.removeDisabledJava(value);
    });
}

void LauncherBackend::uninstallManagedJava(const QString &path) {
    AppLogScope scope("backend", "uninstallManagedJava", {{"path", path}});
    const QString value = path;
    startJavaOperation(QStringLiteral("Java 已卸载"),
                       QStringLiteral("正在删除由启动器管理的 Java。"),
                       [value]() {
        JavaService service;
        return service.uninstallManagedJava(value);
    });
}

void LauncherBackend::revealJava(const QString &path) {
    AppLogScope scope("backend", "revealJava", {{"path", path}});
    QString localPath = path.trimmed();
    if (localPath.startsWith("file:")) localPath = QUrl(localPath).toLocalFile();
    QFileInfo info(localPath);
    QString target = info.absoluteFilePath();
    if (info.isFile()) {
        QDir parent = info.dir();
        if (parent.dirName() == QStringLiteral("bin")) {
            parent.cdUp();
            if (QFileInfo::exists(parent.filePath("release")))
                target = parent.absolutePath();
            else
                target = info.absolutePath();
        } else {
            target = info.absolutePath();
        }
    }
    if (target.isEmpty() || !QFileInfo::exists(target)) {
        AppLogger::warning("backend.java", "reveal_missing", QString(), {{"path", localPath}});
        return;
    }
    const bool opened = QDesktopServices::openUrl(QUrl::fromLocalFile(target));
    AppLogger::info("backend.java", "reveal_result", QString(), {
        {"target", target}, {"opened", opened}
    });
}

void LauncherBackend::loginOffline(const QString &username) {
    AppLogScope scope("backend", "loginOffline", {{"username", username}});
    auto payload = m_accounts.addOffline(username);
    setAccountsPayload(payload);
    setOutput("离线账户添加完成：" + m_currentAccountName);
}

void LauncherBackend::loginOfflineWithUuid(const QString &username,
                                           const QString &uuid) {
    AppLogScope scope("backend", "loginOfflineWithUuid", {
        {"username", username}, {"uuidProvided", !uuid.trimmed().isEmpty()}
    });
    const auto payload = m_accounts.addOffline(username, uuid);
    setAccountsPayload(payload);
    setOutput("离线账户添加完成：" + m_currentAccountName);
}

void LauncherBackend::loginYggdrasil(const QString &serverUrl, const QString &username,
                                     const QString &password) {
    AppLogScope scope("backend", "loginYggdrasil", {
        {"serverUrl", serverUrl}, {"username", username}, {"passwordLength", password.size()}
    });
    const quint64 serial = ++m_accountRequestSerial;
    m_yggdrasilTaskJson = stringify(QJsonObject{{"active", true}, {"success", false},
        {"title", "正在登录"}, {"message", "正在连接第三方认证服务器…"}, {"percent", 20}});

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this, [this, watcher, serial]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (serial != m_accountRequestSerial) return;
        const bool success = result.value("success").toBool(false);
        const bool requiresSelection = result.value("requiresProfileSelection").toBool(false);
        if (result.value("accounts").isArray())
            setAccountsPayload(QJsonObject{{"accounts", result.value("accounts").toArray()}});
        if (requiresSelection) {
            setString(m_pendingYggdrasilProfilesJson, stringify(result),
                      &LauncherBackend::pendingYggdrasilProfilesJsonChanged);
        } else {
            setString(m_pendingYggdrasilProfilesJson, QStringLiteral("{}"),
                      &LauncherBackend::pendingYggdrasilProfilesJsonChanged);
        }
        m_yggdrasilTaskJson = stringify(QJsonObject{{"active", false}, {"success", success},
            {"requiresProfileSelection", requiresSelection},
            {"message", result.value("message").toString(success ? "登录完成" : "登录失败")},
            {"percent", success ? 100 : 0}});
        setOutput(result.value("message").toString());
    });
    watcher->setFuture(QtConcurrent::run([this, serverUrl, username, password]() {
        return m_accounts.authenticateYggdrasil(serverUrl, username, password);
    }));
}

QString LauncherBackend::pollYggdrasilLoginTask() { return m_yggdrasilTaskJson; }

void LauncherBackend::loginMicrosoftBrowser(const QString &clientId) {
    AppLogScope scope("backend", "loginMicrosoftBrowser", {
        {"clientIdLength", clientId.size()},
        {"clientIdPrefix", clientId.left(8)}
    });
    auto payload = m_accounts.addMicrosoftPlaceholder(clientId);
    setAccountsPayload(payload);
    setOutput("Microsoft 账户占位已创建。真实 OAuth 后续按 HMCL Microsoft 登录链路接入。");
}

void LauncherBackend::selectYggdrasilProfile(const QString &index) {
    AppLogScope scope("backend", "selectYggdrasilProfile", {{"index", index}});
    const QJsonObject result = m_accounts.selectPendingYggdrasilProfile(index.toInt());
    if (result.value("accounts").isArray())
        setAccountsPayload(QJsonObject{{"accounts", result.value("accounts").toArray()}});
    setString(m_pendingYggdrasilProfilesJson, QStringLiteral("{}"),
              &LauncherBackend::pendingYggdrasilProfilesJsonChanged);
    m_yggdrasilTaskJson = stringify(QJsonObject{{"active", false},
        {"success", result.value("success").toBool(false)},
        {"message", result.value("message").toString()}});
    setOutput(result.value("message").toString());
}

QString LauncherBackend::refreshAccounts() {
    AppLogScope scope("backend", "refreshAccounts");
    auto payload = m_accounts.list();
    setAccountsPayload(payload);
    return m_accountsJson;
}

QString LauncherBackend::refreshAuthServers() {
    AppLogScope scope("backend", "refreshAuthServers");
    setString(m_authServersJson, stringify(m_accounts.authServers()),
              &LauncherBackend::authServersJsonChanged);
    return m_authServersJson;
}

QString LauncherBackend::probeAuthServer(const QString &url) {
    AppLogScope scope("backend", "probeAuthServer", {{"url", url}});
    return stringify(m_accounts.probeAuthServer(url));
}

void LauncherBackend::startProbeAuthServer(const QString &url) {
    AppLogScope scope("backend", "startProbeAuthServer", {{"url", url}});
    const quint64 serial = ++m_authServerProbeRequestSerial;
    m_authServerProbeTaskJson = stringify(QJsonObject{
        {"active", true}, {"success", false}, {"percent", 15},
        {"title", "正在连接认证服务器"}, {"message", url}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, serial]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (serial != m_authServerProbeRequestSerial) return;
        QJsonObject task = result;
        task.insert("active", false);
        task.insert("percent", result.value("success").toBool(false) ? 100 : 0);
        task.insert("title", result.value("success").toBool(false)
                                  ? QStringLiteral("认证服务器信息已获取")
                                  : QStringLiteral("无法连接认证服务器"));
        m_authServerProbeTaskJson = stringify(task);
        setOutput(result.value("message").toString());
    });
    watcher->setFuture(QtConcurrent::run([this, url]() {
        return m_accounts.probeAuthServer(url);
    }));
}

QString LauncherBackend::pollAuthServerProbeTask() {
    return m_authServerProbeTaskJson;
}

QString LauncherBackend::addAuthServer(const QString &name, const QString &url) {
    AppLogScope scope("backend", "addAuthServer", {{"name", name}, {"url", url}});
    setString(m_authServersJson, stringify(m_accounts.addAuthServer(name, url)),
              &LauncherBackend::authServersJsonChanged);
    return m_authServersJson;
}

QString LauncherBackend::deleteAuthServer(const QString &index) {
    AppLogScope scope("backend", "deleteAuthServer", {{"index", index}});
    setString(m_authServersJson, stringify(m_accounts.deleteAuthServer(index.toInt())),
              &LauncherBackend::authServersJsonChanged);
    return m_authServersJson;
}

QString LauncherBackend::offlineAvatarPreview(const QString &username) {
    AppLogger::debug("backend", "offlineAvatarPreview", QString(), {{"username", username}});
    return m_accounts.offlineAvatarPreview(username);
}

QString LauncherBackend::setOfflineSkin(const QString &index, const QString &fileUrl,
                                               const QString &capeFileUrl, const QString &model,
                                               const QString &cslApi, const QString &skinType) {
    AppLogScope scope("backend", "setOfflineSkin", {
        {"index", index}, {"model", model}, {"skinType", skinType}
    });
    const QJsonObject payload = m_accounts.setOfflineSkin(index.toInt(), fileUrl, capeFileUrl,
                                                           model, cslApi, skinType);
    setAccountsPayload(payload);
    setOutput(QStringLiteral("离线账户皮肤已更新。"));
    return m_accountsJson;
}

void LauncherBackend::switchAccount(const QString &index) {
    AppLogScope scope("backend", "switchAccount", {{"index", index}});
    QJsonObject payload = JsonUtil::objectFromString(m_accountsJson, {});
    auto array = payload.value("accounts").toArray();
    const int i = index.toInt();
    if (i >= 0 && i < array.size()) {
        const auto account = array.at(i).toObject();
        setAccountsPayload(m_accounts.switchAccountByIdentifier(
            account.value("kind").toString(), account.value("uuid").toString(),
            account.value("serverUrl").toString()));
    } else {
        AppLogger::warning("backend", "switchAccount.invalid_index", QString(), {
            {"index", i}, {"accountCount", array.size()}
        });
    }
}

void LauncherBackend::switchAccountFast(const QString &index, const QString &username,
                                        const QString &displayKind, const QString &avatarUrl) {
    AppLogScope scope("backend", "switchAccountFast", {
        {"index", index}, {"username", username}, {"displayKind", displayKind},
        {"avatarUrl", avatarUrl}
    });
    switchAccount(index);
}

void LauncherBackend::switchAccountByIdentifier(const QString &identifier,
                                                const QString &username,
                                                const QString &displayKind,
                                                const QString &avatarUrl) {
    AppLogScope scope("backend", "switchAccountByIdentifier", {
        {"identifier", identifier}, {"username", username},
        {"displayKind", displayKind}, {"avatarUrl", avatarUrl}
    });
    const QStringList parts = identifier.split('|');
    if (parts.size() >= 3) {
        setAccountsPayload(m_accounts.switchAccountByIdentifier(
            parts.at(0), parts.at(1), parts.mid(2).join("|")));
    } else {
        AppLogger::warning("backend", "switchAccountByIdentifier.invalid_identifier",
                           QString(), {{"partCount", parts.size()}});
    }
}

void LauncherBackend::deleteAccount(const QString &index) {
    AppLogScope scope("backend", "deleteAccount", {{"index", index}});
    setAccountsPayload(m_accounts.deleteAccount(index.toInt()));
}

void LauncherBackend::startRefreshAccount(const QString &index) {
    AppLogScope scope("backend", "startRefreshAccount", {{"index", index}});
    const int accountIndex = index.toInt();
    const quint64 serial = ++m_accountRequestSerial;
    m_accountTaskJson = stringify(QJsonObject{
        {"active", true}, {"success", false}, {"requiresPassword", false},
        {"kind", "refresh"}, {"index", accountIndex}, {"percent", 20},
        {"title", "正在刷新账户"}, {"message", "正在验证账户登录状态…"}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, serial, accountIndex]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (serial != m_accountRequestSerial) return;

        const bool success = result.value("success").toBool(false);
        const bool requiresPassword = result.value("requiresPassword").toBool(false);
        if (success && result.value("accounts").isArray()) {
            setAccountsPayload(QJsonObject{{"accounts", result.value("accounts").toArray()}});
        }

        QJsonObject task = result;
        task.insert("active", false);
        task.insert("success", success);
        task.insert("requiresPassword", requiresPassword);
        task.insert("kind", "refresh");
        task.insert("index", accountIndex);
        task.insert("percent", success ? 100 : 0);
        task.insert("title", success ? QStringLiteral("账户刷新完成")
                                      : (requiresPassword
                                             ? QStringLiteral("需要重新登录")
                                             : QStringLiteral("账户刷新失败")));
        if (success) task.insert("accountsJson", m_accountsJson);
        m_accountTaskJson = stringify(task);
        setOutput(task.value("message").toString());
        AppLogger::info("backend.state", "account_task_changed", QString(), {
            {"success", success}, {"requiresPassword", requiresPassword},
            {"summary", AppLogger::summarizeJson(m_accountTaskJson)}
        });
    });
    watcher->setFuture(QtConcurrent::run([this, accountIndex]() {
        return m_accounts.refreshAccount(accountIndex);
    }));
}

void LauncherBackend::reauthenticateYggdrasil(const QString &index,
                                               const QString &password) {
    AppLogScope scope("backend", "reauthenticateYggdrasil", {
        {"index", index}, {"passwordLength", password.size()}
    });
    const int accountIndex = index.toInt();
    const quint64 serial = ++m_accountRequestSerial;
    m_accountTaskJson = stringify(QJsonObject{
        {"active", true}, {"success", false}, {"requiresPassword", false},
        {"kind", "reauthenticate"}, {"index", accountIndex}, {"percent", 20},
        {"title", "正在重新登录"}, {"message", "正在连接第三方认证服务器…"}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, serial, accountIndex]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (serial != m_accountRequestSerial) return;

        const bool success = result.value("success").toBool(false);
        if (success && result.value("accounts").isArray()) {
            setAccountsPayload(QJsonObject{{"accounts", result.value("accounts").toArray()}});
        }

        QJsonObject task = result;
        task.insert("active", false);
        task.insert("success", success);
        task.insert("requiresPassword", !success);
        task.insert("kind", "reauthenticate");
        task.insert("index", accountIndex);
        task.insert("percent", success ? 100 : 0);
        task.insert("title", success ? QStringLiteral("重新登录完成")
                                      : QStringLiteral("重新登录失败"));
        if (success) task.insert("accountsJson", m_accountsJson);
        m_accountTaskJson = stringify(task);
        setOutput(task.value("message").toString());
        AppLogger::info("backend.state", "account_task_changed", QString(), {
            {"success", success}, {"summary", AppLogger::summarizeJson(m_accountTaskJson)}
        });
    });
    watcher->setFuture(QtConcurrent::run([this, accountIndex, password]() {
        return m_accounts.reauthenticateYggdrasil(accountIndex, password);
    }));
}

void LauncherBackend::startUploadSkin(const QString &index, const QString &fileUrl,
                                      const QString &model) {
    AppLogScope scope("backend", "startUploadSkin", {
        {"index", index}, {"fileUrl", fileUrl}, {"model", model}
    });
    const int accountIndex = index.toInt();
    const quint64 serial = ++m_accountRequestSerial;
    m_accountTaskJson = stringify(QJsonObject{
        {"active", true}, {"success", false}, {"kind", "upload"},
        {"index", accountIndex}, {"percent", 15},
        {"title", "正在上传皮肤"}, {"message", "正在连接认证服务器…"}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, serial, accountIndex]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (serial != m_accountRequestSerial) return;
        const bool success = result.value("success").toBool(false);
        if (success && result.value("accounts").isArray()) {
            setAccountsPayload(QJsonObject{{"accounts", result.value("accounts").toArray()}});
        }
        QJsonObject task = result;
        task.insert("active", false);
        task.insert("success", success);
        task.insert("kind", "upload");
        task.insert("index", accountIndex);
        task.insert("percent", success ? 100 : 0);
        task.insert("title", success ? QStringLiteral("皮肤上传完成")
                                      : QStringLiteral("皮肤上传失败"));
        if (success) task.insert("accountsJson", m_accountsJson);
        m_accountTaskJson = stringify(task);
        setOutput(task.value("message").toString());
    });
    watcher->setFuture(QtConcurrent::run([this, accountIndex, fileUrl, model]() {
        return m_accounts.uploadSkin(accountIndex, fileUrl, model);
    }));
}

void LauncherBackend::startMigrateAccount(const QString &index, const QString &target) {
    AppLogScope scope("backend", "startMigrateAccount", {{"index", index}, {"target", target}});
    m_accountTaskJson = R"({"active":false,"success":false,"message":"账户迁移后续接入"})";
    AppLogger::info("backend.state", "account_task_changed", QString(), {
        {"summary", AppLogger::summarizeJson(m_accountTaskJson)}
    });
}

void LauncherBackend::startCleanupAvatarCache() {
    AppLogScope scope("backend", "startCleanupAvatarCache");
    const quint64 serial = ++m_accountRequestSerial;
    m_accountTaskJson = stringify(QJsonObject{
        {"active", true}, {"success", false}, {"kind", "cleanup"},
        {"percent", 15}, {"title", "正在清理头像缓存"},
        {"message", "正在重新生成玩家头像…"}
    });
    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, serial]() {
        const QJsonObject result = watcher->result();
        watcher->deleteLater();
        if (serial != m_accountRequestSerial) return;
        const bool success = result.value("success").toBool(false);
        if (success && result.value("accounts").isArray()) {
            setAccountsPayload(QJsonObject{{"accounts", result.value("accounts").toArray()}});
        }
        QJsonObject task = result;
        task.insert("active", false);
        task.insert("success", success);
        task.insert("kind", "cleanup");
        task.insert("percent", success ? 100 : 0);
        task.insert("title", success ? QStringLiteral("头像缓存清理完成")
                                      : QStringLiteral("头像缓存清理失败"));
        if (success) task.insert("accountsJson", m_accountsJson);
        m_accountTaskJson = stringify(task);
        setOutput(task.value("message").toString());
    });
    watcher->setFuture(QtConcurrent::run([this]() {
        return m_accounts.cleanupAvatarCache();
    }));
}

QString LauncherBackend::pollRefreshAccountTask() { return m_accountTaskJson; }

QString LauncherBackend::refreshDownloadCatalog(const QString &source) {
    AppLogScope scope("backend", "refreshDownloadCatalog", {{"source", source}});
    QJsonObject catalog = m_downloads.refreshCatalog(source);
    setString(m_downloadCatalogJson, stringify(catalog),
              &LauncherBackend::downloadCatalogJsonChanged);
    return m_downloadCatalogJson;
}

void LauncherBackend::startRefreshDownloadCatalog(const QString &source) {
    AppLogScope scope("backend", "startRefreshDownloadCatalog", {{"source", source}});

    const quint64 requestSerial = ++m_catalogRequestSerial;

    // HMCL's GetTask reads its ETag-backed disk cache before completing a
    // network revalidation. Publish the cached catalog immediately so opening
    // the download page does not wait for DNS/TLS/HTTP on every visit.
    const QJsonObject cachedCatalog = m_downloads.cachedCatalog(source);
    QString cachedJson;
    if (!cachedCatalog.isEmpty()) {
        cachedJson = stringify(cachedCatalog);
        setString(m_downloadCatalogJson, cachedJson,
                  &LauncherBackend::downloadCatalogJsonChanged);
    }

    m_catalogTaskJson = stringify(QJsonObject{
        {"active", true}, {"percent", cachedJson.isEmpty() ? 5 : 65},
        {"title", cachedJson.isEmpty() ? "正在获取版本列表" : "正在刷新版本列表"},
        {"message", cachedJson.isEmpty()
            ? "正在连接 Minecraft 版本源。"
            : "已显示缓存版本列表，正在后台校验更新。"},
        {"catalogReady", !cachedJson.isEmpty()}, {"catalogJson", cachedJson},
        {"usingCache", !cachedJson.isEmpty()}
    });
    AppLogger::info("backend.state", "catalog_task_changed", QString(), {
        {"requestSerial", static_cast<double>(requestSerial)},
        {"cacheReady", !cachedJson.isEmpty()},
        {"summary", AppLogger::summarizeJson(m_catalogTaskJson)}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, requestSerial, source]() {
        const QJsonObject catalog = watcher->result();
        watcher->deleteLater();

        if (requestSerial != m_catalogRequestSerial) {
            AppLogger::info("backend.download", "catalog_result_ignored", QString(), {
                {"requestSerial", static_cast<double>(requestSerial)},
                {"currentSerial", static_cast<double>(m_catalogRequestSerial)}
            });
            return;
        }

        if (catalog.isEmpty()) {
            m_catalogTaskJson = stringify(QJsonObject{
                {"active", false}, {"percent", 0}, {"title", "版本列表加载失败"},
                {"message", "无法连接版本源。请检查网络、下载源或日志后重试。"},
                {"catalogReady", false}, {"catalogJson", QString()}, {"usingCache", false}
            });
            AppLogger::warning("backend.download", "catalog_refresh_failed", QString(), {
                {"source", source}, {"requestSerial", static_cast<double>(requestSerial)}
            });
            return;
        }

        const QString catalogJson = stringify(catalog);
        setString(m_downloadCatalogJson, catalogJson,
                  &LauncherBackend::downloadCatalogJsonChanged);
        m_catalogTaskJson = stringify(QJsonObject{
            {"active", false}, {"percent", 100}, {"title", "版本列表已刷新"},
            {"message", "Minecraft 版本列表加载完成。"},
            {"catalogReady", true}, {"catalogJson", catalogJson}, {"usingCache", false}
        });
        AppLogger::info("backend.state", "catalog_task_changed", QString(), {
            {"requestSerial", static_cast<double>(requestSerial)},
            {"summary", AppLogger::summarizeJson(m_catalogTaskJson)}
        });
    });

    watcher->setFuture(QtConcurrent::run([source]() {
        DownloadService service;
        return service.refreshCatalog(source);
    }));
}

QString LauncherBackend::pollDownloadCatalogTask() { return m_catalogTaskJson; }

void LauncherBackend::startFetchInstallerMetadata(const QString &source,
                                                  const QString &gameVersion) {
    AppLogScope scope("backend", "startFetchInstallerMetadata", {
        {"source", source}, {"gameVersion", gameVersion}
    });

    const quint64 requestSerial = ++m_installerRequestSerial;
    m_installerMetadataTaskJson = stringify(QJsonObject{
        {"active", true}, {"percent", 5}, {"title", "正在加载安装器列表"},
        {"message", gameVersion}, {"metadataReady", false}, {"metadataJson", QString()}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, requestSerial, gameVersion]() {
        const QJsonObject metadata = watcher->result();
        watcher->deleteLater();
        if (requestSerial != m_installerRequestSerial) return;

        if (metadata.isEmpty()) {
            m_installerMetadataTaskJson = stringify(QJsonObject{
                {"active", false}, {"percent", 0}, {"title", "安装器列表加载失败"},
                {"message", gameVersion}, {"metadataReady", false}, {"metadataJson", QString()}
            });
            AppLogger::warning("backend.download", "installer_metadata_failed", QString(), {
                {"gameVersion", gameVersion}
            });
            return;
        }

        m_installerMetadataTaskJson = stringify(QJsonObject{
            {"active", false}, {"percent", 100}, {"title", "安装器列表已加载"},
            {"message", gameVersion}, {"metadataReady", true},
            {"metadataJson", stringify(metadata)}
        });
        AppLogger::info("backend.state", "installer_metadata_task_changed", QString(), {
            {"requestSerial", static_cast<double>(requestSerial)},
            {"summary", AppLogger::summarizeJson(m_installerMetadataTaskJson)}
        });
    });

    watcher->setFuture(QtConcurrent::run([source, gameVersion]() {
        DownloadService service;
        return service.loaderMetadata(source, gameVersion, QString());
    }));
}

void LauncherBackend::startFetchLoaderMetadata(const QString &source,
                                               const QString &gameVersion,
                                               const QString &loaderKind) {
    AppLogScope scope("backend", "startFetchLoaderMetadata", {
        {"source", source}, {"gameVersion", gameVersion}, {"loaderKind", loaderKind}
    });

    const quint64 requestSerial = ++m_installerRequestSerial;
    m_installerMetadataTaskJson = stringify(QJsonObject{
        {"active", true}, {"percent", 5},
        {"title", QString("正在加载 %1 版本").arg(loaderKind)},
        {"message", gameVersion}, {"metadataReady", false}, {"metadataJson", QString()}
    });

    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this,
            [this, watcher, requestSerial, gameVersion, loaderKind]() {
        const QJsonObject metadata = watcher->result();
        watcher->deleteLater();
        if (requestSerial != m_installerRequestSerial) return;

        if (metadata.isEmpty()) {
            m_installerMetadataTaskJson = stringify(QJsonObject{
                {"active", false}, {"percent", 0}, {"title", "加载器版本加载失败"},
                {"message", QString("%1 / %2").arg(gameVersion, loaderKind)},
                {"metadataReady", false}, {"metadataJson", QString()}
            });
            AppLogger::warning("backend.download", "loader_metadata_failed", QString(), {
                {"gameVersion", gameVersion}, {"loaderKind", loaderKind}
            });
            return;
        }

        m_installerMetadataTaskJson = stringify(QJsonObject{
            {"active", false}, {"percent", 100}, {"title", "加载器版本已加载"},
            {"message", gameVersion}, {"metadataReady", true},
            {"metadataJson", stringify(metadata)}
        });
        AppLogger::info("backend.state", "installer_metadata_task_changed", QString(), {
            {"requestSerial", static_cast<double>(requestSerial)},
            {"loaderKind", loaderKind},
            {"summary", AppLogger::summarizeJson(m_installerMetadataTaskJson)}
        });
    });

    watcher->setFuture(QtConcurrent::run([source, gameVersion, loaderKind]() {
        DownloadService service;
        return service.loaderMetadata(source, gameVersion, loaderKind);
    }));
}

QString LauncherBackend::pollInstallerMetadataTask() { return m_installerMetadataTaskJson; }

void LauncherBackend::installGameVersion(const QString &source,
                                         const QString &gameVersion,
                                         const QString &instanceName,
                                         const QString &loaderKind,
                                         const QString &loaderVersion,
                                         const QString &addonsJson) {
    AppLogScope scope("backend", "installGameVersion", {
        {"source", source}, {"gameVersion", gameVersion},
        {"instanceName", instanceName}, {"loaderKind", loaderKind},
        {"loaderVersion", loaderVersion}
    });

    const QString normalizedName = instanceName;
    if (!isValidVersionName(normalizedName)) {
        const QJsonObject failed{{"active", false}, {"cancelled", false}, {"percent", 0},
                                 {"title", "安装失败"},
                                 {"message", "版本名称无效：不能为空，不能是 .、..、~，并且不能包含 !、/、: 或控制字符。"},
                                 {"status", "failed"}};
        setString(m_downloadTaskJson, stringify(failed),
                  &LauncherBackend::downloadTaskJsonChanged);
        setOutput(failed.value("message").toString());
        return;
    }

    m_downloads.startInstall(source, gameVersion, normalizedName,
                             loaderKind, loaderVersion, addonsJson);
    m_downloadFinishRefreshed = false;
    setOutput(QString("开始安装：") + normalizedName);
    setString(m_downloadTaskJson, stringify(m_downloads.pollTask()),
              &LauncherBackend::downloadTaskJsonChanged);
}

QString LauncherBackend::pollDownloadTask() {
    QJsonObject task = m_downloads.pollTask();
    setString(m_downloadTaskJson, stringify(task), &LauncherBackend::downloadTaskJsonChanged);
    const QString status = task.value("status").toString();
    if (status == "finished" && !m_downloadFinishRefreshed) {
        m_downloadFinishRefreshed = true;
        AppLogger::info("backend", "download_finished", task.value("message").toString());
        setOutput(task.value("message").toString());
        refreshInstalledVersions();
        refreshInstances();
    }
    return m_downloadTaskJson;
}

void LauncherBackend::cancelDownloadTask() {
    AppLogScope scope("backend", "cancelDownloadTask");
    m_downloads.cancel();
    setString(m_downloadTaskJson, stringify(m_downloads.pollTask()),
              &LauncherBackend::downloadTaskJsonChanged);
}

QString LauncherBackend::refreshInstalledVersions() {
    AppLogScope scope("backend", "refreshInstalledVersions");
    setString(m_installedVersionsJson, stringify(m_instances.installedVersions()),
              &LauncherBackend::installedVersionsJsonChanged);
    return m_installedVersionsJson;
}

QString LauncherBackend::refreshInstances() {
    AppLogScope scope("backend", "refreshInstances");
    QJsonObject payload = m_instances.list();
    setString(m_instanceListJson, stringify(payload), &LauncherBackend::instanceListJsonChanged);
    QString selected = payload.value("selectedInstance").toString();
    if (m_selectedGameVersion.isEmpty() && !selected.isEmpty()) {
        setString(m_selectedGameVersion, selected, &LauncherBackend::selectedGameVersionChanged);
    }
    return m_instanceListJson;
}

QString LauncherBackend::refreshInstanceDetail(const QString &versionId) {
    AppLogScope scope("backend", "refreshInstanceDetail", {{"versionId", versionId}});
    setString(m_instanceDetailJson, stringify(m_instances.detail(versionId)),
              &LauncherBackend::instanceDetailJsonChanged);
    return m_instanceDetailJson;
}

QString LauncherBackend::refreshInstanceMods(const QString &versionId) {
    AppLogScope scope("backend", "refreshInstanceMods", {{"versionId", versionId}});
    setString(m_instanceModsJson, stringify(m_instances.files(versionId, "mods")),
              &LauncherBackend::instanceModsJsonChanged);
    return m_instanceModsJson;
}

void LauncherBackend::setInstanceModEnabled(const QString &versionId,
                                            const QString &fileName, bool enabled) {
    AppLogScope scope("backend", "setInstanceModEnabled", {
        {"versionId", versionId}, {"fileName", fileName}, {"enabled", enabled}
    });
    refreshInstanceMods(versionId);
}

void LauncherBackend::deleteInstanceMod(const QString &versionId,
                                        const QString &fileName) {
    AppLogScope scope("backend", "deleteInstanceMod", {
        {"versionId", versionId}, {"fileName", fileName}
    });
    refreshInstanceMods(versionId);
}

QString LauncherBackend::refreshInstanceResourcepacks(const QString &versionId) {
    AppLogScope scope("backend", "refreshInstanceResourcepacks", {{"versionId", versionId}});
    setString(m_instanceResourcepacksJson,
              stringify(m_instances.files(versionId, "resourcepacks")),
              &LauncherBackend::instanceResourcepacksJsonChanged);
    return m_instanceResourcepacksJson;
}

void LauncherBackend::setInstanceResourcepackEnabled(const QString &versionId,
                                                     const QString &fileName,
                                                     bool enabled) {
    AppLogScope scope("backend", "setInstanceResourcepackEnabled", {
        {"versionId", versionId}, {"fileName", fileName}, {"enabled", enabled}
    });
    refreshInstanceResourcepacks(versionId);
}

void LauncherBackend::deleteInstanceResourcepack(const QString &versionId,
                                                 const QString &fileName) {
    AppLogScope scope("backend", "deleteInstanceResourcepack", {
        {"versionId", versionId}, {"fileName", fileName}
    });
    refreshInstanceResourcepacks(versionId);
}

QString LauncherBackend::refreshInstanceWorlds(const QString &versionId) {
    AppLogScope scope("backend", "refreshInstanceWorlds", {{"versionId", versionId}});
    setString(m_instanceWorldsJson, stringify(m_instances.files(versionId, "worlds")),
              &LauncherBackend::instanceWorldsJsonChanged);
    return m_instanceWorldsJson;
}

void LauncherBackend::deleteInstanceWorld(const QString &versionId,
                                          const QString &fileName) {
    AppLogScope scope("backend", "deleteInstanceWorld", {
        {"versionId", versionId}, {"fileName", fileName}
    });
    refreshInstanceWorlds(versionId);
}

void LauncherBackend::selectInstance(const QString &versionId) {
    AppLogScope scope("backend", "selectInstance", {{"versionId", versionId}});
    selectGameVersion(versionId);
}

void LauncherBackend::renameInstance(const QString &versionId, const QString &newName) {
    AppLogScope scope("backend", "renameInstance", {
        {"versionId", versionId}, {"newName", newName}
    });
    setOutput(m_instances.rename(versionId, newName).value("message").toString());
    refreshInstances();
    refreshInstalledVersions();
}

void LauncherBackend::duplicateInstance(const QString &versionId,
                                        const QString &newName, bool copySaves) {
    AppLogScope scope("backend", "duplicateInstance", {
        {"versionId", versionId}, {"newName", newName}, {"copySaves", copySaves}
    });
    setOutput(m_instances.duplicate(versionId, newName, copySaves).value("message").toString());
    refreshInstances();
    refreshInstalledVersions();
}

QString LauncherBackend::deleteInstance(const QString &versionId) {
    AppLogScope scope("backend", "deleteInstance", {{"versionId", versionId}});
    QString message = m_instances.remove(versionId).value("message").toString();
    setOutput(message);
    refreshInstances();
    refreshInstalledVersions();
    return message;
}

QString LauncherBackend::openInstanceFolder(const QString &versionId,
                                            const QString &folderKey) {
    AppLogScope scope("backend", "openInstanceFolder", {
        {"versionId", versionId}, {"folderKey", folderKey}
    });
    return m_instances.openFolder(versionId, folderKey);
}

QString LauncherBackend::generateInstanceLaunchCommand(const QString &versionId) {
    AppLogScope scope("backend", "generateInstanceLaunchCommand", {{"versionId", versionId}});
    return m_instances.generateLaunchCommand(versionId);
}

QString LauncherBackend::cleanInstance(const QString &versionId) {
    AppLogScope scope("backend", "cleanInstance", {{"versionId", versionId}});
    return m_instances.clean(versionId, "clean");
}

QString LauncherBackend::clearInstanceAssets(const QString &versionId) {
    AppLogScope scope("backend", "clearInstanceAssets", {{"versionId", versionId}});
    return m_instances.clean(versionId, "assets");
}

QString LauncherBackend::clearInstanceLibraries(const QString &versionId) {
    AppLogScope scope("backend", "clearInstanceLibraries", {{"versionId", versionId}});
    return m_instances.clean(versionId, "libraries");
}

void LauncherBackend::saveInstanceSettings(const QString &versionId,
                                           const QString &settingsJson) {
    AppLogScope scope("backend", "saveInstanceSettings", {
        {"versionId", versionId}, {"settingsLength", settingsJson.size()},
        {"settingsSummary", AppLogger::summarizeJson(settingsJson)}
    });
    setOutput(m_instances.saveSettings(versionId, settingsJson).value("message").toString());
    refreshInstanceDetail(versionId);
}

void LauncherBackend::selectGameVersion(const QString &versionId) {
    AppLogScope scope("backend", "selectGameVersion", {{"versionId", versionId}});
    setString(m_selectedGameVersion, versionId, &LauncherBackend::selectedGameVersionChanged);
    refreshInstanceDetail(versionId);
}

void LauncherBackend::deleteGameVersion(const QString &versionId) {
    AppLogScope scope("backend", "deleteGameVersion", {{"versionId", versionId}});
    deleteInstance(versionId);
}

void LauncherBackend::launchSelectedVersion() {
    AppLogScope scope("backend", "launchSelectedVersion", {
        {"selectedGameVersion", m_selectedGameVersion}
    });
    startLaunchSelectedVersion("hide");
}

void LauncherBackend::startLaunchSelectedVersion(const QString &visibility) {
    AppLogScope scope("backend", "startLaunchSelectedVersion", {
        {"selectedGameVersion", m_selectedGameVersion}, {"visibility", visibility}
    });

    const QJsonObject account = m_accounts.selectedAccountForLaunch();
    LaunchOptions options;
    if (account.isEmpty()) {
        options.versionId = m_selectedGameVersion;
        options.error = QStringLiteral("没有可用于启动游戏的账户。请先添加或选择一个账户。");
    } else {
        options = m_instances.createLaunchOptions(m_selectedGameVersion,
                                                  account,
                                                  m_settings.load());
    }

    AppLogger::info("launch", "launch_options_generated", QString(),
                    options.diagnostics());
    m_launch.start(options, visibility);
}

void LauncherBackend::cancelLaunchTask() {
    AppLogScope scope("backend", "cancelLaunchTask");
    m_launch.cancel();
}

QString LauncherBackend::pollLaunchTask() { return stringify(m_launch.status()); }

QString LauncherBackend::refreshLauncherSettings() {
    AppLogScope scope("backend", "refreshLauncherSettings");
    setString(m_launcherSettingsJson, stringify(m_settings.load()),
              &LauncherBackend::launcherSettingsJsonChanged);
    return m_launcherSettingsJson;
}

QString LauncherBackend::refreshSystemMemory() {
    AppLogScope scope("backend", "refreshSystemMemory");
    return stringify(m_settings.systemMemory());
}

QString LauncherBackend::refreshAppearanceOptions() {
    AppLogScope scope("backend", "refreshAppearanceOptions");
    return stringify(m_settings.appearanceOptions());
}

QString LauncherBackend::exportLauncherThemePack() {
    AppLogScope scope("backend", "exportLauncherThemePack");
    return exportLauncherDiagnostics();
}

void LauncherBackend::updateLauncherSetting(const QString &key, const QString &value) {
    AppLogScope scope("backend", "updateLauncherSetting", {
        {"key", key}, {"value", value}
    });
    setString(m_launcherSettingsJson, stringify(m_settings.update(key, value)),
              &LauncherBackend::launcherSettingsJsonChanged);
}

QString LauncherBackend::generateLaunchCommand(const QString &versionId) {
    AppLogScope scope("backend", "generateLaunchCommand", {{"versionId", versionId}});
    const QJsonObject account = m_accounts.selectedAccountForLaunch();
    const LaunchOptions options = m_instances.createLaunchOptions(
        versionId, account, m_settings.load());
    return options.valid ? options.displayCommand : options.error;
}

void LauncherBackend::openFolder(const QString &path) {
    AppLogScope scope("backend", "openFolder", {{"path", path}});
    QString localPath = path;
    if (localPath.startsWith("file://")) localPath = QUrl(localPath).toLocalFile();
    if (localPath.isEmpty()) {
        AppLogger::warning("backend", "openFolder.empty_path");
        return;
    }
    QDir().mkpath(localPath);
    const bool opened = QDesktopServices::openUrl(QUrl::fromLocalFile(localPath));
    AppLogger::info("backend", "openFolder.result", QString(), {
        {"path", localPath}, {"opened", opened}
    });
}

QString LauncherBackend::openLauncherSpecialFolder(const QString &kind) {
    AppLogScope scope("backend", "openLauncherSpecialFolder", {{"kind", kind}});
    QString path = LauncherPaths::specialFolder(kind);
    openFolder(path);
    return path;
}

QString LauncherBackend::exportLauncherDiagnostics() {
    AppLogScope scope("backend", "exportLauncherDiagnostics");
    AppLogger::flush();

    const QString path = LauncherPaths::logsDir();
    QDir().mkpath(path);
    const QString filePath = path + "/diagnostics-" +
        QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss") + ".txt";
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        const QString message = "诊断信息导出失败：" + file.errorString();
        AppLogger::error("diagnostics", "export_failed", message, {{"file", filePath}});
        setOutput(message);
        return QString();
    }

    QTextStream stream(&file);
    stream.setEncoding(QStringConverter::Utf8);
    stream << "mc-launcher-qt-cpp diagnostics\n";
    stream << "generatedAt=" << QDateTime::currentDateTime().toString(Qt::ISODateWithMs) << "\n";
    stream << "sessionId=" << AppLogger::sessionId() << "\n";
    stream << "pid=" << QCoreApplication::applicationPid() << "\n";
    stream << "qtVersion=" << qVersion() << "\n";
    stream << "os=" << QSysInfo::prettyProductName() << "\n";
    stream << "kernel=" << QSysInfo::kernelType() << " " << QSysInfo::kernelVersion() << "\n";
    stream << "config=" << LauncherPaths::configDir() << "\n";
    stream << "data=" << LauncherPaths::dataDir() << "\n";
    stream << "cache=" << LauncherPaths::cacheDir() << "\n";
    stream << "minecraft=" << LauncherPaths::minecraftDir() << "\n";
    stream << "latestLog=" << AppLogger::latestLogFile() << "\n";
    stream << "sessionLog=" << AppLogger::sessionLogFile() << "\n";
    stream << "crashLog=" << AppLogger::crashLogFile() << "\n";
    stream << "selectedGameVersion=" << m_selectedGameVersion << "\n";
    stream << "currentAccountKind=" << m_currentAccountKind << "\n";
    stream << "launcherSettingsSummary=" << AppLogger::summarizeJson(m_launcherSettingsJson) << "\n";

    stream << "\n===== latest.log tail =====\n";
    stream.flush();
    file.write(tailOfFile(AppLogger::latestLogFile()));
    file.write("\n===== crash-last.log =====\n");
    file.write(tailOfFile(AppLogger::crashLogFile()));
    file.flush();

    AppLogger::info("diagnostics", "export_succeeded", QString(), {{"file", filePath}});
    setOutput("诊断信息已导出：" + filePath);
    return filePath;
}

QString LauncherBackend::resetLauncherSettings() {
    AppLogScope scope("backend", "resetLauncherSettings");
    m_settings.save(m_settings.defaults());
    return refreshLauncherSettings();
}

QString LauncherBackend::clearLauncherCache() {
    AppLogScope scope("backend", "clearLauncherCache", {{"cacheDir", LauncherPaths::cacheDir()}});
    QDir dir(LauncherPaths::cacheDir());
    bool ok = dir.exists() ? dir.removeRecursively() : true;
    QDir().mkpath(LauncherPaths::cacheDir());
    QString message = ok ? "缓存已清理" : "缓存清理失败";
    setOutput(message);
    return message;
}

void LauncherBackend::openUrl(const QString &url) {
    AppLogScope scope("backend", "openUrl", {{"url", url}});
    const bool opened = QDesktopServices::openUrl(QUrl(url));
    AppLogger::info("backend", "openUrl.result", QString(), {{"url", url}, {"opened", opened}});
}

void LauncherBackend::logUiAction(const QString &category, const QString &action,
                                  const QString &detailsJson) {
    QJsonObject parsed;
    if (!detailsJson.trimmed().isEmpty()) {
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(detailsJson.toUtf8(), &error);
        if (error.error == QJsonParseError::NoError && document.isObject()) {
            parsed = document.object();
        } else {
            parsed.insert("detailsLength", detailsJson.size());
            parsed.insert("parseError", error.errorString());
            parsed.insert("detailsPreview", AppLogger::redactText(detailsJson.left(300)));
        }
    }
    AppLogger::info(category.isEmpty() ? QStringLiteral("ui.semantic") : category,
                    action.isEmpty() ? QStringLiteral("action") : action,
                    QString(), parsed);
}

QString LauncherBackend::flushLogs() {
    AppLogger::info("ui.semantic", "flush_logs_requested");
    AppLogger::flush();
    return AppLogger::latestLogFile();
}
