#include "java/JavaService.h"

#include "core/LauncherPaths.h"
#include "download/Downloader.h"
#include "logging/AppLogger.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QMap>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTemporaryDir>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>
#include <QVersionNumber>

#include <algorithm>

namespace {

QString formatSpeed(qint64 bytesPerSecond) {
    double value = static_cast<double>(qMax<qint64>(0, bytesPerSecond));
    const char *unit = "B/s";
    if (value >= 1024.0 * 1024.0) {
        value /= 1024.0 * 1024.0;
        unit = "MiB/s";
    } else if (value >= 1024.0) {
        value /= 1024.0;
        unit = "KiB/s";
    }
    return QString::number(value, 'f', value >= 10.0 ? 0 : 1) + " " + unit;
}

QString javaExecutableName() {
#ifdef Q_OS_WIN
    return QStringLiteral("java.exe");
#else
    return QStringLiteral("java");
#endif
}

QString javacExecutableName() {
#ifdef Q_OS_WIN
    return QStringLiteral("javac.exe");
#else
    return QStringLiteral("javac");
#endif
}

QString statePath() {
    LauncherPaths::ensureDir(LauncherPaths::configDir());
    return LauncherPaths::configDir() + "/java_settings.json";
}

QString cachePath() {
    LauncherPaths::ensureDir(LauncherPaths::cacheDir());
    return LauncherPaths::cacheDir() + "/java_cache.json";
}

QString managedRoot() {
    const QString root = LauncherPaths::dataDir() + "/java";
    LauncherPaths::ensureDir(root);
    return QDir(root).absolutePath();
}

QString downloadsRoot() {
    const QString root = LauncherPaths::cacheDir() + "/java-downloads";
    LauncherPaths::ensureDir(root);
    return root;
}

QString canonicalOrAbsolute(const QString &path) {
    QFileInfo info(path);
    const QString canonical = info.canonicalFilePath();
    return canonical.isEmpty() ? info.absoluteFilePath() : canonical;
}

QString normalizedVendor(QString vendor) {
    vendor = vendor.trimmed();
    if (vendor == "N/A") return {};
    if (vendor == "Oracle Corporation") return "Oracle";
    if (vendor == "Azul Systems, Inc.") return "Azul";
    if (vendor == "IBM Corporation" || vendor == "International Business Machines Corporation"
        || vendor == "Eclipse OpenJ9") return "IBM";
    if (vendor == "Eclipse Adoptium") return "Adoptium";
    if (vendor == "Amazon.com Inc.") return "Amazon";
    return vendor;
}

int parseMajor(const QString &version) {
    const QString text = version.trimmed();
    int start = text.startsWith("1.") ? 2 : 0;
    int end = start;
    while (end < text.size() && text.at(end).isDigit()) ++end;
    bool ok = false;
    const int value = text.mid(start, end - start).toInt(&ok);
    return ok ? value : -1;
}

QString normalizeArchitecture(QString arch) {
    arch = arch.trimmed().toLower();
    if (arch == "amd64" || arch == "x86_64" || arch == "x64") return "x86_64";
    if (arch == "x86" || arch == "i386" || arch == "i486" || arch == "i586" || arch == "i686") return "x86";
    if (arch == "aarch64" || arch == "arm64") return "aarch64";
    if (arch.startsWith("arm")) return "arm";
    return arch;
}

QString currentArchitecture() {
    return normalizeArchitecture(QSysInfo::currentCpuArchitecture());
}

bool architectureCompatible(const QString &arch) {
    const QString current = currentArchitecture();
    const QString candidate = normalizeArchitecture(arch);
    if (candidate.isEmpty() || current.isEmpty() || candidate == current) return true;
#if defined(Q_OS_WIN) || defined(Q_OS_LINUX)
    if (current == "x86_64" && candidate == "x86") return true;
#endif
#ifdef Q_OS_MACOS
    if (current == "aarch64" && candidate == "x86_64") return true;
#endif
    return false;
}

QMap<QString, QString> readReleaseFile(const QString &javaHome) {
    QMap<QString, QString> result;
    QFile file(QDir(javaHome).filePath("release"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return result;
    while (!file.atEnd()) {
        QString line = QString::fromUtf8(file.readLine()).trimmed();
        const int equals = line.indexOf('=');
        if (equals <= 0) continue;
        QString key = line.left(equals).trimmed();
        QString value = line.mid(equals + 1).trimmed();
        if (value.size() >= 2 && value.startsWith('"') && value.endsWith('"'))
            value = value.mid(1, value.size() - 2);
        result.insert(key, value);
    }
    return result;
}

QString runtimeCacheKey(const QString &executable) {
    QFileInfo exe(executable);
    if (!exe.exists()) return {};
    QString javaHome = exe.dir().dirName() == "bin" ? exe.dir().absolutePath() + "/.." : exe.dir().absolutePath();
    javaHome = QDir(javaHome).absolutePath();
    QFileInfo release(QDir(javaHome).filePath("release"));
    const QString raw = QString("%1:%2:%3:%4:%5")
        .arg(exe.size()).arg(exe.lastModified().toMSecsSinceEpoch())
        .arg(release.exists() ? release.size() : -1)
        .arg(release.exists() ? release.lastModified().toMSecsSinceEpoch() : -1)
        .arg(executable);
    return QString::fromLatin1(QCryptographicHash::hash(raw.toUtf8(), QCryptographicHash::Sha1).toHex());
}

QJsonObject readJsonObject(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    return doc.isObject() ? doc.object() : QJsonObject{};
}

bool writeJsonObject(const QString &path, const QJsonObject &object) {
    LauncherPaths::ensureDir(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) return false;
    file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    return file.commit();
}

QStringList jsonStringList(const QJsonValue &value) {
    QStringList out;
    for (const QJsonValue &item : value.toArray()) {
        const QString text = item.toString().trimmed();
        if (!text.isEmpty() && !out.contains(text)) out.append(text);
    }
    return out;
}

QJsonArray toJsonArray(const QStringList &values) {
    QJsonArray out;
    for (const QString &value : values) out.append(value);
    return out;
}

void addHomeCandidate(QSet<QString> &out, const QString &home) {
    if (home.trimmed().isEmpty()) return;
    const QString normalized = QDir::cleanPath(home);
    const QString normal = QDir(normalized).filePath("bin/" + javaExecutableName());
    if (QFileInfo(normal).isFile()) out.insert(canonicalOrAbsolute(normal));
#ifdef Q_OS_MACOS
    const QString bundle = QDir(normalized).filePath("jre.bundle/Contents/Home/bin/java");
    if (QFileInfo(bundle).isFile()) out.insert(canonicalOrAbsolute(bundle));
#endif
}

void searchImmediateHomes(QSet<QString> &out, const QString &root) {
    QDir dir(root);
    if (!dir.exists()) return;
    addHomeCandidate(out, root);
    const QFileInfoList entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable);
    for (const QFileInfo &entry : entries) {
        addHomeCandidate(out, entry.absoluteFilePath());
#ifdef Q_OS_MACOS
        addHomeCandidate(out, QDir(entry.absoluteFilePath()).filePath("Contents/Home"));
#endif
    }
}

void searchRecursiveJava(QSet<QString> &out, const QString &root, int limit = 256) {
    if (!QFileInfo(root).isDir()) return;
    QDirIterator it(root, QStringList{javaExecutableName()},
                    QDir::Files | QDir::Executable | QDir::NoSymLinks,
                    QDirIterator::Subdirectories);
    while (it.hasNext() && out.size() < limit) {
        const QString file = it.next();
        const QFileInfo info(file);
        if (info.dir().dirName() == "bin") out.insert(canonicalOrAbsolute(file));
    }
}

QString safeName(QString value) {
    value = value.toLower();
    value.replace(QRegularExpression("[^a-z0-9._-]+"), "-");
    value.remove(QRegularExpression("^-+|-+$"));
    return value.isEmpty() ? QStringLiteral("java") : value;
}

bool copyRecursively(const QString &source, const QString &destination) {
    QFileInfo sourceInfo(source);
    if (sourceInfo.isDir()) {
        QDir().mkpath(destination);
        QDir sourceDir(source);
        for (const QFileInfo &entry : sourceDir.entryInfoList(QDir::NoDotAndDotDot | QDir::AllEntries)) {
            if (!copyRecursively(entry.absoluteFilePath(), QDir(destination).filePath(entry.fileName())))
                return false;
        }
        return true;
    }
    QFile::remove(destination);
    return QFile::copy(source, destination);
}

QString findExtractedJavaHome(const QString &root) {
    if (QFileInfo(QDir(root).filePath("release")).isFile()
        && QFileInfo(QDir(root).filePath("bin/" + javaExecutableName())).isFile())
        return root;
    QDirIterator it(root, QStringList{"release"}, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QFileInfo release(it.next());
        const QString home = release.absolutePath();
        if (QFileInfo(QDir(home).filePath("bin/" + javaExecutableName())).isFile())
            return home;
    }
    return {};
}

QJsonObject errorResult(const QString &message) {
    return QJsonObject{{"success", false}, {"message", message}};
}

QByteArray blockingGet(const QUrl &url, QString *errorMessage = nullptr, int timeoutMs = 30000) {
    QNetworkAccessManager manager;
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "mc-launcher-qt-cpp/0.1 HMCL-java-port");
    request.setRawHeader("Accept", "application/json");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = manager.get(request);
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();
    if (!timer.isActive()) {
        reply->abort();
        if (errorMessage) *errorMessage = QStringLiteral("请求超时");
        reply->deleteLater();
        return {};
    }
    if (reply->error() != QNetworkReply::NoError) {
        if (errorMessage) *errorMessage = reply->errorString();
        reply->deleteLater();
        return {};
    }
    const QByteArray data = reply->readAll();
    reply->deleteLater();
    return data;
}

QString discoOs() {
#ifdef Q_OS_WIN
    return QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    return QStringLiteral("macos");
#else
    return QStringLiteral("linux");
#endif
}

QString discoArch() {
    const QString arch = currentArchitecture();
    if (arch == "x86_64") return "x64";
    if (arch == "x86") return "x32";
    if (arch == "aarch64") return "aarch64";
    return arch;
}

QString archiveType() {
#ifdef Q_OS_WIN
    return QStringLiteral("zip");
#else
    return QStringLiteral("tar.gz");
#endif
}

bool extractArchive(const QString &archive, const QString &destination, QString *error) {
    QDir().mkpath(destination);
    QProcess process;
    const QString lower = archive.toLower();
    if (lower.endsWith(".zip")) {
#ifdef Q_OS_WIN
        QString escapedArchive = archive;
        QString escapedDestination = destination;
        escapedArchive.replace("'", "''");
        escapedDestination.replace("'", "''");
        process.start("powershell", {"-NoProfile", "-Command",
            QString("Expand-Archive -LiteralPath '%1' -DestinationPath '%2' -Force")
                .arg(escapedArchive, escapedDestination)});
#else
        process.start("unzip", {"-q", archive, "-d", destination});
#endif
    } else {
        process.start("tar", {"-xf", archive, "-C", destination});
    }
    if (!process.waitForStarted(5000) || !process.waitForFinished(120000)) {
        process.kill();
        if (error) *error = QStringLiteral("无法启动或完成解压程序");
        return false;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (error) *error = QString::fromUtf8(process.readAllStandardError()).trimmed();
        return false;
    }
    return true;
}

} // namespace

