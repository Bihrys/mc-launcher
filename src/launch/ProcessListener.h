#pragma once

#include <QByteArray>
#include <QString>

class ProcessListener {
public:
    virtual ~ProcessListener() = default;
    virtual void onProcessStarted(qint64 pid) = 0;
    virtual void onProcessLog(const QByteArray &data, bool standardError) = 0;
    virtual void onProcessReady() = 0;
    virtual void onProcessExited(int exitCode, bool crashed, bool exitedBeforeReady) = 0;
    virtual void onProcessError(const QString &message) = 0;
};
