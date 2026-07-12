#pragma once

#include "launch/Launcher.h"
#include "launch/ProcessListener.h"

#include <QFile>
#include <QObject>
#include <QProcess>
#include <QTimer>

class DefaultLauncher final : public QObject, public Launcher {
    Q_OBJECT
public:
    explicit DefaultLauncher(LaunchOptions options,
                             ProcessListener *listener,
                             QObject *parent = nullptr);
    ~DefaultLauncher() override;

    void start() override;
    void stop() override;
    bool isRunning() const override;
    qint64 processId() const override;

    const LaunchOptions &options() const { return m_options; }

private:
    void appendLog(const QByteArray &data, bool standardError);
    void markReady();
    void detectReadyFromLog(const QByteArray &data);

    LaunchOptions m_options;
    ProcessListener *m_listener = nullptr;
    QProcess m_process;
    QFile m_logFile;
    QTimer m_readyTimer;
    bool m_ready = false;
    bool m_stopping = false;
    QByteArray m_readyProbeBuffer;
};
