#pragma once

#include "launch/LaunchOptions.h"

class Launcher {
public:
    virtual ~Launcher() = default;
    virtual void start() = 0;
    virtual void stop() = 0;
    virtual bool isRunning() const = 0;
    virtual qint64 processId() const = 0;
};
