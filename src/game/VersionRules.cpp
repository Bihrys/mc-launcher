#include "game/VersionRules.h"

#include <QJsonValue>
#include <QStringList>

namespace VersionRules {

bool ruleMatchesCurrentLinux(const QJsonObject &rule) {
    const QString action = rule.value("action").toString();
    const QJsonObject os = rule.value("os").toObject();
    if (os.isEmpty()) return action == "allow";
    const QString name = os.value("name").toString();
    if (name.isEmpty() || name == "linux") return action == "allow";
    return action == "disallow";
}

bool allowedByRules(const QJsonArray &rules) {
    if (rules.isEmpty()) return true;
    bool allowed = false;
    for (const QJsonValue &v : rules) {
        const QJsonObject rule = v.toObject();
        if (ruleMatchesCurrentLinux(rule)) allowed = rule.value("action").toString() == "allow";
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