QString JavaService::normalizeInputPath(const QString &path) const {
    QString value = path.trimmed();
    const QUrl url(value);
    if (value.startsWith("file:") && url.isLocalFile()) value = url.toLocalFile();
    return QDir::cleanPath(value);
}

QString JavaService::resolveJavaExecutable(const QString &path) const {
    const QString value = normalizeInputPath(path);
    QFileInfo info(value);
    if (info.isFile()) {
        if (info.fileName() == javaExecutableName()) return canonicalOrAbsolute(value);
        return {};
    }
    if (info.isDir()) {
        const QString direct = QDir(value).filePath("bin/" + javaExecutableName());
        if (QFileInfo(direct).isFile()) return canonicalOrAbsolute(direct);
#ifdef Q_OS_MACOS
        const QString bundle = QDir(value).filePath("Contents/Home/bin/java");
        if (QFileInfo(bundle).isFile()) return canonicalOrAbsolute(bundle);
#endif
    }
    return {};
}

QJsonObject JavaService::loadState() const {
    QJsonObject state = readJsonObject(statePath());
    if (!state.value("userJava").isArray()) state.insert("userJava", QJsonArray{});
    if (!state.value("disabledJava").isArray()) state.insert("disabledJava", QJsonArray{});
    return state;
}

bool JavaService::saveState(const QJsonObject &state) const {
    return writeJsonObject(statePath(), state);
}

