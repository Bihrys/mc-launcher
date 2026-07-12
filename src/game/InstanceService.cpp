#include "game/InstanceService.h"

#include "core/JsonUtil.h"
#include "core/LauncherPaths.h"
#include "download/hmcl/DownloadProvider.h"
#include "game/VersionRules.h"
#include "java/JavaService.h"
#include "launch/LaunchEnvironment.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QVersionNumber>
#include <QRegularExpression>
#include <QProcessEnvironment>
#include <QJsonDocument>
#include <QHash>
#include <QJsonValue>
#include <QLocale>
#include <QProcess>
#include <QStandardPaths>
#include <QSysInfo>
#include <QSet>
#include <QDesktopServices>
#include <QUrl>

#include <utility>
#include <algorithm>
#include <climits>

namespace {

QString shellQuote(const QString &value) {
    QString out = value;
    out.replace("'", "'\\''");
    return QString("\'") + out + QString("\'");
}

QJsonObject readVersionObjectById(const QString &versionId) {
    const QString path = LauncherPaths::versionsDir() + "/" + versionId + "/" + versionId + ".json";
    return JsonUtil::readObjectFile(path, {});
}

QJsonObject mergeVersionJson(const QJsonObject &parent, const QJsonObject &child) {
    if (parent.isEmpty()) return child;
    QJsonObject out = parent;
    for (auto it = child.begin(); it != child.end(); ++it) {
        if (it.key() == "libraries") {
            QList<QJsonObject> merged;
            QHash<QString, int> indexByKey;
            auto appendOrReplace = [&](const QJsonArray &array) {
                for (const QJsonValue &value : array) {
                    if (!value.isObject()) continue;
                    const QJsonObject library = value.toObject();
                    const QString name = library.value("name").toString();
                    const QStringList parts = name.split(':');
                    const QString key = parts.size() >= 2
                        ? parts.at(0) + ":" + parts.at(1)
                        : name;
                    if (!key.isEmpty() && indexByKey.contains(key)) {
                        merged[indexByKey.value(key)] = library;
                    } else {
                        if (!key.isEmpty()) indexByKey.insert(key, merged.size());
                        merged.append(library);
                    }
                }
            };
            appendOrReplace(parent.value("libraries").toArray());
            appendOrReplace(child.value("libraries").toArray());
            QJsonArray libraries;
            for (const QJsonObject &library : std::as_const(merged)) libraries.append(library);
            out.insert("libraries", libraries);
        } else if (it.key() == "arguments") {
            QJsonObject args = parent.value("arguments").toObject();
            const QJsonObject childArgs = child.value("arguments").toObject();
            for (const QString &kind : {QStringLiteral("game"), QStringLiteral("jvm")}) {
                QJsonArray merged = args.value(kind).toArray();
                for (const QJsonValue &value : childArgs.value(kind).toArray()) merged.append(value);
                if (!merged.isEmpty()) args.insert(kind, merged);
            }
            out.insert("arguments", args);
        } else {
            out.insert(it.key(), it.value());
        }
    }
    return out;
}



bool fileMatchesSha1(const QString &path, const QString &sha1) {
    if (sha1.isEmpty()) return QFileInfo(path).isFile() && QFileInfo(path).size() > 0;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return false;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    if (!hash.addData(&file)) return false;
    return hash.result().toHex() == sha1.toLatin1().toLower();
}

QJsonObject repairDownload(const QList<QUrl> &urls,
                           const QString &destPath,
                           const QString &sha1,
                           qint64 size,
                           const QString &displayName,
                           const QString &stageId) {
    QJsonArray jsonUrls;
    for (const QUrl &url : urls) {
        if (url.isValid() && !url.isEmpty()) jsonUrls.append(url.toString());
    }
    return QJsonObject{
        {"urls", jsonUrls}, {"destPath", destPath}, {"sha1", sha1},
        {"size", static_cast<double>(size)}, {"displayName", displayName},
        {"stageId", stageId}
    };
}

QString libraryUrlFor(const QJsonObject &library, const QJsonObject &artifact,
                      const QString &relativePath) {
    QString url = artifact.value("url").toString();
    if (!url.isEmpty()) return url;
    QString base = library.value("url").toString();
    if (base.isEmpty()) base = QStringLiteral("https://libraries.minecraft.net/");
    if (!base.endsWith(u'/')) base.append(u'/');
    return base + relativePath;
}

QJsonObject applyHmclPatches(QJsonObject object, QString *gameVersion) {
    const QJsonArray patches = object.value("patches").toArray();
    if (patches.isEmpty()) return object;

    QList<QJsonObject> sorted;
    sorted.reserve(patches.size());
    for (const QJsonValue &value : patches) {
        if (value.isObject()) sorted.append(value.toObject());
    }
    std::sort(sorted.begin(), sorted.end(), [](const QJsonObject &a, const QJsonObject &b) {
        return a.value("priority").toInt(0) < b.value("priority").toInt(0);
    });

    object.remove("patches");
    QJsonObject resolved = object;
    for (QJsonObject patch : std::as_const(sorted)) {
        const QString patchId = patch.value("id").toString();
        if (patchId == QStringLiteral("game") && gameVersion) {
            const QString version = patch.value("version").toString();
            if (!version.isEmpty()) *gameVersion = version;
        }
        // HMCL clears the patch jar before merging so loader patches cannot
        // accidentally replace the primary Minecraft client jar.
        patch.remove("jar");
        patch.remove("patches");
        resolved = mergeVersionJson(resolved, patch);
    }
    return resolved;
}

QStringList stringOrArray(const QJsonValue &value) {
    QStringList out;
    if (value.isString()) {
        out << value.toString();
    } else if (value.isArray()) {
        for (const QJsonValue &v : value.toArray()) {
            if (v.isString()) out << v.toString();
        }
    }
    return out;
}

QString replaceLaunchPlaceholders(QString value, const QHash<QString, QString> &vars) {
    for (auto it = vars.begin(); it != vars.end(); ++it) {
        value.replace("${" + it.key() + "}", it.value());
    }
    return value;
}

QStringList parseArgumentList(const QJsonArray &array,
                              const QHash<QString, QString> &vars,
                              const QSet<QString> &enabledFeatures = {}) {
    QStringList out;
    for (const QJsonValue &v : array) {
        if (v.isString()) {
            out << replaceLaunchPlaceholders(v.toString(), vars);
        } else if (v.isObject()) {
            const QJsonObject obj = v.toObject();
            if (!VersionRules::allowedByRules(obj.value("rules").toArray(), enabledFeatures)) continue;
            for (const QString &item : stringOrArray(obj.value("value"))) {
                out << replaceLaunchPlaceholders(item, vars);
            }
        }
    }
    return out;
}

QString nativeClassifierForLibrary(const QJsonObject &library) {
#ifdef Q_OS_WIN
    const QString os = QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    const QString os = QStringLiteral("osx");
#else
    const QString os = QStringLiteral("linux");
#endif
    QString classifier = library.value("natives").toObject().value(os).toString();
    classifier.replace("${arch}", QSysInfo::WordSize >= 64 ? "64" : "32");
    return classifier;
}

bool extractArchive(const QString &archive, const QString &destination, QString *error) {
    QString program = QStandardPaths::findExecutable(QStringLiteral("bsdtar"));
    QStringList arguments;
    if (!program.isEmpty()) {
        arguments << "-xf" << archive << "-C" << destination;
    } else {
        program = QStandardPaths::findExecutable(QStringLiteral("unzip"));
        if (!program.isEmpty()) arguments << "-o" << "-q" << archive << "-d" << destination;
    }
    if (program.isEmpty()) {
        if (error) *error = QStringLiteral("缺少原生库解压工具：请安装 libarchive(bsdtar) 或 unzip。");
        return false;
    }

    QProcess process;
    process.start(program, arguments);
    if (!process.waitForStarted(5000) || !process.waitForFinished(60000)
            || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (error) {
            *error = QString("无法解压原生库 %1：%2")
                         .arg(QFileInfo(archive).fileName(),
                              QString::fromUtf8(process.readAllStandardError()).trimmed());
        }
        return false;
    }
    return true;
}

bool prepareNativeLibraries(const QJsonObject &versionJson, const QString &nativesDir,
                            QString *error) {
    QStringList archives;
    const QString librariesRoot = LauncherPaths::minecraftDir() + "/libraries";
    for (const QJsonValue &value : versionJson.value("libraries").toArray()) {
        const QJsonObject library = value.toObject();
        if (!VersionRules::allowedByRules(library.value("rules").toArray())) continue;
        const QString classifier = nativeClassifierForLibrary(library);
        if (classifier.isEmpty()) continue;
        const QJsonObject artifact = library.value("downloads").toObject()
                                         .value("classifiers").toObject()
                                         .value(classifier).toObject();
        const QString rel = artifact.value("path").toString();
        if (rel.isEmpty()) continue;
        const QString archive = librariesRoot + "/" + rel;
        if (!QFileInfo::exists(archive)) {
            if (error) *error = QString("缺少原生库：%1。请重新安装或修复该版本。").arg(rel);
            return false;
        }
        archives << archive;
    }

    if (archives.isEmpty()) return true;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    for (const QString &archive : std::as_const(archives)) {
        const QFileInfo info(archive);
        hash.addData(archive.toUtf8());
        hash.addData(QByteArray::number(info.size()));
        hash.addData(QByteArray::number(info.lastModified().toMSecsSinceEpoch()));
    }
    const QByteArray cacheKey = hash.result().toHex();
    QFile marker(nativesDir + "/.native-cache-key");
    if (marker.open(QIODevice::ReadOnly)) {
        const bool cacheValid = marker.readAll().trimmed() == cacheKey;
        marker.close();
        if (cacheValid) return true;
    }

    QDir(nativesDir).removeRecursively();
    if (!QDir().mkpath(nativesDir)) {
        if (error) *error = QString("无法创建原生库目录：%1").arg(nativesDir);
        return false;
    }
    for (const QString &archive : std::as_const(archives)) {
        if (!extractArchive(archive, nativesDir, error)) return false;
    }
    QDir(nativesDir + "/META-INF").removeRecursively();
    marker.setFileName(nativesDir + "/.native-cache-key");
    if (marker.open(QIODevice::WriteOnly | QIODevice::Truncate)) marker.write(cacheKey);
    return true;
}

QString buildClasspath(const QString &clientJarVersionId,
                       const QJsonObject &versionJson,
                       QStringList *missingLibraries = nullptr) {
    QStringList entries;
    QSet<QString> seen;
    const QString librariesRoot = LauncherPaths::minecraftDir() + "/libraries";
    for (const QJsonValue &v : versionJson.value("libraries").toArray()) {
        const QJsonObject lib = v.toObject();
        if (!VersionRules::allowedByRules(lib.value("rules").toArray())) continue;
        QString rel = lib.value("downloads").toObject()
                          .value("artifact").toObject()
                          .value("path").toString();
        if (rel.isEmpty())
            rel = VersionRules::libraryPathFromName(lib.value("name").toString());
        if (rel.isEmpty()) continue;
        const QString abs = librariesRoot + "/" + rel;
        const QFileInfo info(abs);
        if (!info.isFile() || info.size() <= 0) {
            if (missingLibraries) missingLibraries->append(rel);
        }
        if (!seen.contains(abs)) {
            entries << abs;
            seen.insert(abs);
        }
    }
    const QString clientJar = LauncherPaths::versionsDir() + "/" + clientJarVersionId
        + "/" + clientJarVersionId + ".jar";
    const QFileInfo clientInfo(clientJar);
    if ((!clientInfo.isFile() || clientInfo.size() <= 0) && missingLibraries)
        missingLibraries->append(clientJar);
    // The pre-launch repair stage may download the client jar after the launch
    // plan is built, so the expected path must already be present in classpath.
    if (!seen.contains(clientJar)) entries << clientJar;
    return entries.join(QDir::listSeparator());
}


QStringList detectLoaderKinds(const QJsonObject &versionJson,
                              const QString &versionId) {
    QSet<QString> loaders;
    QString corpus = versionId + u' ' + versionJson.value("mainClass").toString();
    for (const QJsonValue &value : versionJson.value("libraries").toArray())
        corpus += u' ' + value.toObject().value("name").toString();

    const QString lower = corpus.toLower();
    if (lower.contains("net.fabricmc:fabric-loader")
            || lower.contains("knotclient") || lower.contains("fabric"))
        loaders.insert(QStringLiteral("fabric"));
    if (lower.contains("org.quiltmc:quilt-loader") || lower.contains("quilt"))
        loaders.insert(QStringLiteral("quilt"));
    if (lower.contains("net.neoforged") || lower.contains("neoforge"))
        loaders.insert(QStringLiteral("neoforge"));
    else if (lower.contains("net.minecraftforge") || lower.contains("forge"))
        loaders.insert(QStringLiteral("forge"));
    if (lower.contains("liteloader")) loaders.insert(QStringLiteral("liteloader"));
    if (lower.contains("optifine")) loaders.insert(QStringLiteral("optifine"));
    if (lower.contains("legacyfabric")) loaders.insert(QStringLiteral("legacyfabric"));
    if (lower.contains("cleanroom")) loaders.insert(QStringLiteral("cleanroom"));
    return loaders.values();
}

QStringList splitCommandLine(const QString &text) {
    QStringList result;
    QString current;
    QChar quote;
    bool escaping = false;
    for (const QChar ch : text) {
        if (escaping) {
            current.append(ch);
            escaping = false;
            continue;
        }
        if (ch == u'\\' && quote != u'\'') {
            escaping = true;
            continue;
        }
        if (!quote.isNull()) {
            if (ch == quote) quote = QChar();
            else current.append(ch);
            continue;
        }
        if (ch == u'\'' || ch == u'"') {
            quote = ch;
        } else if (ch.isSpace()) {
            if (!current.isEmpty()) {
                result.append(current);
                current.clear();
            }
        } else {
            current.append(ch);
        }
    }
    if (escaping) current.append(u'\\');
    if (!current.isEmpty()) result.append(current);
    return result;
}

QString compactUuid(QString uuid) {
    uuid.remove(u'-');
    return uuid;
}

int compareGameVersion(const QString &left, const QString &right) {
    auto normalize = [](QString value) {
        value.remove(QRegularExpression(QStringLiteral("[^0-9.].*$")));
        return QVersionNumber::fromString(value);
    };
    return QVersionNumber::compare(normalize(left), normalize(right));
}

int requiredJavaMajorFor(const QJsonObject &versionJson, const QString &gameVersion) {
    const int declared = versionJson.value("javaVersion").toObject().value("majorVersion").toInt(0);
    if (declared > 0) return declared;
    if (compareGameVersion(gameVersion, QStringLiteral("1.20.5")) >= 0) return 21;
    if (compareGameVersion(gameVersion, QStringLiteral("1.18")) >= 0) return 17;
    if (compareGameVersion(gameVersion, QStringLiteral("1.17")) >= 0) return 16;
    return 8;
}

QString selectJavaExecutable(const QJsonObject &effectiveSettings, int requiredMajor,
                             QString *selectionError) {
    const QString configured = effectiveSettings.value("javaPath").toString().trimmed();
    auto resolveConfigured = [](const QString &path) {
        QFileInfo info(path);
        if (info.isFile() && info.isExecutable()) return info.absoluteFilePath();
        if (info.isDir()) {
#ifdef Q_OS_WIN
            const QString candidate = QDir(path).filePath(QStringLiteral("bin/java.exe"));
#else
            const QString candidate = QDir(path).filePath(QStringLiteral("bin/java"));
#endif
            if (QFileInfo(candidate).isFile() && QFileInfo(candidate).isExecutable()) return candidate;
        }
        return QString();
    };
    if (!configured.isEmpty()) {
        const QString resolved = resolveConfigured(configured);
        if (!resolved.isEmpty()) return resolved;
        if (selectionError) *selectionError = QStringLiteral("配置的 Java 路径无效：") + configured;
        return {};
    }

    const QJsonArray runtimes = JavaService().detect(true).value("runtimes").toArray();
    QJsonObject exact;
    QJsonObject compatibleNewer;
    for (const QJsonValue &value : runtimes) {
        const QJsonObject runtime = value.toObject();
        if (!runtime.value("compatible").toBool(true)) continue;
        const int major = runtime.value("major").toInt(0);
        if (major == requiredMajor) exact = runtime;
        else if (major > requiredMajor
                 && (compatibleNewer.isEmpty()
                     || major < compatibleNewer.value("major").toInt(INT_MAX))) {
            compatibleNewer = runtime;
        }
    }
    const QJsonObject selected = !exact.isEmpty() ? exact : compatibleNewer;
    if (!selected.isEmpty()) return selected.value("path").toString();

    const QString pathJava = QStandardPaths::findExecutable(QStringLiteral("java"));
    if (!pathJava.isEmpty()) return pathJava;
    if (selectionError) {
        *selectionError = QString("未找到可用的 Java %1。请在 Java 管理中安装或选择对应版本。")
                              .arg(requiredMajor);
    }
    return {};
}

QJsonObject resolveVersionJsonChain(const QString &versionId, QString *baseVersion,
                                    QString *error) {
    QString current = versionId;
    QList<QJsonObject> chain;
    QSet<QString> visited;
    for (int depth = 0; depth < 32 && !current.isEmpty(); ++depth) {
        if (visited.contains(current)) {
            if (error) *error = QStringLiteral("版本继承关系存在循环：") + current;
            return {};
        }
        visited.insert(current);
        const QJsonObject object = readVersionObjectById(current);
        if (object.isEmpty()) {
            if (error) *error = QStringLiteral("缺少版本 JSON：") + current;
            return {};
        }
        chain.prepend(object);
        const QString parent = object.value("inheritsFrom").toString();
        if (parent.isEmpty()) {
            if (baseVersion) *baseVersion = current;
            break;
        }
        current = parent;
    }
    if (chain.isEmpty()) return {};
    QJsonObject resolved;
    QString patchedGameVersion = baseVersion ? *baseVersion : QString();
    for (const QJsonObject &object : std::as_const(chain)) {
        resolved = mergeVersionJson(resolved, applyHmclPatches(object, &patchedGameVersion));
    }
    if (baseVersion && !patchedGameVersion.isEmpty()) *baseVersion = patchedGameVersion;
    return resolved;
}

QString redactedCommand(const QString &program, const QStringList &arguments) {
    QStringList parts{shellQuote(program)};
    bool redactNext = false;
    for (const QString &argument : arguments) {
        if (redactNext) {
            parts.append(QStringLiteral("'<redacted>'"));
            redactNext = false;
            continue;
        }
        const QString lower = argument.toLower();
        if (lower == QStringLiteral("--accesstoken")
            || lower == QStringLiteral("--clientid")
            || lower == QStringLiteral("--xuid")) {
            parts.append(shellQuote(argument));
            redactNext = true;
        } else if (argument.startsWith(QStringLiteral("-javaagent:"))
                   && argument.contains(u'=')) {
            parts.append(shellQuote(argument.left(argument.indexOf(u'=') + 1)
                                    + QStringLiteral("<server>")));
        } else {
            parts.append(shellQuote(argument));
        }
    }
    return parts.join(u' ');
}

} // namespace

