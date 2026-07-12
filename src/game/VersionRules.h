#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QSet>
#include <QString>

// Shared Minecraft version-JSON rule + path helpers, ported from HMCL's
// Rule.java / Library.java / Artifact.java. The feature set is intentionally
// explicit: launch arguments guarded by quick-play/demo/custom-resolution
// features must not be enabled unless the launcher actually requested them.
namespace VersionRules {

// Evaluates only the condition part of a rule against the current runtime.
// The rule's action (allow/disallow) is handled by allowedByRules().
bool ruleMatchesCurrentEnvironment(const QJsonObject &rule,
                                   const QSet<QString> &enabledFeatures = {});

// Applies Mojang's ordered allow/disallow rule list. Empty list means allowed.
bool allowedByRules(const QJsonArray &rules,
                    const QSet<QString> &enabledFeatures = {});

// Derives the Maven-style relative jar path from a library "name" coordinate
// (group:artifact:version[:classifier]) when downloads.artifact.path is absent.
QString libraryPathFromName(const QString &name);

} // namespace VersionRules