QJsonObject JavaService::inspectRuntime(const QString &executable,
                                        const QJsonObject &cacheEntry) const {
    const QString real = canonicalOrAbsolute(executable);
    QFileInfo exeInfo(real);
    if (!exeInfo.isFile() || !exeInfo.isExecutable()) return {};

    const QString key = runtimeCacheKey(real);
    if (!cacheEntry.isEmpty() && cacheEntry.value("key").toString() == key) {
        QJsonObject runtime = cacheEntry.value("runtime").toObject();
        if (!runtime.isEmpty()) {
            runtime.insert("path", real);
            runtime.insert("executable", real);
            runtime.insert("exists", true);
            return runtime;
        }
    }

    QString javaHome;
    QDir binDir = exeInfo.dir();
    if (binDir.dirName() == "bin") {
        binDir.cdUp();
        javaHome = binDir.absolutePath();
    } else {
        javaHome = exeInfo.absolutePath();
    }

    QMap<QString, QString> release = readReleaseFile(javaHome);
    QString version = release.value("JAVA_VERSION");
    QString vendor = release.value("IMPLEMENTOR");
    QString arch = release.value("OS_ARCH");
    QString osName = release.value("OS_NAME");

    if (version.isEmpty() || arch.isEmpty()) {
        QProcess process;
        process.setProcessChannelMode(QProcess::MergedChannels);
        process.start(real, {"-XshowSettings:properties", "-version"});
        if (!process.waitForStarted(3000) || !process.waitForFinished(7000)) {
            process.kill();
            return {};
        }
        const QString text = QString::fromUtf8(process.readAll());
        const auto property = [&text](const QString &name) {
            const QRegularExpression re(QString("(?:^|\\n)\\s*%1\\s*=\\s*([^\\r\\n]+)")
                                            .arg(QRegularExpression::escape(name)));
            const QRegularExpressionMatch match = re.match(text);
            return match.hasMatch() ? match.captured(1).trimmed() : QString();
        };
        if (version.isEmpty()) version = property("java.version");
        if (vendor.isEmpty()) vendor = property("java.vendor");
        if (arch.isEmpty()) arch = property("os.arch");
        if (osName.isEmpty()) osName = property("os.name");
        if (version.isEmpty()) {
            const QRegularExpression re("version \\\"([^\\\"]+)\\\"");
            const auto match = re.match(text);
            if (match.hasMatch()) version = match.captured(1);
        }
    }

    if (version.isEmpty()) return {};
    const int major = parseMajor(version);
    const QString normalizedArch = normalizeArchitecture(arch);
    const bool managed = real.startsWith(managedRoot() + "/");
    const bool jdk = QFileInfo(exeInfo.dir().filePath(javacExecutableName())).isFile();

    return QJsonObject{
        {"path", real}, {"executable", real}, {"home", javaHome},
        {"version", version}, {"major", major},
        {"vendor", normalizedVendor(vendor)}, {"vendorHint", normalizedVendor(vendor)},
        {"architecture", normalizedArch}, {"os", osName},
        {"managed", managed}, {"isJdk", jdk}, {"exists", true},
        {"compatible", architectureCompatible(normalizedArch)},
        {"cacheKey", key}
    };
}

