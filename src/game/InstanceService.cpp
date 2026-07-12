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
#include <QDirIterator>
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


QString selectedInstanceStatePath() {
    return LauncherPaths::configDir() + QStringLiteral("/selected_instance.txt");
}

QString readSelectedInstanceId() {
    QFile file(selectedInstanceStatePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

void writeSelectedInstanceId(const QString &versionId) {
    QDir().mkpath(LauncherPaths::configDir());
    QFile file(selectedInstanceStatePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) return;
    file.write(versionId.trimmed().toUtf8());
}

QString loaderSignature(const QJsonObject &raw, const QString &gameVersion,
                        const QStringList &loaderKinds) {
    const QJsonObject meta = raw.value(QStringLiteral("hmclQt")).toObject();
    QString kind = meta.value(QStringLiteral("libraryId")).toString();
    if (kind.isEmpty() && !loaderKinds.isEmpty()) kind = loaderKinds.first();
    const QString loaderVersion = meta.value(QStringLiteral("loaderVersion")).toString();
    const QString base = meta.value(QStringLiteral("gameVersion")).toString(gameVersion);
    if (kind.isEmpty()) return {};
    return base.toLower() + u'|' + kind.toLower() + u'|' + loaderVersion.toLower();
}

QString canonicalLoaderHelperId(const QJsonObject &raw, const QString &gameVersion,
                                const QStringList &loaderKinds) {
    const QJsonObject meta = raw.value(QStringLiteral("hmclQt")).toObject();
    QString kind = meta.value(QStringLiteral("libraryId")).toString();
    if (kind.isEmpty() && !loaderKinds.isEmpty()) kind = loaderKinds.first();
    const QString loaderVersion = meta.value(QStringLiteral("loaderVersion")).toString();
    const QString base = meta.value(QStringLiteral("gameVersion")).toString(gameVersion);
    if (base.isEmpty() || kind.isEmpty() || loaderVersion.isEmpty()) return {};
    QString id = base + u'-' + kind + u'-' + loaderVersion;
    id.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_.+-]")), QStringLiteral("_"));
    return id;
}

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
            // HMCL Version.merge() uses Lang.merge(this.libraries, parent.libraries):
            // the child/patch list is prepended to the parent list without Maven
            // coordinate de-duplication. This is essential for modern Minecraft
            // metadata, where the same group:artifact:version may appear several
            // times with different rule sets and different artifact paths
            // (regular JAR, unsafe JAR and platform-native JAR variants).
            // Collapsing by group:artifact discards LWJGL modules such as
            // lwjgl-glfw/lwjgl-opengl and causes ClassNotFoundException at launch.
            QJsonArray libraries;
            for (const QJsonValue &value : child.value("libraries").toArray())
                libraries.append(value);
            for (const QJsonValue &value : parent.value("libraries").toArray())
                libraries.append(value);
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
    // HMCL distinguishes an external launcher version (the `patches` field is
    // absent) from an HMCL root version (the field exists). For an HMCL root,
    // top-level resolved fields are deliberately ignored and the effective
    // version is rebuilt exclusively from its sorted patches. Starting from
    // the top-level object here duplicates both JVM and game arguments.
    if (!object.contains(QStringLiteral("patches"))) return object;

    const QJsonArray patches = object.value(QStringLiteral("patches")).toArray();
    if (patches.isEmpty()) {
        object.remove(QStringLiteral("patches"));
        return object;
    }

    QList<QJsonObject> sorted;
    sorted.reserve(patches.size());
    for (const QJsonValue &value : patches) {
        if (value.isObject()) sorted.append(value.toObject());
    }
    std::sort(sorted.begin(), sorted.end(), [](const QJsonObject &a, const QJsonObject &b) {
        return a.value(QStringLiteral("priority")).toInt(0)
             < b.value(QStringLiteral("priority")).toInt(0);
    });

    QJsonObject resolved;
    const QString rootId = object.value(QStringLiteral("id")).toString();
    if (!rootId.isEmpty()) resolved.insert(QStringLiteral("id"), rootId);

    for (QJsonObject patch : std::as_const(sorted)) {
        const QString patchId = patch.value(QStringLiteral("id")).toString();
        if (patchId == QStringLiteral("game") && gameVersion) {
            const QString version = patch.value(QStringLiteral("version")).toString();
            if (!version.isEmpty()) *gameVersion = version;
        }
        // Same as Version.resolve(): patches cannot replace the primary jar.
        patch.remove(QStringLiteral("jar"));
        patch.remove(QStringLiteral("patches"));
        resolved = mergeVersionJson(resolved, patch);
    }
    if (!rootId.isEmpty()) resolved.insert(QStringLiteral("id"), rootId);
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


QStringList collapseRepeatedArgumentBlocks(QStringList arguments) {
    // Some old Qt-port versions persisted already-resolved argument arrays and
    // then appended the same patch arguments again. Collapse an exact repeated
    // block before applying option-level normalization. HMCL resolves a patch
    // container once, so an identical adjacent half cannot be intentional.
    bool changed = true;
    while (changed && arguments.size() >= 2) {
        changed = false;
        for (int repeatCount = 2; repeatCount <= arguments.size(); ++repeatCount) {
            if (arguments.size() % repeatCount != 0) continue;
            const int blockSize = arguments.size() / repeatCount;
            bool identical = true;
            for (int block = 1; block < repeatCount && identical; ++block) {
                for (int i = 0; i < blockSize; ++i) {
                    if (arguments.at(i) != arguments.at(block * blockSize + i)) {
                        identical = false;
                        break;
                    }
                }
            }
            if (identical) {
                arguments = arguments.mid(0, blockSize);
                changed = true;
                break;
            }
        }
    }
    return arguments;
}

QStringList deduplicateGameArguments(const QStringList &arguments) {
    static const QSet<QString> singletonOptions = {
        QStringLiteral("--username"), QStringLiteral("--version"),
        QStringLiteral("--gameDir"), QStringLiteral("--assetsDir"),
        QStringLiteral("--assetIndex"), QStringLiteral("--uuid"),
        QStringLiteral("--accessToken"), QStringLiteral("--clientId"),
        QStringLiteral("--xuid"), QStringLiteral("--userType"),
        QStringLiteral("--versionType"), QStringLiteral("--width"),
        QStringLiteral("--height"), QStringLiteral("--quickPlaySingleplayer"),
        QStringLiteral("--quickPlayMultiplayer")
    };

    QStringList result;
    QSet<QString> seen;
    for (int i = 0; i < arguments.size(); ++i) {
        const QString current = arguments.at(i);
        if (!singletonOptions.contains(current)) {
            result.append(current);
            continue;
        }

        const QString value = i + 1 < arguments.size() ? arguments.at(i + 1) : QString();
        if (!seen.contains(current)) {
            result.append(current);
            if (i + 1 < arguments.size()) result.append(value);
            seen.insert(current);
        }
        if (i + 1 < arguments.size()) ++i;
    }
    return result;
}

QString nativeClassifierForLibrary(const QJsonObject &library) {
#ifdef Q_OS_WIN
    const QString os = QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    const QString os = QStringLiteral("osx");
#else
    const QString os = QStringLiteral("linux");
#endif

    QString arch = QSysInfo::currentCpuArchitecture().toLower();
    if (arch == QStringLiteral("amd64") || arch == QStringLiteral("x64"))
        arch = QStringLiteral("x86_64");
    else if (arch == QStringLiteral("aarch64"))
        arch = QStringLiteral("arm64");
    const QString bits = QSysInfo::WordSize >= 64
        ? QStringLiteral("64") : QStringLiteral("32");

    // Port of HMCL Library.POSSIBLE_NATIVE_DESCRIPTORS/getClassifier().
    // Newer Mojang metadata may use linux, native-linux, natives-linux,
    // linux-x86_64, natives-linux-64, etc. It may also omit the `natives`
    // map and expose the descriptor directly in downloads.classifiers.
    const QStringList keys{QString(), arch, bits};
    const QStringList variants{QString(), QStringLiteral("native"),
                               QStringLiteral("natives")};
    const QJsonObject natives = library.value(QStringLiteral("natives")).toObject();
    const QJsonObject classifiers = library.value(QStringLiteral("downloads")).toObject()
                                        .value(QStringLiteral("classifiers")).toObject();
    for (const QString &key : keys) {
        for (const QString &variant : variants) {
            QString descriptor;
            if (!variant.isEmpty()) descriptor = variant + u'-';
            descriptor += os;
            if (!key.isEmpty()) descriptor += u'-' + key;

            QString mapped = natives.value(descriptor).toString();
            if (!mapped.isEmpty()) {
                mapped.replace(QStringLiteral("${arch}"), bits);
                return mapped;
            }
            if (classifiers.contains(descriptor)) return descriptor;
        }
    }
    return {};
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
        // HMCL excludes libraries represented by a native classifier from the
        // Java classpath and extracts them separately. Explicit classifier
        // artifacts without a natives/classifiers descriptor remain ordinary
        // classpath entries, matching HMCL Library.isNative().
        if (!nativeClassifierForLibrary(lib).isEmpty()) continue;
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
    struct Candidate {
        QString id;
        QFileInfo info;
        QJsonObject raw;
        QJsonObject resolved;
        QString gameVersion;
        QString type;
        QStringList loaderKinds;
        QString loaderSummary;
        QString iconName;
        QString signature;
        QString canonicalHelperId;
    };

    QList<Candidate> candidates;
    QSet<QString> inheritedParents;
    QHash<QString, int> signatureCount;

    QDir dir(LauncherPaths::versionsDir());
    if (!dir.exists()) return {};

    const auto entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot,
                                           QDir::Name);
    for (const QFileInfo &info : entries) {
        const QString id = info.fileName();
        const QJsonObject raw = readVersionJson(id);
        if (raw.isEmpty()) continue;

        const QString parent = raw.value(QStringLiteral("inheritsFrom")).toString();
        if (!parent.isEmpty()) inheritedParents.insert(parent);

        QString gameVersion;
        QString resolveError;
        const QJsonObject resolved = resolveVersionJsonChain(id, &gameVersion,
                                                              &resolveError);
        if (resolved.isEmpty()) continue;

        Candidate c;
        c.id = id;
        c.info = info;
        c.raw = raw;
        c.resolved = resolved;
        c.gameVersion = gameVersion.isEmpty() ? id : gameVersion;
        c.type = resolved.value(QStringLiteral("type")).toString(QStringLiteral("release"));
        c.loaderKinds = detectLoaderKinds(resolved, id);
        c.loaderSummary = QStringLiteral("原版");
        c.iconName = iconForVersion(id, c.type);
        if (c.loaderKinds.contains(QStringLiteral("fabric"))) {
            c.loaderSummary = QStringLiteral("Fabric");
            c.iconName = QStringLiteral("fabric");
        } else if (c.loaderKinds.contains(QStringLiteral("quilt"))) {
            c.loaderSummary = QStringLiteral("Quilt");
            c.iconName = QStringLiteral("quilt");
        } else if (c.loaderKinds.contains(QStringLiteral("neoforge"))) {
            c.loaderSummary = QStringLiteral("NeoForge");
            c.iconName = QStringLiteral("neoforge");
        } else if (c.loaderKinds.contains(QStringLiteral("forge"))) {
            c.loaderSummary = QStringLiteral("Forge");
            c.iconName = QStringLiteral("forge");
        } else if (c.loaderKinds.contains(QStringLiteral("optifine"))) {
            c.loaderSummary = QStringLiteral("OptiFine");
            c.iconName = QStringLiteral("optifine");
        }
        c.signature = loaderSignature(raw, c.gameVersion, c.loaderKinds);
        c.canonicalHelperId = canonicalLoaderHelperId(raw, c.gameVersion,
                                                       c.loaderKinds);
        if (!c.signature.isEmpty()) signatureCount[c.signature] += 1;
        candidates.append(c);
    }

    QJsonArray result;
    for (const Candidate &c : std::as_const(candidates)) {
        // HMCL's getDisplayVersions() excludes hidden versions. The vanilla
        // parent downloaded only to satisfy an inherited loader instance is
        // also an implementation detail and must not appear as a separate row.
        if (c.raw.value(QStringLiteral("hidden")).toBool(false)) continue;
        if (inheritedParents.contains(c.id)) continue;

        // Older Qt-port builds materialized a user-facing instance by copying
        // the canonical helper id (e.g. 26.2-fabric-0.19.3), leaving both on
        // disk. Prefer the named instance and suppress the generated helper.
        if (!c.signature.isEmpty()
                && signatureCount.value(c.signature) > 1
                && c.id.compare(c.canonicalHelperId, Qt::CaseInsensitive) == 0) {
            continue;
        }

        result.append(QJsonObject{
            {QStringLiteral("id"), c.id},
            {QStringLiteral("title"), c.id},
            {QStringLiteral("name"), c.id},
            {QStringLiteral("subtitle"), c.gameVersion},
            {QStringLiteral("tag"), c.type},
            {QStringLiteral("versionType"), c.type},
            {QStringLiteral("gameVersion"), c.gameVersion},
            {QStringLiteral("loaderSummary"), c.loaderSummary},
            {QStringLiteral("iconName"), c.iconName},
            {QStringLiteral("selected"), false},
            {QStringLiteral("canUpdate"), false},
            {QStringLiteral("path"), c.info.absoluteFilePath()}
        });
    }
    return result;
}

