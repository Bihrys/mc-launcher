#include "launch/DefaultLauncher.h"

#include "logging/AppLogger.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>

#include <utility>

namespace {

bool containsAny(const QByteArray &text, const QList<QByteArray> &needles) {
    const QByteArray lower = text.toLower();
    for (const QByteArray &needle : needles) {
        if (lower.contains(needle.toLower())) return true;
    }
    return false;
}

QString exitTypeName(ProcessListener::ExitType type) {
    switch (type) {
    case ProcessListener::ExitType::JvmError: return QStringLiteral("JVM_ERROR");
    case ProcessListener::ExitType::ApplicationError: return QStringLiteral("APPLICATION_ERROR");
    case ProcessListener::ExitType::SigKill: return QStringLiteral("SIGKILL");
    case ProcessListener::ExitType::Normal: return QStringLiteral("NORMAL");
    case ProcessListener::ExitType::Interrupted: return QStringLiteral("INTERRUPTED");
    }
    return QStringLiteral("APPLICATION_ERROR");
}

} // namespace

DefaultLauncher::DefaultLauncher(LaunchOptions options,
                                 ProcessListener *listener,
                                 QObject *parent)
    : QObject(parent), m_options(std::move(options)), m_listener(listener) {
    connect(&m_process, &QProcess::started, this, [this]() {
        AppLogger::info("launch", "process_started", "游戏进程已创建", {
            {"versionId", m_options.versionId},
            {"pid", static_cast<double>(m_process.processId())},
            {"gameLogFile", m_options.logFile},
            {"java", m_options.javaExecutable},
            {"renderer", m_options.renderer},
            {"graphicsBackend", m_options.graphicsBackend}
        });
        if (m_listener) m_listener->onProcessStarted(m_process.processId());
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
        if (error == QProcess::Crashed && m_process.state() == QProcess::NotRunning)
            return; // finished() performs the HMCL-style exit classification.
        if (m_errorReported) return;
        m_errorReported = true;
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
        appendLog(m_process.readAllStandardOutput(), false);
        appendLog(m_process.readAllStandardError(), true);

        const ProcessListener::ExitType exitType = m_stopping
            ? ProcessListener::ExitType::Interrupted
            : classifyExit(exitCode, exitStatus);

        if (m_logFile.isOpen()) {
            const QByteArray footer = QString(
                "\n[%1] [HMCL ProcessListener] Minecraft exit with code %2(0x%3), type is %4.\n")
                .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs))
                .arg(exitCode)
                .arg(QString::number(static_cast<quint32>(exitCode), 16))
                .arg(exitTypeName(exitType))
                .toUtf8();
            m_logFile.write(footer);
            m_logFile.flush();
        }

        AppLogger::info("launch", "process_exited", "游戏进程已退出", {
            {"versionId", m_options.versionId},
            {"exitCode", exitCode},
            {"exitType", exitTypeName(exitType)},
            {"exitedBeforeReady", !m_ready}
        });
        if (m_listener)
            m_listener->onProcessExited(exitCode, exitType, !m_ready);
    });
}

DefaultLauncher::~DefaultLauncher() {
    // HMCL keeps the launcher alive while a managed process is running. Only
    // an explicit stop() is allowed to terminate Minecraft.
    if (m_process.state() != QProcess::NotRunning && m_stopping) {
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
        m_logFile.write(QString("[%1] Working directory: %2\n")
                            .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs),
                                 m_options.workingDirectory)
                            .toUtf8());
        m_logFile.write(QString("[%1] Renderer: %2, graphics backend: %3\n")
                            .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs),
                                 m_options.renderer,
                                 m_options.graphicsBackend)
                            .toUtf8());
        m_logFile.flush();
    }

    AppLogger::info("launch", "graphics_environment", QString(), {
        {"renderer", m_options.renderer},
        {"graphicsBackend", m_options.graphicsBackend},
        {"display", m_options.environment.value(QStringLiteral("DISPLAY"))},
        {"waylandDisplay", m_options.environment.value(QStringLiteral("WAYLAND_DISPLAY"))},
        {"sessionType", m_options.environment.value(QStringLiteral("XDG_SESSION_TYPE"))},
        {"glxVendor", m_options.environment.value(QStringLiteral("__GLX_VENDOR_LIBRARY_NAME"))},
        {"libglSoftware", m_options.environment.value(QStringLiteral("LIBGL_ALWAYS_SOFTWARE"))},
        {"mesaDriver", m_options.environment.value(QStringLiteral("MESA_LOADER_DRIVER_OVERRIDE"))}
    });

    m_process.setProgram(m_options.javaExecutable);
    m_process.setArguments(m_options.arguments);
    m_process.setWorkingDirectory(m_options.workingDirectory);
    m_process.setProcessEnvironment(m_options.environment);
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    m_process.start(QIODevice::ReadWrite);
}

void DefaultLauncher::stop() {
    if (m_process.state() == QProcess::NotRunning) return;
    m_stopping = true;
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

    m_logBuffer.append(data);
    constexpr qsizetype maxLogBytes = 512 * 1024;
    if (m_logBuffer.size() > maxLogBytes)
        m_logBuffer = m_logBuffer.right(maxLogBytes);

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
    if (m_listener) m_listener->onProcessReady();
}

void DefaultLauncher::detectReadyFromLog(const QByteArray &data) {
    if (m_ready || data.isEmpty()) return;
    if (!m_options.detectWindow) {
        markReady();
        return;
    }

    m_readyProbeBuffer.append(data.toLower());
    if (m_readyProbeBuffer.size() > 4096)
        m_readyProbeBuffer = m_readyProbeBuffer.right(4096);

    // Same signal used by HMCL's HMCLProcessListener. There is intentionally
    // no timeout fallback: an error dialog must not be reported as a successful
    // launch merely because the Java process stayed alive for 30 seconds.
    if (m_readyProbeBuffer.contains("lwjgl version")
        || m_readyProbeBuffer.contains("lwjgl openal")) {
        markReady();
    }
}

ProcessListener::ExitType DefaultLauncher::classifyExit(
        int exitCode, QProcess::ExitStatus exitStatus) const {
    Q_UNUSED(exitStatus)

    if (exitCode != 0 && containsAny(m_logBuffer, {
            QByteArrayLiteral("Could not create the Java Virtual Machine."),
            QByteArrayLiteral("Error occurred during initialization of VM"),
            QByteArrayLiteral("A fatal exception has occurred. Program will exit.")
        })) {
        return ProcessListener::ExitType::JvmError;
    }

    if (exitCode != 0 || containsAny(m_logBuffer, {
            QByteArrayLiteral("Crash report saved to"),
            QByteArrayLiteral("Could not save crash report to"),
            QByteArrayLiteral("This crash report has been saved to:"),
            QByteArrayLiteral("Unable to launch"),
            QByteArrayLiteral("An exception was thrown, the game will display an error screen and halt."),
            QByteArrayLiteral("GLX: Failed to create context: GLXBadFBConfig")
        })) {
#if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)
        if (exitCode == 137) return ProcessListener::ExitType::SigKill;
#endif
        return ProcessListener::ExitType::ApplicationError;
    }

    return ProcessListener::ExitType::Normal;
}