QJsonObject JavaService::detect(bool useCache) const {
    const QJsonObject state = loadState();
    const QStringList userJava = jsonStringList(state.value("userJava"));
    const QStringList disabledJava = jsonStringList(state.value("disabledJava"));
    QSet<QString> disabledSet;
    for (const QString &path : disabledJava) {
        disabledSet.insert(path);
        disabledSet.insert(canonicalOrAbsolute(path));
    }

    QJsonObject oldCache = useCache ? readJsonObject(cachePath()) : QJsonObject{};
    const QJsonObject oldEntries = oldCache.value("entries").toObject();

    QSet<QString> candidates;
    const QString pathJava = QStandardPaths::findExecutable(javaExecutableName());
    if (!pathJava.isEmpty()) candidates.insert(canonicalOrAbsolute(pathJava));

    const QStringList pathEntries = qEnvironmentVariable("PATH").split(QDir::listSeparator(), Qt::SkipEmptyParts);
    for (const QString &entry : pathEntries) {
        const QString executable = QDir(entry).filePath(javaExecutableName());
        if (QFileInfo(executable).isFile()) candidates.insert(canonicalOrAbsolute(executable));
    }
    for (const char *name : {"JAVA_HOME", "JDK_HOME"}) addHomeCandidate(candidates, qEnvironmentVariable(name));
    for (const QString &home : qEnvironmentVariable("HMCL_JRES").split(QDir::listSeparator(), Qt::SkipEmptyParts))
        addHomeCandidate(candidates, home);

#ifdef Q_OS_LINUX
    for (const QString &root : {QStringLiteral("/usr/java"), QStringLiteral("/usr/lib/jvm"),
                                QStringLiteral("/usr/lib32/jvm"), QStringLiteral("/usr/lib64/jvm")})
        searchImmediateHomes(candidates, root);
    searchImmediateHomes(candidates, QDir::homePath() + "/.sdkman/candidates/java");
    searchImmediateHomes(candidates, QDir::homePath() + "/.jdks");
#elif defined(Q_OS_MACOS)
    searchImmediateHomes(candidates, "/Library/Java/JavaVirtualMachines");
    searchImmediateHomes(candidates, QDir::homePath() + "/Library/Java/JavaVirtualMachines");
    addHomeCandidate(candidates, "/opt/homebrew/opt/java");
#elif defined(Q_OS_WIN)
    searchImmediateHomes(candidates, qEnvironmentVariable("ProgramFiles") + "/Java");
    searchImmediateHomes(candidates, qEnvironmentVariable("ProgramFiles(x86)") + "/Java");
#endif

    searchRecursiveJava(candidates, managedRoot());
    searchRecursiveJava(candidates, QDir::homePath() + "/.minecraft/runtime");
    for (const QString &path : userJava) {
        const QString executable = resolveJavaExecutable(path);
        if (!executable.isEmpty()) candidates.insert(executable);
    }

    QJsonArray runtimes;
    QJsonObject newEntries;
    for (const QString &candidate : candidates) {
        if (disabledSet.contains(candidate)) continue;
        const QJsonObject runtime = inspectRuntime(candidate, oldEntries.value(candidate).toObject());
        if (runtime.isEmpty() || !runtime.value("compatible").toBool(true)) continue;
        runtimes.append(runtime);
        newEntries.insert(candidate, QJsonObject{{"key", runtime.value("cacheKey")}, {"runtime", runtime}});
    }

    QList<QJsonObject> sorted;
    sorted.reserve(runtimes.size());
    for (const QJsonValue &value : runtimes) sorted.append(value.toObject());
    std::sort(sorted.begin(), sorted.end(), [](const QJsonObject &a, const QJsonObject &b) {
        if (a.value("managed").toBool() != b.value("managed").toBool())
            return a.value("managed").toBool();
        const int majorA = a.value("major").toInt(-1);
        const int majorB = b.value("major").toInt(-1);
        if (majorA != majorB) return majorA < majorB;
        const int versionCompare = QVersionNumber::compare(
            QVersionNumber::fromString(a.value("version").toString()),
            QVersionNumber::fromString(b.value("version").toString()));
        if (versionCompare != 0) return versionCompare < 0;
        return a.value("path").toString() < b.value("path").toString();
    });
    runtimes = QJsonArray{};
    for (const QJsonObject &runtime : sorted) runtimes.append(runtime);

    QJsonArray disabled;
    for (const QString &path : disabledJava) {
        const QString real = canonicalOrAbsolute(path);
        disabled.append(QJsonObject{{"path", path}, {"realPath", QFileInfo::exists(real) ? real : QString()},
                                    {"exists", QFileInfo::exists(real)}});
    }

    writeJsonObject(cachePath(), QJsonObject{{"version", "1"}, {"entries", newEntries},
                                             {"savedAt", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)}});

    AppLogger::info("java.management", "lookup_finished", QString(), {
        {"runtimeCount", runtimes.size()}, {"disabledCount", disabled.size()},
        {"candidateCount", candidates.size()}, {"usedCache", useCache}
    });
    return QJsonObject{{"success", true}, {"runtimes", runtimes}, {"disabled", disabled},
                       {"count", runtimes.size()}, {"disabledCount", disabled.size()}};
}

