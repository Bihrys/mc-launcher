#include "game/VersionRules.h"

#include <QOperatingSystemVersion>
#include <QRegularExpression>
#include <QSysInfo>
#include <QJsonValue>
#include <QStringList>

namespace {

QString minecraftOsName() {
#ifdef Q_OS_WIN
    return QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    return QStringLiteral("osx");
#else
    return QStringLiteral("linux");
#endif
}

QString minecraftArchName() {
    const QString arch = QSysInfo::currentCpuArchitecture().toLower();
    if (arch == "x86_64" || arch == "amd64" || arch == "x64")
        return QStringLiteral("x86_64");
    if (arch == "i386" || arch == "i486" || arch == "i586"
            || arch == "i686" || arch == "x86")
        return QStringLiteral("x86");
    if (arch == "aarch64" || arch == "arm64")
        return QStringLiteral("arm64");
    return arch;
}

bool regexMatches(const QString &pattern, const QString &value) {
    if (pattern.isEmpty()) return true;
    const QRegularExpression re(pattern);
    return re.isValid() && re.match(value).hasMatch();
}

} // namespace

namespace VersionRules {

bool ruleMatchesCurrentEnvironment(const QJsonObject &rule,
                                   const QSet<QString> &enabledFeatures) {
    const QJsonObject os = rule.value("os").toObject();
    if (!os.isEmpty()) {
        const QString requiredName = os.value("name").toString();
        if (!requiredName.isEmpty() && requiredName != minecraftOsName())
            return false;

        const QString requiredArch = os.value("arch").toString();
        if (!regexMatches(requiredArch, minecraftArchName()))
            return false;

        const QString requiredVersion = os.value("version").toString();
        const QOperatingSystemVersion current = QOperatingSystemVersion::current();
        const QString currentVersion = QString("%1.%2.%3")
            .arg(current.majorVersion()).arg(current.minorVersion()).arg(current.microVersion());
        if (!regexMatches(requiredVersion, currentVersion))
            return false;
    }

    const QJsonObject features = rule.value("features").toObject();
    for (auto it = features.begin(); it != features.end(); ++it) {
        if (!it.value().isBool()) return false;
        const bool actual = enabledFeatures.contains(it.key());
        if (actual != it.value().toBool()) return false;
    }

    return true;
}

bool allowedByRules(const QJsonArray &rules,
                    const QSet<QString> &enabledFeatures) {
    if (rules.isEmpty()) return true;

    bool allowed = false;
    for (const QJsonValue &value : rules) {
        if (!value.isObject()) continue;
        const QJsonObject rule = value.toObject();
        if (!ruleMatchesCurrentEnvironment(rule, enabledFeatures)) continue;
        allowed = rule.value("action").toString() == QStringLiteral("allow");
    }
    return allowed;
}

QString libraryPathFromName(const QString &name) {
    const QStringList parts = name.split(':');
    if (parts.size() < 3) return QString();
    QString groupPath = parts.at(0);
    groupPath.replace('.', '/');
    const QString artifact = parts.at(1);
    const QString version = parts.at(2);
    QString fileName = artifact + "-" + version;
    if (parts.size() >= 4 && !parts.at(3).isEmpty()) fileName += "-" + parts.at(3);
    return groupPath + "/" + artifact + "/" + version + "/" + fileName + ".jar";
}

} // namespace VersionRules