QString InstanceService::versionDir(const QString &versionId) const {
    return LauncherPaths::versionsDir() + "/" + versionId;
}

QString InstanceService::iconForVersion(const QString &versionId, const QString &type) const {
    Q_UNUSED(type)
    if (versionId.contains("fabric", Qt::CaseInsensitive)) return "fabric";
    if (versionId.contains("quilt", Qt::CaseInsensitive)) return "quilt";
    if (versionId.contains("neoforge", Qt::CaseInsensitive)) return "neoforge";
    if (versionId.contains("forge", Qt::CaseInsensitive)) return "forge";
    if (versionId.contains("optifine", Qt::CaseInsensitive)) return "optifine";
    return "grass";
}

QJsonObject InstanceService::readVersionJson(const QString &versionId) const {
    const QString path = versionDir(versionId) + "/" + versionId + ".json";
    return JsonUtil::readObjectFile(path, {});
}

QJsonArray InstanceService::scanVersions() const {
    QJsonArray arr;
    QDir dir(LauncherPaths::versionsDir());
    if (!dir.exists()) return arr;
    const auto entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QFileInfo &info : entries) {
        const QString id = info.fileName();
        const QJsonObject raw = readVersionJson(id);
        if (raw.isEmpty()) continue;
        QString gameVersion;
        QString resolveError;
        const QJsonObject json = resolveVersionJsonChain(id, &gameVersion, &resolveError);
        if (json.isEmpty()) continue;
        const QString type = json.value("type").toString("release");
        const QStringList loaderKinds = detectLoaderKinds(json, id);
        QString loaderSummary = QStringLiteral("原版");
        QString iconName = iconForVersion(id, type);
        if (loaderKinds.contains(QStringLiteral("fabric"))) { loaderSummary = QStringLiteral("Fabric"); iconName = QStringLiteral("fabric"); }
        else if (loaderKinds.contains(QStringLiteral("quilt"))) { loaderSummary = QStringLiteral("Quilt"); iconName = QStringLiteral("quilt"); }
        else if (loaderKinds.contains(QStringLiteral("neoforge"))) { loaderSummary = QStringLiteral("NeoForge"); iconName = QStringLiteral("neoforge"); }
        else if (loaderKinds.contains(QStringLiteral("forge"))) { loaderSummary = QStringLiteral("Forge"); iconName = QStringLiteral("forge"); }
        arr.append(QJsonObject{
            {"id", id}, {"title", id}, {"name", id}, {"subtitle", gameVersion}, {"tag", type},
            {"versionType", type}, {"gameVersion", gameVersion}, {"loaderSummary", loaderSummary},
            {"iconName", iconName}, {"selected", false}, {"canUpdate", false},
            {"path", info.absoluteFilePath()}
        });
    }
    return arr;
}