QJsonObject JavaService::addJavaPath(const QString &path) const {
    const QString executable = resolveJavaExecutable(path);
    if (executable.isEmpty()) return errorResult("所选路径不是有效的 Java 可执行文件或 Java 主目录。");
    const QJsonObject runtime = inspectRuntime(executable);
    if (runtime.isEmpty()) return errorResult("无法读取该 Java 的版本和平台信息。");
    if (!runtime.value("compatible").toBool(true)) return errorResult("该 Java 与当前系统架构不兼容。");

    QJsonObject state = loadState();
    QStringList users = jsonStringList(state.value("userJava"));
    QStringList disabled = jsonStringList(state.value("disabledJava"));
    disabled.removeAll(executable);
    disabled.removeAll(path);
    if (!users.contains(executable)) users.append(executable);
    state.insert("userJava", toJsonArray(users));
    state.insert("disabledJava", toJsonArray(disabled));
    if (!saveState(state)) return errorResult("无法保存 Java 管理配置。");

    QJsonObject result = detect(false);
    result.insert("message", "Java 已添加：" + executable);
    return result;
}

QJsonObject JavaService::disableJava(const QString &path) const {
    const QString executable = resolveJavaExecutable(path).isEmpty()
        ? normalizeInputPath(path) : resolveJavaExecutable(path);
    if (executable.startsWith(managedRoot() + "/"))
        return errorResult("由启动器管理的 Java 应使用卸载操作，而不是禁用。");

    QJsonObject state = loadState();
    QStringList users = jsonStringList(state.value("userJava"));
    QStringList disabled = jsonStringList(state.value("disabledJava"));
    users.removeAll(executable);
    if (!disabled.contains(executable)) disabled.append(executable);
    state.insert("userJava", toJsonArray(users));
    state.insert("disabledJava", toJsonArray(disabled));
    if (!saveState(state)) return errorResult("无法保存 Java 管理配置。");
    QJsonObject result = detect(false);
    result.insert("message", "Java 已禁用。");
    return result;
}

