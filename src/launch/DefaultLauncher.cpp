#include "launch/DefaultLauncher.h"

#include "logging/AppLogger.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>

#include <utility>

DefaultLauncher::DefaultLauncher(LaunchOptions options,
                                 ProcessListener *listener,
                                 QObject *parent)
    : QObject(parent), m_options(std::move(options)), m_listener(listener) {
    m_readyTimer.setSingleShot(true);
    // HMCL normally finishes the waiting stage when the game log reaches
    // LWJGL initialization. Keep a long fallback for versions/mod loaders
    // that suppress these lines instead of declaring success immediately.
    m_readyTimer.setInterval(30000);

    connect(&m_readyTimer, &QTimer::timeout, this, [this]() {
        if (m_process.state() == QProcess::Running) markReady();
    });

    connect(&m_process, &QProcess::started, this, [this]() {
        AppLogger::info("launch", "process_started", "游戏进程已创建", {
            {"versionId", m_options.versionId},
            {"pid", static_cast<double>(m_process.processId())},
            {"gameLogFile", m_options.logFile},
            {"java", m_options.javaExecutable}
        });
        if (m_listener) m_listener->onProcessStarted(m_process.processId());
        m_readyTimer.start();
    });

    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        appendLog(m_process.readAllStandardOutput(), false);
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this]() {
        appendLog(m_process.readAllStandardError(), true);
    });

    connect(&m_process, &QProcess::errorOccurred, this,
            [this](QProcess::ProcessError error) {
        if (m_stopping && error == QProcess::Crashed) return;
        const QString message = m_process.errorString().isEmpty()
            ? QStringLiteral("无法创建游戏进程。") : m_process.errorString();
        AppLogger::error("launch", "process_error", message, {
            {"versionId", m_options.versionId},
            {"processError", static_cast<int>(error)}
        });
        if (m_listener) m_listener->onProcessError(message);
    });

    connect(&m_process,
            qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
        m_readyTimer.stop();
        appendLog(m_process.readAllStandardOutput(), false);
        appendLog(m_process.readAllStandardError(), true);
        if (m_logFile.isOpen()) {
            const QByteArray footer = QString("\n[%1] [HMCL-Qt ProcessListener] Minecraft exit with code %2.\n")
                .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs))
                .arg(exitCode).toUtf8();
            m_logFile.write(footer);
            m_logFile.flush();
        }
        const bool crashed = exitStatus == QProcess::CrashExit;
        AppLogger::info("launch", "process_exited", "游戏进程已退出", {
            {"versionId", m_options.versionId},
            {"exitCode", exitCode},
            {"crashed", crashed},
            {"exitedBeforeReady", !m_ready}
        });
        if (m_listener)
            m_listener->onProcessExited(exitCode, crashed, !m_ready);
    });
}

DefaultLauncher::~DefaultLauncher() {
    if (m_process.state() != QProcess::NotRunning) {
        m_process.disconnect();
        m_process.kill();
        m_process.waitForFinished(1000);
    }
}

void DefaultLauncher::start() {
    if (m_process.state() != QProcess::NotRunning) return;

    QDir().mkpath(QFileInfo(m_options.logFile).absolutePath());
    m_logFile.setFileName(m_options.logFile);
    if (m_logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        m_logFile.write(QString("[%1] Command: %2\n")
                            .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs),
                                 m_options.displayCommand)
                            .toUtf8());
        m_logFile.flush();
    }

    m_process.setProgram(m_options.javaExecutable);
    m_process.setArguments(m_options.arguments);
    m_process.setWorkingDirectory(m_options.workingDirectory);
    m_process.setProcessEnvironment(m_options.environment);
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    m_process.start(QIODevice::ReadOnly);
}

void DefaultLauncher::stop() {
    if (m_process.state() == QProcess::NotRunning) return;
    m_stopping = true;
    m_readyTimer.stop();
    m_process.terminate();
    if (!m_process.waitForFinished(3000)) {
        m_process.kill();
        m_process.waitForFinished(2000);
    }
}

bool DefaultLauncher::isRunning() const {
    return m_process.state() != QProcess::NotRunning;
}

qint64 DefaultLauncher::processId() const {
    return m_process.processId();
}

void DefaultLauncher::appendLog(const QByteArray &data, bool standardError) {
    if (data.isEmpty()) return;
    detectReadyFromLog(data);
    if (m_logFile.isOpen()) {
        m_logFile.write(data);
        if (!data.endsWith('\n')) m_logFile.write("\n");
        m_logFile.flush();
    }
    if (m_listener) m_listener->onProcessLog(data, standardError);
}


void DefaultLauncher::markReady() {
    if (m_ready) return;
    m_ready = true;
    m_readyTimer.stop();
    if (m_listener) m_listener->onProcessReady();
}

void DefaultLauncher::detectReadyFromLog(const QByteArray &data) {
    if (m_ready || data.isEmpty()) return;
    m_readyProbeBuffer.append(data.toLower());
    if (m_readyProbeBuffer.size() > 2048)
        m_readyProbeBuffer = m_readyProbeBuffer.right(2048);
    // Same launch-window signal used by HMCL's HMCLProcessListener.
    if (m_readyProbeBuffer.contains("lwjgl version")
        || m_readyProbeBuffer.contains("lwjgl openal")) {
        markReady();
    }
}