QJsonObject InstanceService::list() {
    const QJsonArray instances = scanVersions();
    QString selected = readSelectedInstanceId();
    bool selectedExists = false;
    for (const QJsonValue &value : instances) {
        if (value.toObject().value(QStringLiteral("id")).toString() == selected) {
            selectedExists = true;
            break;
        }
    }
    if (!selectedExists) {
        selected = instances.isEmpty()
            ? QString()
            : instances.first().toObject().value(QStringLiteral("id")).toString();
        writeSelectedInstanceId(selected);
    }

    QJsonArray marked;
    for (const QJsonValue &value : instances) {
        QJsonObject item = value.toObject();
        item.insert(QStringLiteral("selected"),
                    item.value(QStringLiteral("id")).toString() == selected);
        marked.append(item);
    }

    QJsonArray profiles;
    profiles.append(QJsonObject{
        {QStringLiteral("id"), QStringLiteral("default")},
        {QStringLiteral("name"), QStringLiteral("默认游戏目录")},
        {QStringLiteral("path"), LauncherPaths::minecraftDir()},
        {QStringLiteral("selected"), true}
    });
    return QJsonObject{
        {QStringLiteral("instances"), marked},
        {QStringLiteral("profiles"), profiles},
        {QStringLiteral("selectedInstance"), selected}
    };
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
    const QString id = versionId.trimmed();
    if (!id.isEmpty() && QFileInfo(versionDir(id)).isDir())
        writeSelectedInstanceId(id);
    return list();
}