QJsonObject JavaService::restoreJava(const QString &path) const {
    const QString input = normalizeInputPath(path);
    QJsonObject state = loadState();
    QStringList users = jsonStringList(state.value("userJava"));
    QStringList disabled = jsonStringList(state.value("disabledJava"));
    disabled.removeAll(input);
    disabled.removeAll(canonicalOrAbsolute(input));
    const QString executable = resolveJavaExecutable(input);
    if (!executable.isEmpty() && !users.contains(executable)) users.append(executable);
    state.insert("userJava", toJsonArray(users));
    state.insert("disabledJava", toJsonArray(disabled));
    if (!saveState(state)) return errorResult("无法保存 Java 管理配置。");
    QJsonObject result = detect(false);
    result.insert("message", executable.isEmpty() ? "禁用记录已移除；原文件已不存在。" : "Java 已重新启用。");
    return result;
}

QJsonObject JavaService::removeDisabledJava(const QString &path) const {
    const QString input = normalizeInputPath(path);
    QJsonObject state = loadState();
    QStringList disabled = jsonStringList(state.value("disabledJava"));
    disabled.removeAll(input);
    disabled.removeAll(canonicalOrAbsolute(input));
    state.insert("disabledJava", toJsonArray(disabled));
    if (!saveState(state)) return errorResult("无法保存 Java 管理配置。");
    QJsonObject result = detect(false);
    result.insert("message", "禁用记录已移除。");
    return result;
}

QJsonObject JavaService::uninstallManagedJava(const QString &path) const {
    const QString executable = resolveJavaExecutable(path);
    if (executable.isEmpty() || !executable.startsWith(managedRoot() + "/"))
        return errorResult("该 Java 不是由启动器管理的安装项。");
    const QString relative = QDir(managedRoot()).relativeFilePath(executable);
    const QString name = relative.section('/', 0, 0);
    if (name.isEmpty() || name == "." || name == "..") return errorResult("无法确定 Java 安装目录。");
    QDir installDir(QDir(managedRoot()).filePath(name));
    if (!installDir.removeRecursively()) return errorResult("无法删除 Java 安装目录：" + installDir.absolutePath());
    QJsonObject result = detect(false);
    result.insert("message", "Java 已卸载。");
    return result;
}

