#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

// Shared Minecraft version-JSON rule + path helpers, ported from HMCL
// (Rule.java / Library.java / Artifact.java). Used by both InstanceService
// (launch command) and GameInstaller (library download) so the OS-filtering
// logic stays identical on both paths.
namespace VersionRules {

// Evaluates a single rule object against the current (Linux) environment.
bool ruleMatchesCurrentLinux(const QJsonObject &rule);

// Applies an ordered list of allow/disallow rules; empty list means allowed.
bool allowedByRules(const QJsonArray &rules);

// Derives the Maven-style relative jar path from a library "name" coordinate
// (group:artifact:version[:classifier]) when downloads.artifact.path is absent.
QString libraryPathFromName(const QString &name);

} // namespace VersionRules
