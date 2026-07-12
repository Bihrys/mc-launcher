#pragma once

#include <QByteArray>
#include <QString>

class ProcessListener {
public:
    enum class ExitType {
        JvmError,
        ApplicationError,
        SigKill,
        Normal,
        Interrupted
    };

    virtual ~ProcessListener() = default;
    virtual void onProcessStarted(qint64 pid) = 0;
    virtual void onProcessLog(const QByteArray &data, bool standardError) = 0;
    virtual void onProcessReady() = 0;
    virtual void onProcessExited(int exitCode, ExitType exitType,
                                 bool exitedBeforeReady) = 0;
    virtual void onProcessError(const QString &message) = 0;
};