QJsonObject JavaService::installJavaArchive(const QString &archivePath) const {
    const QString archive = normalizeInputPath(archivePath);
    if (!QFileInfo(archive).isFile()) return errorResult("Java 压缩包不存在。");

    const QString temp = managedRoot() + "/.tmp/" + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString extractError;
    if (!extractArchive(archive, temp, &extractError)) {
        QDir(temp).removeRecursively();
        return errorResult("Java 压缩包解压失败：" + extractError);
    }
    const QString extractedHome = findExtractedJavaHome(temp);
    if (extractedHome.isEmpty()) {
        QDir(temp).removeRecursively();
        return errorResult("压缩包中没有找到 release 文件和 bin/java。");
    }

    const QString executable = QDir(extractedHome).filePath("bin/" + javaExecutableName());
    const QJsonObject inspected = inspectRuntime(executable);
    if (inspected.isEmpty() || !inspected.value("compatible").toBool(true)) {
        QDir(temp).removeRecursively();
        return errorResult("压缩包中的 Java 无效或与当前平台不兼容。");
    }

    const QString installName = safeName(QString("archive-%1-%2")
        .arg(inspected.value("major").toInt()).arg(inspected.value("version").toString()));
    const QString destination = QDir(managedRoot()).filePath(installName);
    QDir(destination).removeRecursively();
    bool moved = QDir().rename(extractedHome, destination);
    if (!moved) {
        moved = copyRecursively(extractedHome, destination);
    }
    QDir(temp).removeRecursively();
    if (!moved) return errorResult("无法写入 Java 安装目录。");

    writeJsonObject(QDir(destination).filePath(".mc-launcher-java.json"),
                    QJsonObject{{"provider", "archive"}, {"source", archive},
                                {"installedAt", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)}});
    QJsonObject result = detect(false);
    result.insert("message", "Java 压缩包安装完成。");
    return result;
}

