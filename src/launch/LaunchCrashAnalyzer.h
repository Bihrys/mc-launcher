#pragma once

#include <QString>

namespace LaunchCrashAnalyzer {

struct Result {
    bool matched = false;
    QString category;
    QString title;
    QString message;
};

Result analyze(const QString &logText, int exitCode);

} // namespace LaunchCrashAnalyzer