QJsonObject InstanceService::list() {
    const QJsonArray instances = scanVersions();
    QString selected;
    if (!instances.isEmpty()) selected = instances.first().toObject().value("id").toString();
    QJsonArray marked;
    for (int i = 0; i < instances.size(); ++i) {
        QJsonObject item = instances.at(i).toObject();
        item["selected"] = item.value("id").toString() == selected;
        marked.append(item);
    }
    QJsonArray profiles;
    profiles.append(QJsonObject{{"id", "default"}, {"name", "默认游戏目录"}, {"path", LauncherPaths::minecraftDir()}, {"selected", true}});
    return QJsonObject{{"instances", marked}, {"profiles", profiles}, {"selectedInstance", selected}};
}

QJsonObject InstanceService::installedVersions() {
    QJsonArray versions = scanVersions();
    for (int i = 0; i < versions.size(); ++i) {
        QJsonObject v = versions.at(i).toObject();
        v.insert("installed", true);
        versions[i] = v;
    }
    return QJsonObject{{"versions", versions}};
}

QJsonObject InstanceService::detail(const QString &versionId) {
    const QString id = versionId.trimmed();
    const QString dir = versionDir(id);
    const QJsonObject raw = readVersionJson(id);
    QString gameVersion;
    QString resolveError;
    QJsonObject json = resolveVersionJsonChain(id, &gameVersion, &resolveError);
    if (json.isEmpty()) json = raw;
    const QString inherits = raw.value("inheritsFrom").toString();
    if (gameVersion.isEmpty()) gameVersion = inherits.isEmpty() ? id : inherits;
    const QString mainClass = json.value("mainClass").toString();
    QJsonArray folders;
    const QList<QPair<QString, QString>> map = {
        {"root", "版本目录"}, {"mods", "mods"}, {"resourcepacks", "resourcepacks"}, {"shaderpacks", "shaderpacks"}, {"saves", "saves"}, {"logs", "logs"}
    };
    for (auto pair : map) {
        QString sub = pair.first == "root" ? dir : LauncherPaths::minecraftDir() + "/" + pair.first;
        QDir d(sub);
        folders.append(QJsonObject{{"key", pair.first}, {"title", pair.second}, {"path", sub}, {"exists", d.exists()}, {"itemCount", d.exists() ? d.entryList(QDir::NoDotAndDotDot | QDir::AllEntries).size() : 0}});
    }
    QJsonArray loaders;
    const QStringList detectedLoaders = detectLoaderKinds(json, id);
    for (const QString &loader : detectedLoaders) {
        QString title = loader;
        if (loader == QStringLiteral("fabric")) title = QStringLiteral("Fabric");
        else if (loader == QStringLiteral("quilt")) title = QStringLiteral("Quilt");
        else if (loader == QStringLiteral("forge")) title = QStringLiteral("Forge");
        else if (loader == QStringLiteral("neoforge")) title = QStringLiteral("NeoForge");
        else if (loader == QStringLiteral("optifine")) title = QStringLiteral("OptiFine");
        loaders.append(QJsonObject{{"kind", title}, {"version", id}});
    }

    QJsonObject settings{{"javaPath", ""}, {"minMemoryMb", 256}, {"maxMemoryMb", 4096}, {"jvmArgs", ""}, {"gameArgs", ""}, {"width", 854}, {"height", 480}, {"fullscreen", false}, {"isolated", false}, {"runDirectory", LauncherPaths::minecraftDir()}, {"server", ""}};
    const QString settingsPath = dir + "/hmcl-qt-settings.json";
    QJsonObject saved = JsonUtil::readObjectFile(settingsPath, {});
    for (auto it = saved.begin(); it != saved.end(); ++it) settings.insert(it.key(), it.value());

    return QJsonObject{
        {"versionId", id}, {"versionJson", dir + "/" + id + ".json"}, {"clientJar", dir + "/" + id + ".jar"},
        {"mainClass", mainClass}, {"inheritsFrom", inherits}, {"folders", folders}, {"loaders", loaders},
        {"settings", settings},
        {"summary", QJsonObject{{"title", id}, {"subtitle", gameVersion}, {"gameVersion", gameVersion}, {"versionType", json.value("type").toString("release")}, {"loaderSummary", loaders.isEmpty() ? "原版" : loaders.first().toObject().value("kind").toString()}, {"javaMajor", 17}, {"path", dir}, {"runDirectory", LauncherPaths::minecraftDir()}, {"iconName", iconForVersion(id)}, {"isIsolated", false}, {"isModpack", false}}}
    };
}

