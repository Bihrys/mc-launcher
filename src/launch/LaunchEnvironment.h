#pragma once

#include "launch/LaunchOptions.h"

#include <QProcessEnvironment>

namespace LaunchEnvironment {

// Builds the process environment using the same layers as HMCL:
// system environment -> instance variables -> renderer variables -> user values.
QProcessEnvironment build(const LaunchOptions &options,
                          const QProcessEnvironment &userVariables = {});

} // namespace LaunchEnvironment