QJsonObject InstanceService::rename(const QString &versionId, const QString &newName) {
    const QString targetId = newName.trimmed();
    const QString oldDir = versionDir(versionId);
    const QString newDir = LauncherPaths::versionsDir() + "/" + targetId;
    const bool ok = !targetId.isEmpty() && !QFileInfo(newDir).exists()
                 && QDir().rename(oldDir, newDir);
    if (ok) {
        const QString oldJson = newDir + "/" + versionId + ".json";
        const QString newJson = newDir + "/" + targetId + ".json";
        if (QFileInfo(oldJson).isFile()) QFile::rename(oldJson, newJson);
        QJsonObject json = JsonUtil::readObjectFile(newJson, {});
        if (!json.isEmpty()) {
            json.insert(QStringLiteral("id"), targetId);
            JsonUtil::writeObjectFile(newJson, json);
        }
        if (readSelectedInstanceId() == versionId) writeSelectedInstanceId(targetId);
    }
    return QJsonObject{{"success", ok},
                       {"message", ok ? "已重命名实例" : "重命名失败"}};
}

QJsonObject InstanceService::duplicate(const QString &versionId, const QString &newName, bool copySaves) {
    const QString targetId = newName.trimmed();
    const QString sourceDir = versionDir(versionId);
    const QString targetDir = versionDir(targetId);
    if (targetId.isEmpty() || !QFileInfo(sourceDir).isDir() || QFileInfo(targetDir).exists()) {
        return QJsonObject{{"success", false}, {"message", "复制失败：目标名称无效或已存在"}};
    }

    if (!QDir().mkpath(targetDir))
        return QJsonObject{{"success", false}, {"message", "复制失败：无法创建目标目录"}};

    QDir source(sourceDir);
    QDirIterator iterator(sourceDir, QDir::NoDotAndDotDot | QDir::AllEntries,
                          QDirIterator::Subdirectories);
    bool ok = true;
    while (iterator.hasNext() && ok) {
        const QString sourcePath = iterator.next();
        const QFileInfo info(sourcePath);
        QString relative = source.relativeFilePath(sourcePath);
        if (relative == versionId + QStringLiteral(".json"))
            relative = targetId + QStringLiteral(".json");
        if (relative == versionId + QStringLiteral(".jar"))
            relative = targetId + QStringLiteral(".jar");
        const QString targetPath = targetDir + u'/' + relative;
        if (info.isDir()) {
            ok = QDir().mkpath(targetPath);
        } else {
            QDir().mkpath(QFileInfo(targetPath).absolutePath());
            ok = QFile::copy(sourcePath, targetPath);
        }
    }

    const QString targetJsonPath = targetDir + u'/' + targetId + QStringLiteral(".json");
    if (ok) {
        QJsonObject json = JsonUtil::readObjectFile(targetJsonPath, {});
        if (json.isEmpty()) {
            ok = false;
        } else {
            json.insert(QStringLiteral("id"), targetId);
            ok = JsonUtil::writeObjectFile(targetJsonPath, json);
        }
    }

    // HMCL only copies the instance working directory when the user asks for
    // saves. This project currently uses the shared ~/.minecraft run directory,
    // so there is no per-instance saves tree to duplicate here.
    Q_UNUSED(copySaves)

    if (!ok) QDir(targetDir).removeRecursively();
    return QJsonObject{{"success", ok},
                       {"message", ok ? "已复制实例" : "复制实例失败"}};
}