QJsonObject JavaService::downloadJava(
    const QString &distribution,
    int major,
    const QString &packageType,
    const std::function<void(const QJsonObject &)> &progress,
    std::shared_ptr<std::atomic_bool> cancellation) const {
    const auto cancelled = [&]() {
        return cancellation && cancellation->load();
    };
    const auto publish = [&](const QJsonObject &status) {
        if (progress) progress(status);
    };
    const auto cancelledResult = []() {
        return QJsonObject{{"success", false}, {"cancelled", true},
                           {"message", QStringLiteral("Java 下载已取消。")}};
    };

    if (major <= 0) return errorResult("Java 主版本无效。");
    const QString dist = distribution.trimmed().toLower();
    const QString package = packageType.trimmed().toLower();
    if (dist.isEmpty() || (package != "jdk" && package != "jre"))
        return errorResult("Java 发行版或包类型无效。");

    publish(QJsonObject{
        {"active", true}, {"success", false}, {"cancelled", false},
        {"canCancel", true}, {"status", "preparing"}, {"percent", 3},
        {"title", QString("正在获取 Java %1 %2").arg(major).arg(package.toUpper())},
        {"message", QStringLiteral("正在连接 Foojay Disco 元数据服务。")},
        {"speed", 0}, {"speedText", "0 B/s"}, {"files", QJsonArray{}},
        {"stages", QJsonArray{QJsonObject{{"id", "hmcl.java.metadata"},
                                           {"title", "获取 Java 下载信息"},
                                           {"status", "running"},
                                           {"count", 0}, {"total", 1}}}}
    });

    QUrl api("https://api.foojay.io/disco/v3.0/packages");
    QUrlQuery query;
    query.addQueryItem("distribution", dist);
    query.addQueryItem("operating_system", discoOs());
    query.addQueryItem("architecture", discoArch());
    query.addQueryItem("archive_type", archiveType());
    query.addQueryItem("directly_downloadable", "true");
#ifdef Q_OS_LINUX
    query.addQueryItem("lib_c_type", "glibc");
#endif
    api.setQuery(query);

    QString fetchError;
    const QByteArray data = blockingGet(api, &fetchError);
    if (cancelled()) return cancelledResult();
    if (data.isEmpty()) return errorResult("获取 Java 下载列表失败：" + fetchError);
    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return errorResult("Java 下载列表格式无效：" + parseError.errorString());

    const QJsonArray packages = document.object().value("result").toArray();
    QJsonObject selected;
    for (const QJsonValue &value : packages) {
        const QJsonObject item = value.toObject();
        const int itemMajor = item.value("jdk_version").toInt(item.value("major_version").toInt());
        if (itemMajor != major) continue;
        if (item.value("distribution").toString().compare(dist, Qt::CaseInsensitive) != 0) continue;
        if (item.value("package_type").toString().compare(package, Qt::CaseInsensitive) != 0) continue;
        if (!item.value("directly_downloadable").toBool()) continue;
        if (item.value("javafx_bundled").toBool()) continue;
        if (item.value("archive_type").toString() != archiveType()) continue;
        if (selected.isEmpty()) {
            selected = item;
        } else {
            const QVersionNumber a = QVersionNumber::fromString(item.value("distribution_version").toString());
            const QVersionNumber b = QVersionNumber::fromString(selected.value("distribution_version").toString());
            if (QVersionNumber::compare(a, b) > 0) selected = item;
        }
    }
    if (selected.isEmpty()) return errorResult("没有找到适用于当前平台的 Java 下载包。");

    const QJsonObject links = selected.value("links").toObject();
    const QUrl downloadUrl(links.value("pkg_download_redirect").toString());
    if (!downloadUrl.isValid()) return errorResult("Java 下载地址无效。");
    QString fileName = selected.value("filename").toString();
    if (fileName.isEmpty())
        fileName = QString("%1-%2-%3.%4").arg(dist).arg(major).arg(package).arg(archiveType());
    const QString archive = QDir(downloadsRoot()).filePath(fileName);
    const qint64 expectedSize = static_cast<qint64>(selected.value("size").toDouble(
        selected.value("download_size").toDouble()));

    Downloader downloader;
    downloader.setConcurrency(1);
    downloader.setCancellationFlag(cancellation);
    QObject::connect(&downloader, &Downloader::progress, &downloader,
        [&](int finished, int total, qint64 bytes, const QString &current,
            qint64 speed, const QJsonArray &files, const QJsonObject &) {
            const int percent = expectedSize > 0
                ? qBound(5, static_cast<int>(bytes * 85 / expectedSize) + 5, 90)
                : (total > 0 ? qBound(5, static_cast<int>(finished * 85.0 / total) + 5, 90) : 5);
            publish(QJsonObject{
                {"active", true}, {"success", false}, {"cancelled", false},
                {"canCancel", true}, {"status", "downloading"},
                {"percent", percent},
                {"title", QString("正在下载 Java %1 %2").arg(major).arg(package.toUpper())},
                {"message", current.isEmpty() ? fileName : current},
                {"totalFiles", total}, {"finishedFiles", finished},
                {"totalBytes", static_cast<double>(expectedSize)},
                {"downloadedBytes", static_cast<double>(bytes)},
                {"currentFile", current}, {"speed", static_cast<double>(speed)},
                {"speedText", formatSpeed(speed)}, {"files", files},
                {"stages", QJsonArray{
                    QJsonObject{{"id", "hmcl.java.metadata"}, {"title", "获取 Java 下载信息"},
                                {"status", "success"}, {"count", 1}, {"total", 1}},
                    QJsonObject{{"id", "hmcl.java.download"}, {"title", fileName},
                                {"status", "running"}, {"count", finished}, {"total", total}},
                    QJsonObject{{"id", "hmcl.java.install"}, {"title", "安装 Java"},
                                {"status", "waiting"}, {"count", 0}, {"total", 1}}
                }}
            });
        }, Qt::DirectConnection);

    DownloadItem item;
    item.urls = {downloadUrl};
    item.destPath = archive;
    item.size = expectedSize;
    item.displayName = fileName;
    item.stageId = QStringLiteral("hmcl.java.download");
    if (!downloader.run({item})) {
        if (cancelled()) return cancelledResult();
        return errorResult("Java 文件下载失败。请检查网络和日志。");
    }
    if (cancelled()) return cancelledResult();

    publish(QJsonObject{
        {"active", true}, {"success", false}, {"cancelled", false},
        {"canCancel", false}, {"status", "installing"}, {"percent", 94},
        {"title", QString("正在安装 Java %1 %2").arg(major).arg(package.toUpper())},
        {"message", QStringLiteral("正在解压、验证并写入托管 Java 目录。")},
        {"speed", 0}, {"speedText", "0 B/s"}, {"files", QJsonArray{}},
        {"stages", QJsonArray{
            QJsonObject{{"id", "hmcl.java.metadata"}, {"title", "获取 Java 下载信息"},
                        {"status", "success"}, {"count", 1}, {"total", 1}},
            QJsonObject{{"id", "hmcl.java.download"}, {"title", fileName},
                        {"status", "success"}, {"count", 1}, {"total", 1}},
            QJsonObject{{"id", "hmcl.java.install"}, {"title", "安装 Java"},
                        {"status", "running"}, {"count", 0}, {"total", 1}}
        }}
    });

    QJsonObject result = installJavaArchive(archive);
    if (cancelled()) return cancelledResult();
    if (result.value("success").toBool()) {
        result.insert("download", QJsonObject{{"distribution", dist}, {"major", major},
                                               {"packageType", package}, {"fileName", fileName},
                                               {"archive", archive}});
        result.insert("message", QString("Java %1 %2 下载并安装完成。").arg(major).arg(package.toUpper()));
    }
    return result;
}