QJsonObject InstanceService::files(const QString &versionId, const QString &kind) {
    QString folder;
    QString key;
    if (kind == "mods") { folder = LauncherPaths::minecraftDir() + "/mods"; key = "mods"; }
    else if (kind == "resourcepacks") { folder = LauncherPaths::minecraftDir() + "/resourcepacks"; key = "resourcepacks"; }
    else { folder = LauncherPaths::minecraftDir() + "/saves"; key = "worlds"; }
    Q_UNUSED(versionId)
    QJsonArray rows;
    QDir dir(folder);
    if (dir.exists()) {
        const auto entries = dir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
        for (const auto &e : entries) {
            rows.append(QJsonObject{{"name", e.fileName()}, {"fileName", e.fileName()}, {"path", e.absoluteFilePath()}, {"enabled", !e.fileName().endsWith(".disabled")}, {"size", static_cast<qint64>(e.size())}, {"modified", e.lastModified().toString(Qt::ISODate)}});
        }
    }
    return QJsonObject{{key, rows}};
}

QJsonObject InstanceService::select(const QString &versionId) {
    Q_UNUSED(versionId)
    return list();
}

QJsonObject InstanceService::rename(const QString &versionId, const QString &newName) {
    QString oldDir = versionDir(versionId);
    QString newDir = LauncherPaths::versionsDir() + "/" + newName.trimmed();
    bool ok = !newName.trimmed().isEmpty() && QDir().rename(oldDir, newDir);
    return QJsonObject{{"success", ok}, {"message", ok ? "已重命名实例" : "重命名失败"}};
}