QJsonObject InstanceService::remove(const QString &versionId) {
    const QJsonObject removedJson = readVersionJson(versionId);
    const QString parentId = removedJson.value(QStringLiteral("inheritsFrom")).toString();
    const bool ok = QDir(versionDir(versionId)).removeRecursively();

    if (ok && !parentId.isEmpty()) {
        bool parentStillReferenced = false;
        QDir versions(LauncherPaths::versionsDir());
        for (const QFileInfo &info : versions.entryInfoList(
                 QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
            const QString id = info.fileName();
            const QJsonObject raw = readVersionJson(id);
            if (raw.value(QStringLiteral("inheritsFrom")).toString() == parentId) {
                parentStillReferenced = true;
                break;
            }
        }
        if (!parentStillReferenced) {
            const QJsonObject parent = readVersionJson(parentId);
            if (parent.value(QStringLiteral("hmclQtHelper")).toBool(false)
                    || parent.value(QStringLiteral("hidden")).toBool(false)) {
                QDir(versionDir(parentId)).removeRecursively();
            }
        }
    }

    if (ok && readSelectedInstanceId() == versionId) {
        const QJsonArray remaining = scanVersions();
        const QString next = remaining.isEmpty()
            ? QString()
            : remaining.first().toObject().value(QStringLiteral("id")).toString();
        writeSelectedInstanceId(next);
    }
    return QJsonObject{{"success", ok},
                       {"message", ok ? "已删除实例" : "删除失败"}};
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
        const QString classifier = nativeClassifierForLibrary(library);
        if (!classifier.isEmpty()) {
            const QJsonObject nativeArtifact = downloads.value("classifiers").toObject()
                                                   .value(classifier).toObject();
            QString nativeRelative = nativeArtifact.value("path").toString();
            if (nativeRelative.isEmpty()) {
                QString coordinate = library.value("name").toString();
                const QStringList parts = coordinate.split(u':');
                if (parts.size() >= 3) {
                    QString group = parts.at(0);
                    group.replace(u'.', u'/');
                    const QString artifactName = parts.at(1);
                    const QString artifactVersion = parts.at(2);
                    nativeRelative = group + u'/' + artifactName + u'/' + artifactVersion
                        + u'/' + artifactName + u'-' + artifactVersion + u'-'
                        + classifier + QStringLiteral(".jar");
                }
            }
            if (nativeRelative.isEmpty()) continue;

            const QString nativePath = librariesRoot + u'/' + nativeRelative;
            if (!options.nativeArchives.contains(nativePath))
                options.nativeArchives.append(nativePath);
            const QString nativeSha1 = nativeArtifact.value("sha1").toString();
            if (!fileMatchesSha1(nativePath, nativeSha1)
                    && !scheduledPaths.contains(nativePath)) {
                const QString nativeUrl = libraryUrlFor(library, nativeArtifact,
                                                        nativeRelative);
                if (nativeUrl.isEmpty()) missingWithoutUrl.append(nativePath);
                else dependencyDownloads.append(repairDownload(
                    provider.candidatesFor(nativeUrl), nativePath, nativeSha1,
                    static_cast<qint64>(nativeArtifact.value("size").toDouble()),
                    QFileInfo(nativePath).fileName(),
                    QStringLiteral("hmcl.install.libraries")));
                scheduledPaths.insert(nativePath);
            }
            continue;
        }

        const QJsonObject artifact = downloads.value("artifact").toObject();
        QString relative = artifact.value("path").toString();
        if (relative.isEmpty())
            relative = VersionRules::libraryPathFromName(
                library.value("name").toString());
        if (relative.isEmpty()) continue;

        const QString path = librariesRoot + u'/' + relative;
        const QString sha1 = artifact.value("sha1").toString();
        if (!fileMatchesSha1(path, sha1) && !scheduledPaths.contains(path)) {
            const QString url = libraryUrlFor(library, artifact, relative);
            if (url.isEmpty()) missingWithoutUrl.append(path);
            else dependencyDownloads.append(repairDownload(
                provider.candidatesFor(url), path, sha1,
                static_cast<qint64>(artifact.value("size").toDouble()),
                QFileInfo(path).fileName(),
                QStringLiteral("hmcl.install.libraries")));
            scheduledPaths.insert(path);
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
    QStringList versionJvmArguments = collapseRepeatedArgumentBlocks(
        parseArgumentList(arguments.value("jvm").toArray(), vars, enabledFeatures));
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

    QStringList gameArguments = collapseRepeatedArgumentBlocks(
        parseArgumentList(arguments.value("game").toArray(), vars, enabledFeatures));
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

    // HMCL root versions are patch containers. Older Qt-port builds merged
    // both the root's pre-resolved arguments and its patches, which produced
    // duplicate singleton options such as --version. Keep one value for each
    // launcher-owned singleton option before appending user custom arguments.
    gameArguments = deduplicateGameArguments(gameArguments);

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