QJsonObject InstanceService::duplicate(const QString &versionId, const QString &newName, bool copySaves) {
    Q_UNUSED(copySaves)
    QString src = versionDir(versionId);
    QString dst = LauncherPaths::versionsDir() + "/" + newName.trimmed();
    QDir().mkpath(dst);
    QFile::copy(src + "/" + versionId + ".json", dst + "/" + newName.trimmed() + ".json");
    QFile::copy(src + "/" + versionId + ".jar", dst + "/" + newName.trimmed() + ".jar");
    return QJsonObject{{"success", true}, {"message", "已复制实例骨架"}};
}

QJsonObject InstanceService::remove(const QString &versionId) {
    bool ok = QDir(versionDir(versionId)).removeRecursively();
    return QJsonObject{{"success", ok}, {"message", ok ? "已删除实例" : "删除失败"}};
}

QString InstanceService::openFolder(const QString &versionId, const QString &subFolder) {
    QString path = versionDir(versionId);
    if (!subFolder.isEmpty() && subFolder != "root") path = LauncherPaths::minecraftDir() + "/" + subFolder;
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    return path;
}

LaunchOptions InstanceService::createLaunchOptions(const QString &versionId,
                                                   const QJsonObject &account,
                                                   const QJsonObject &launcherSettings) {
    LaunchOptions options;
    options.versionId = versionId.trimmed();
    if (options.versionId.isEmpty()) {
        options.error = QStringLiteral("当前没有选中的游戏版本。");
        return options;
    }

    QString baseVersion;
    QString resolveError;
    const QJsonObject versionJson = resolveVersionJsonChain(options.versionId, &baseVersion, &resolveError);
    if (versionJson.isEmpty()) {
        options.error = resolveError.isEmpty() ? QStringLiteral("无法解析版本 JSON。") : resolveError;
        return options;
    }
    options.gameVersion = baseVersion;

    const QString mainClass = versionJson.value("mainClass").toString();
    if (mainClass.isEmpty()) {
        options.error = QStringLiteral("版本 JSON 缺少 mainClass。");
        return options;
    }

    QJsonObject effectiveSettings = launcherSettings;
    const QJsonObject instanceSettings = JsonUtil::readObjectFile(
        versionDir(options.versionId) + "/hmcl-qt-settings.json", {});
    for (auto it = instanceSettings.begin(); it != instanceSettings.end(); ++it)
        effectiveSettings.insert(it.key(), it.value());

    const QString fileSource = effectiveSettings.value("fileDownloadSource")
                                   .toString(effectiveSettings.value("downloadSource")
                                                 .toString(QStringLiteral("balanced")));
    const HmclDownloadProvider provider = HmclDownloadProvider::fromSource(fileSource);
    options.downloadSource = provider.id();

    QJsonArray dependencyDownloads;
    QStringList missingWithoutUrl;

    const QString clientJarVersionId = versionJson.value("jar").toString(baseVersion);
    const QString clientJar = versionDir(clientJarVersionId) + "/" + clientJarVersionId + ".jar";
    const QJsonObject clientInfo = versionJson.value("downloads").toObject()
                                      .value("client").toObject();
    const QString clientSha1 = clientInfo.value("sha1").toString();
    if (!fileMatchesSha1(clientJar, clientSha1)) {
        const QString url = clientInfo.value("url").toString();
        if (url.isEmpty()) {
            missingWithoutUrl.append(clientJar);
        } else {
            dependencyDownloads.append(repairDownload(
                provider.candidatesFor(url), clientJar, clientSha1,
                static_cast<qint64>(clientInfo.value("size").toDouble()),
                QFileInfo(clientJar).fileName(), QStringLiteral("hmcl.install.game")));
        }
    }

    QStringList missingLibraries;
    const QString classpath = buildClasspath(clientJarVersionId, versionJson,
                                             &missingLibraries);
    if (classpath.isEmpty()) {
        options.error = QStringLiteral("无法生成 classpath，请重新安装或修复该版本。");
        return options;
    }

    const QString librariesRoot = LauncherPaths::minecraftDir() + "/libraries";
    QSet<QString> scheduledPaths;
    for (const QJsonValue &value : versionJson.value("libraries").toArray()) {
        const QJsonObject library = value.toObject();
        if (!VersionRules::allowedByRules(library.value("rules").toArray())) continue;

        const QJsonObject downloads = library.value("downloads").toObject();
        const QJsonObject artifact = downloads.value("artifact").toObject();
        QString relative = artifact.value("path").toString();
        if (relative.isEmpty()) relative = VersionRules::libraryPathFromName(library.value("name").toString());
        if (!relative.isEmpty()) {
            const QString path = librariesRoot + "/" + relative;
            const QString sha1 = artifact.value("sha1").toString();
            if (!fileMatchesSha1(path, sha1) && !scheduledPaths.contains(path)) {
                const QString url = libraryUrlFor(library, artifact, relative);
                if (url.isEmpty()) missingWithoutUrl.append(path);
                else dependencyDownloads.append(repairDownload(
                    provider.candidatesFor(url), path, sha1,
                    static_cast<qint64>(artifact.value("size").toDouble()),
                    QFileInfo(path).fileName(), QStringLiteral("hmcl.install.libraries")));
                scheduledPaths.insert(path);
            }
        }

        const QString classifier = nativeClassifierForLibrary(library);
        if (classifier.isEmpty()) continue;
        const QJsonObject nativeArtifact = downloads.value("classifiers").toObject()
                                               .value(classifier).toObject();
        QString nativeRelative = nativeArtifact.value("path").toString();
        if (nativeRelative.isEmpty()) continue;
        const QString nativePath = librariesRoot + "/" + nativeRelative;
        if (!options.nativeArchives.contains(nativePath)) options.nativeArchives.append(nativePath);
        const QString nativeSha1 = nativeArtifact.value("sha1").toString();
        if (!fileMatchesSha1(nativePath, nativeSha1) && !scheduledPaths.contains(nativePath)) {
            const QString nativeUrl = libraryUrlFor(library, nativeArtifact, nativeRelative);
            if (nativeUrl.isEmpty()) missingWithoutUrl.append(nativePath);
            else dependencyDownloads.append(repairDownload(
                provider.candidatesFor(nativeUrl), nativePath, nativeSha1,
                static_cast<qint64>(nativeArtifact.value("size").toDouble()),
                QFileInfo(nativePath).fileName(), QStringLiteral("hmcl.install.libraries")));
            scheduledPaths.insert(nativePath);
        }
    }

    if (!missingWithoutUrl.isEmpty()) {
        options.error = QStringLiteral("以下游戏文件缺失且版本元数据没有下载地址：\n")
            + missingWithoutUrl.mid(0, 8).join(QStringLiteral("\n"));
        return options;
    }

    QString gameDirectory = effectiveSettings.value("runDirectory").toString().trimmed();
    if (gameDirectory.isEmpty()) gameDirectory = effectiveSettings.value("runningDir").toString().trimmed();
    if (gameDirectory.isEmpty()) gameDirectory = effectiveSettings.value("gameDir").toString().trimmed();
    if (gameDirectory.isEmpty()) gameDirectory = LauncherPaths::minecraftDir();
    if (effectiveSettings.value("isolated").toBool(false))
        gameDirectory = versionDir(options.versionId) + "/.minecraft";
    gameDirectory = QDir(gameDirectory).absolutePath();
    if (!QDir().mkpath(gameDirectory)) {
        options.error = QStringLiteral("无法创建游戏运行目录：") + gameDirectory;
        return options;
    }
    options.workingDirectory = gameDirectory;
    options.instanceDirectory = versionDir(options.versionId);
    options.minecraftDirectory = LauncherPaths::minecraftDir();

    const QString nativesDir = versionDir(options.versionId) + "/natives";
    options.nativeDirectory = nativesDir;

    options.requiredJavaMajor = requiredJavaMajorFor(versionJson, baseVersion);
    QString javaError;
    options.javaExecutable = selectJavaExecutable(effectiveSettings,
                                                  options.requiredJavaMajor,
                                                  &javaError);
    if (options.javaExecutable.isEmpty()) {
        options.error = javaError;
        return options;
    }

    options.graphicsBackend = effectiveSettings.value("graphicsBackend")
                                  .toString(QStringLiteral("default"))
                                  .trimmed().toLower();
    options.renderer = effectiveSettings.value("openGLRenderer")
                           .toString(QStringLiteral("default"))
                           .trimmed().toLower();
    if (options.renderer == QStringLiteral("system"))
        options.renderer = QStringLiteral("default");
    else if (options.renderer == QStringLiteral("software"))
        options.renderer = QStringLiteral("llvmpipe");
    options.loaderKinds = detectLoaderKinds(versionJson, options.versionId);

    options.accountKind = account.value("kind").toString(QStringLiteral("offline"));
    options.accountName = account.value("username").toString(QStringLiteral("Steve"));
    options.accountUuid = compactUuid(account.value("uuid").toString());
    if (options.accountUuid.isEmpty())
        options.accountUuid = QStringLiteral("00000000000000000000000000000000");

    const QString accessToken = account.value("accessToken").toString(
        options.accountKind == QStringLiteral("offline") ? QStringLiteral("0") : QString());
    const QString userType = account.value("userType").toString(
        options.accountKind == QStringLiteral("microsoft")
            ? QStringLiteral("msa")
            : options.accountKind == QStringLiteral("offline")
                ? QStringLiteral("legacy") : QStringLiteral("mojang"));

    options.authServerUrl = account.value("serverUrl").toString();
    if (options.accountKind == QStringLiteral("yggdrasil")) {
        options.authlibInjectorPath = LauncherPaths::cacheDir()
            + QStringLiteral("/authlib-injector/authlib-injector-1.2.7.jar");
    }

    const QJsonObject assetIndexInfo = versionJson.value("assetIndex").toObject();
    const QString assetIndex = assetIndexInfo.value("id").toString(
                                   versionJson.value("assets").toString(QStringLiteral("legacy")));
    options.assetsDirectory = LauncherPaths::minecraftDir() + QStringLiteral("/assets");
    options.assetIndexId = assetIndex;
    options.assetIndexFile = options.assetsDirectory + QStringLiteral("/indexes/")
        + assetIndex + QStringLiteral(".json");
    if (!assetIndex.isEmpty()) {
        const QString indexSha1 = assetIndexInfo.value("sha1").toString();
        if (!fileMatchesSha1(options.assetIndexFile, indexSha1)) {
            const QString indexUrl = assetIndexInfo.value("url").toString();
            if (indexUrl.isEmpty()) {
                options.error = QStringLiteral("缺少资源索引且版本元数据没有下载地址：")
                    + options.assetIndexFile;
                return options;
            }
            dependencyDownloads.append(repairDownload(
                provider.candidatesFor(indexUrl), options.assetIndexFile, indexSha1,
                static_cast<qint64>(assetIndexInfo.value("size").toDouble()),
                QFileInfo(options.assetIndexFile).fileName(), QStringLiteral("hmcl.install.assets")));
        }
    }

    const QJsonObject loggingClient = versionJson.value("logging").toObject()
                                          .value("client").toObject();
    const QJsonObject loggingFile = loggingClient.value("file").toObject();
    const QString loggingFileId = loggingFile.value("id").toString();
    if (!loggingFileId.isEmpty()) {
        const QString loggingPath = options.assetsDirectory
            + QStringLiteral("/log_configs/") + loggingFileId;
        const QString loggingSha1 = loggingFile.value("sha1").toString();
        if (!fileMatchesSha1(loggingPath, loggingSha1)) {
            const QString loggingUrl = loggingFile.value("url").toString();
            if (!loggingUrl.isEmpty()) {
                dependencyDownloads.append(repairDownload(
                    provider.candidatesFor(loggingUrl), loggingPath, loggingSha1,
                    static_cast<qint64>(loggingFile.value("size").toDouble()),
                    loggingFileId, QStringLiteral("hmcl.install.assets")));
            }
        }
    }
    options.dependencyDownloads = dependencyDownloads;

    QHash<QString, QString> vars;
    vars.insert(QStringLiteral("auth_player_name"), options.accountName);
    vars.insert(QStringLiteral("version_name"), options.versionId);
    vars.insert(QStringLiteral("game_directory"), gameDirectory);
    vars.insert(QStringLiteral("assets_root"), LauncherPaths::minecraftDir() + "/assets");
    vars.insert(QStringLiteral("game_assets"), LauncherPaths::minecraftDir() + "/assets/virtual/legacy");
    vars.insert(QStringLiteral("assets_index_name"), assetIndex);
    vars.insert(QStringLiteral("auth_uuid"), options.accountUuid);
    vars.insert(QStringLiteral("auth_access_token"), accessToken);
    vars.insert(QStringLiteral("auth_session"), accessToken);
    vars.insert(QStringLiteral("user_properties"), QStringLiteral("{}"));
    vars.insert(QStringLiteral("clientid"), account.value("clientId").toString(QStringLiteral("0")));
    vars.insert(QStringLiteral("auth_xuid"), account.value("xuid").toString(QStringLiteral("0")));
    vars.insert(QStringLiteral("user_type"), userType);
    vars.insert(QStringLiteral("version_type"), versionJson.value("type").toString(QStringLiteral("release")));
    vars.insert(QStringLiteral("natives_directory"), nativesDir);
    vars.insert(QStringLiteral("launcher_name"), QStringLiteral("HMCL-Qt"));
    vars.insert(QStringLiteral("launcher_version"), QStringLiteral("0.1.0"));
    vars.insert(QStringLiteral("classpath"), classpath);
    vars.insert(QStringLiteral("classpath_separator"), QString(QDir::listSeparator()));
    vars.insert(QStringLiteral("library_directory"), LauncherPaths::minecraftDir() + "/libraries");
    vars.insert(QStringLiteral("libraries_directory"), LauncherPaths::minecraftDir() + "/libraries");
    vars.insert(QStringLiteral("primary_jar"), clientJar);
    vars.insert(QStringLiteral("primary_jar_name"), QFileInfo(clientJar).fileName());
    vars.insert(QStringLiteral("file_separator"), QString(QDir::separator()));
    vars.insert(QStringLiteral("language"), QLocale::system().bcp47Name());

    QSet<QString> enabledFeatures;
    const int width = effectiveSettings.value("width").toInt(
        effectiveSettings.value("gameWidth").toInt(854));
    const int height = effectiveSettings.value("height").toInt(
        effectiveSettings.value("gameHeight").toInt(480));
    const bool fullscreen = effectiveSettings.value("fullscreen").toBool(false);
    vars.insert(QStringLiteral("resolution_width"), QString::number(width));
    vars.insert(QStringLiteral("resolution_height"), QString::number(height));
    vars.insert(QStringLiteral("quickPlayPath"), effectiveSettings.value("quickPlayPath").toString());
    vars.insert(QStringLiteral("quickPlaySingleplayer"), effectiveSettings.value("quickPlaySingleplayer").toString());
    vars.insert(QStringLiteral("quickPlayMultiplayer"), effectiveSettings.value("quickPlayServer").toString());
    vars.insert(QStringLiteral("quickPlayRealms"), effectiveSettings.value("quickPlayRealms").toString());
    if (width > 0 && height > 0) enabledFeatures.insert(QStringLiteral("has_custom_resolution"));
    if (effectiveSettings.value("quickPlayType").toString() == QStringLiteral("multiplayer"))
        enabledFeatures.insert(QStringLiteral("is_quick_play_multiplayer"));
    if (effectiveSettings.value("quickPlayType").toString() == QStringLiteral("singleplayer"))
        enabledFeatures.insert(QStringLiteral("is_quick_play_singleplayer"));

    QStringList javaArguments;
    const int maxMemory = qMax(256, effectiveSettings.value("maxMemoryMb").toInt(4096));
    const int minMemory = qMax(0, effectiveSettings.value("minMemoryMb").toInt(256));
    options.maxMemoryMiB = maxMemory;
    javaArguments << QString("-Xmx%1m").arg(maxMemory);
    if (minMemory > 0 && minMemory <= maxMemory)
        javaArguments << QString("-Xms%1m").arg(minMemory);

    if (!effectiveSettings.value("noJVMOptions").toBool(false)) {
        const QString launcherHome = QFileInfo(LauncherPaths::minecraftDir()).absolutePath();
        javaArguments << QStringLiteral("-Dfile.encoding=UTF-8")
                      << QStringLiteral("-Dstdout.encoding=UTF-8")
                      << QStringLiteral("-Dstderr.encoding=UTF-8")
                      << QStringLiteral("-Djava.rmi.server.useCodebaseOnly=true")
                      << QStringLiteral("-Dcom.sun.jndi.rmi.object.trustURLCodebase=false")
                      << QStringLiteral("-Dcom.sun.jndi.cosnaming.object.trustURLCodebase=false")
                      << QStringLiteral("-Dlog4j2.formatMsgNoLookups=true")
                      << QStringLiteral("-Dminecraft.client.jar=") + clientJar
                      << QStringLiteral("-Duser.home=") + launcherHome
                      << QStringLiteral("-Djava.net.useSystemProxies=true")
                      << QStringLiteral("-Dfml.ignoreInvalidMinecraftCertificates=true")
                      << QStringLiteral("-Dfml.ignorePatchDiscrepancies=true")
                      << QStringLiteral("-Djna.tmpdir=") + nativesDir
                      << QStringLiteral("-Dorg.lwjgl.system.SharedLibraryExtractPath=") + nativesDir
                      << QStringLiteral("-Dio.netty.native.workdir=") + nativesDir
                      << QStringLiteral("-Dminecraft.launcher.brand=HMCL")
                      << QStringLiteral("-Dminecraft.launcher.version=3.15.2");
    }

    if (options.accountKind == QStringLiteral("yggdrasil")) {
        if (options.authServerUrl.isEmpty()) {
            options.error = QStringLiteral("第三方账户缺少认证服务器地址，请重新登录该账户。");
            return options;
        }
        javaArguments << QStringLiteral("-javaagent:") + options.authlibInjectorPath
                         + QStringLiteral("=") + options.authServerUrl;
        javaArguments << QStringLiteral("-Dauthlibinjector.side=client");
    }

    // Mojang's legacy logging configuration is generated by the same
    // version metadata path used by HMCL. It is optional for versions that do
    // not declare it, but must be passed when the downloaded file exists.
    const QJsonObject loggingClientArgs = versionJson.value("logging").toObject()
                                          .value("client").toObject();
    const QString loggingArgument = loggingClientArgs.value("argument").toString();
    const QString loggingFileIdForArgs = loggingClientArgs.value("file").toObject()
                                      .value("id").toString();
    if (!loggingArgument.isEmpty() && !loggingFileIdForArgs.isEmpty()) {
        const QString loggingPath = LauncherPaths::minecraftDir()
            + QStringLiteral("/assets/log_configs/") + loggingFileIdForArgs;
        if (QFileInfo(loggingPath).isFile()) {
            QString argument = loggingArgument;
            argument.replace(QStringLiteral("${path}"), loggingPath);
            javaArguments << argument;
        }
    }

    const QString customJvm = effectiveSettings.value("jvmArgs").toString();
    if (!customJvm.trimmed().isEmpty()) javaArguments << splitCommandLine(customJvm);

    const QJsonObject arguments = versionJson.value("arguments").toObject();
    QStringList versionJvmArguments = parseArgumentList(arguments.value("jvm").toArray(),
                                                        vars, enabledFeatures);
    bool hasClasspath = false;
    bool hasNativePath = false;
    for (const QString &argument : std::as_const(versionJvmArguments)) {
        if (argument == QStringLiteral("-cp") || argument == QStringLiteral("-classpath"))
            hasClasspath = true;
        if (argument.startsWith(QStringLiteral("-Djava.library.path=")))
            hasNativePath = true;
    }
    if (!hasNativePath) javaArguments << QStringLiteral("-Djava.library.path=") + nativesDir;
    if (!hasClasspath) javaArguments << QStringLiteral("-cp") << classpath;
    javaArguments << versionJvmArguments;

    QStringList gameArguments = parseArgumentList(arguments.value("game").toArray(),
                                                  vars, enabledFeatures);
    if (gameArguments.isEmpty()) {
        const QString legacy = versionJson.value("minecraftArguments").toString();
        if (!legacy.isEmpty()) {
            for (const QString &argument : splitCommandLine(legacy))
                gameArguments << replaceLaunchPlaceholders(argument, vars);
        } else {
            gameArguments << QStringLiteral("--username") << options.accountName
                          << QStringLiteral("--version") << options.versionId
                          << QStringLiteral("--gameDir") << gameDirectory
                          << QStringLiteral("--assetsDir") << LauncherPaths::minecraftDir() + "/assets"
                          << QStringLiteral("--assetIndex") << assetIndex
                          << QStringLiteral("--uuid") << options.accountUuid
                          << QStringLiteral("--accessToken") << accessToken
                          << QStringLiteral("--userType") << userType
                          << QStringLiteral("--versionType")
                          << versionJson.value("type").toString(QStringLiteral("release"));
        }
    }

    if (width > 0 && height > 0) {
        if (!gameArguments.contains(QStringLiteral("--width")))
            gameArguments << QStringLiteral("--width") << QString::number(width);
        if (!gameArguments.contains(QStringLiteral("--height")))
            gameArguments << QStringLiteral("--height") << QString::number(height);
    }
    if (fullscreen && !gameArguments.contains(QStringLiteral("--fullscreen")))
        gameArguments << QStringLiteral("--fullscreen");

    const QString quickPlayType = effectiveSettings.value("quickPlayType").toString();
    if (quickPlayType == QStringLiteral("multiplayer")) {
        const QString server = effectiveSettings.value("quickPlayServer").toString().trimmed();
        if (!server.isEmpty()) gameArguments << QStringLiteral("--quickPlayMultiplayer") << server;
    } else if (quickPlayType == QStringLiteral("singleplayer")) {
        const QString world = effectiveSettings.value("quickPlaySingleplayer").toString().trimmed();
        if (!world.isEmpty()) gameArguments << QStringLiteral("--quickPlaySingleplayer") << world;
    }

    const QString customGameArguments = effectiveSettings.value("gameArguments").toString();
    if (!customGameArguments.trimmed().isEmpty())
        gameArguments << splitCommandLine(customGameArguments);

    options.arguments = javaArguments;
    options.arguments << mainClass;
    options.arguments << gameArguments;

    QRegularExpression unresolvedPattern(QStringLiteral("\\$\\{[^}]+\\}"));
    QStringList unresolved;
    for (const QString &argument : std::as_const(options.arguments)) {
        const QRegularExpressionMatch match = unresolvedPattern.match(argument);
        if (match.hasMatch() && !unresolved.contains(match.captured(0)))
            unresolved.append(match.captured(0));
    }
    if (!unresolved.isEmpty()) {
        options.error = QStringLiteral("版本启动参数包含无法解析的变量：")
            + unresolved.join(QStringLiteral("、"));
        return options;
    }

    QProcessEnvironment userEnvironment;
    const QString environmentText = effectiveSettings.value("environmentVariables").toString();
    for (const QString &line : environmentText.split(QRegularExpression(QStringLiteral("[\r\n]+")),
                                                      Qt::SkipEmptyParts)) {
        const int equals = line.indexOf(u'=');
        if (equals > 0)
            userEnvironment.insert(line.left(equals).trimmed(), line.mid(equals + 1));
    }
    options.environment = LaunchEnvironment::build(options, userEnvironment);

    const QString gameLogDir = LauncherPaths::logsDir() + QStringLiteral("/game");
    QDir().mkpath(gameLogDir);
    QString safeVersion = options.versionId;
    safeVersion.replace(u'/', u'_');
    safeVersion.replace(u'\\', u'_');
    options.logFile = gameLogDir + QStringLiteral("/game-") + safeVersion + u'-'
        + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"))
        + QStringLiteral(".log");

    options.displayCommand = redactedCommand(options.javaExecutable, options.arguments);
    options.valid = true;
    return options;
}

QString InstanceService::generateLaunchCommand(const QString &versionId) {
    QJsonObject offlineAccount{
        {"kind", QStringLiteral("offline")},
        {"username", QStringLiteral("Steve")},
        {"uuid", QStringLiteral("00000000000000000000000000000000")},
        {"accessToken", QStringLiteral("0")},
        {"userType", QStringLiteral("legacy")}
    };
    const LaunchOptions options = createLaunchOptions(versionId, offlineAccount, QJsonObject{});
    return options.valid ? options.displayCommand
                         : QStringLiteral("echo ") + shellQuote(options.error);
}

QString InstanceService::clean(const QString &versionId, const QString &what) {
    Q_UNUSED(versionId)
    return QString("已执行清理动作: ") + what;
}

QJsonObject InstanceService::saveSettings(const QString &versionId, const QString &settingsJson) {
    QJsonObject settings = JsonUtil::objectFromString(settingsJson, {});
    bool ok = JsonUtil::writeObjectFile(versionDir(versionId) + "/hmcl-qt-settings.json", settings);
    return QJsonObject{{"success", ok}, {"message", ok ? "实例设置已保存" : "实例设置保存失败"}};
}
