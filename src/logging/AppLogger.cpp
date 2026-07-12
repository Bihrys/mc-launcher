#include "logging/AppLogger.h"

#include "core/LauncherPaths.h"

#include <QByteArray>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QMutexLocker>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSysInfo>
#include <QStringList>
#include <QThread>
#include <QUuid>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>

#ifdef Q_OS_UNIX
#include <fcntl.h>
#include <unistd.h>
#endif

#ifdef __linux__
#include <execinfo.h>
#include <sys/syscall.h>
#endif

namespace {
struct LoggerState {
    QMutex mutex;
    std::unique_ptr<QFile> latest;
    std::unique_ptr<QFile> session;
    QString logsDir;
    QString latestPath;
    QString sessionPath;
    QString crashPath;
    QString statePath;
    QString sessionId;
    QElapsedTimer elapsed;
    bool initialized = false;
    bool cleanShutdownWritten = false;
#ifdef Q_OS_UNIX
    int crashFd = -1;
#endif
};

LoggerState &state() {
    static LoggerState value;
    return value;
}

QString compactJson(const QJsonObject &object) {
    return QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

QString normalizedMessage(QString value) {
    value.replace('\r', "\\r");
    value.replace('\n', "\\n");
    return value;
}

bool shouldEchoToConsole(const char *level, const QString &category, const QString &event) {
    const QByteArray verbose = qgetenv("MC_LAUNCHER_VERBOSE_LOGS").trimmed().toLower();
    if (verbose == "1" || verbose == "true" || verbose == "yes") return true;

    const QByteArray severity(level);
    if (severity == "WARN" || severity == "ERROR" || severity == "FATAL") return true;

    // Keep only the useful lifecycle and launch milestones on the terminal.
    if (category == "lifecycle" &&
        (event == "logger_initialized" || event == "clean_shutdown")) return true;
    if (category == "launch" &&
        (event == "process_started" || event == "process_start_failed")) return true;
    return false;
}

QString threadIdString() {
#ifdef __linux__
    return QString::number(static_cast<qulonglong>(::syscall(SYS_gettid)));
#else
    return QString::number(reinterpret_cast<quintptr>(QThread::currentThreadId()), 16);
#endif
}

bool sensitiveKey(const QString &key) {
    const QString lower = key.toLower();
    static const QStringList fragments = {
        "password", "passwd", "access_token", "refreshtoken", "refresh_token",
        "authorization", "cookie", "clientsecret", "client_secret", "credential",
        "privatekey", "private_key", "sessiontoken", "session_token", "bearer",
        "token", "secret", "api_key", "apikey"
    };
    for (const QString &fragment : fragments) {
        if (lower.contains(fragment)) return true;
    }
    return false;
}

QJsonValue redactValue(const QString &key, const QJsonValue &value) {
    if (sensitiveKey(key)) return QStringLiteral("<redacted>");
    if (value.isObject()) return AppLogger::redactObject(value.toObject());
    if (value.isArray()) {
        QJsonArray out;
        const QJsonArray array = value.toArray();
        for (const QJsonValue &item : array) {
            if (item.isObject()) out.append(AppLogger::redactObject(item.toObject()));
            else if (item.isString()) out.append(AppLogger::redactText(item.toString()));
            else out.append(item);
        }
        return out;
    }
    if (value.isString()) return AppLogger::redactText(value.toString());
    return value;
}

void pruneOldLogs(const QString &directory) {
    QDir dir(directory);
    const QFileInfoList files = dir.entryInfoList({"session-*.log"}, QDir::Files, QDir::Time);
    constexpr int keepCount = 30;
    for (int i = keepCount; i < files.size(); ++i) {
        QFile::remove(files.at(i).absoluteFilePath());
    }
}

QJsonObject readStateFile(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject()) return {};
    return doc.object();
}

void writeStateFile(const QString &path, const QJsonObject &object) {
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    file.commit();
}


void qtMessageHandler(QtMsgType type, const QMessageLogContext &context,
                      const QString &message) {
    thread_local bool handlingMessage = false;
    if (handlingMessage) {
        const QByteArray fallback = (QStringLiteral("[QT-RECURSIVE] ") + message + QLatin1Char('\n')).toUtf8();
        std::fwrite(fallback.constData(), 1, static_cast<size_t>(fallback.size()), stderr);
        std::fflush(stderr);
        return;
    }
    handlingMessage = true;

    QJsonObject details;
    if (context.file) details.insert("file", QString::fromUtf8(context.file));
    if (context.function) details.insert("function", QString::fromUtf8(context.function));
    if (context.line > 0) details.insert("line", context.line);
    if (context.category) details.insert("qtCategory", QString::fromUtf8(context.category));

    const QString category = context.category && *context.category
        ? QStringLiteral("qt.") + QString::fromUtf8(context.category)
        : QStringLiteral("qt");

    switch (type) {
    case QtDebugMsg:
        AppLogger::debug(category, "message", message, details);
        break;
    case QtInfoMsg:
        AppLogger::info(category, "message", message, details);
        break;
    case QtWarningMsg:
        AppLogger::warning(category, "message", message, details);
        break;
    case QtCriticalMsg:
        AppLogger::error(category, "message", message, details);
        break;
    case QtFatalMsg:
        AppLogger::fatal(category, "message", message, details);
        AppLogger::flush();
        std::abort();
    }

    handlingMessage = false;
}

#ifdef Q_OS_UNIX
volatile std::sig_atomic_t g_inSignalHandler = 0;

void rawWrite(int fd, const char *text) {
    if (fd < 0 || !text) return;
    const size_t len = std::strlen(text);
    ssize_t ignored = ::write(fd, text, len);
    Q_UNUSED(ignored);
}

void crashSignalHandler(int signalNumber) {
    if (g_inSignalHandler) _exit(128 + signalNumber);
    g_inSignalHandler = 1;

    LoggerState &s = state();
    char header[256];
#ifdef __linux__
    const long tid = ::syscall(SYS_gettid);
#else
    const long tid = 0;
#endif
    const int n = std::snprintf(header, sizeof(header),
        "\n===== FATAL SIGNAL =====\nsignal=%d pid=%ld tid=%ld\n",
        signalNumber, static_cast<long>(::getpid()), tid);
    if (n > 0 && s.crashFd >= 0) {
        ::write(s.crashFd, header, static_cast<size_t>(n));
    }
    if (n > 0) {
        ::write(STDERR_FILENO, header, static_cast<size_t>(n));
    }

#ifdef __linux__
    void *frames[64];
    const int frameCount = ::backtrace(frames, 64);
    rawWrite(s.crashFd, "backtrace:\n");
    if (s.crashFd >= 0) ::backtrace_symbols_fd(frames, frameCount, s.crashFd);
    rawWrite(STDERR_FILENO, "backtrace:\n");
    ::backtrace_symbols_fd(frames, frameCount, STDERR_FILENO);
#endif

    if (s.crashFd >= 0) ::fsync(s.crashFd);
    std::signal(signalNumber, SIG_DFL);
    std::raise(signalNumber);
    _exit(128 + signalNumber);
}
#endif

void terminateHandler() {
    QString reason = "std::terminate called";
    if (std::exception_ptr exception = std::current_exception()) {
        try {
            std::rethrow_exception(exception);
        } catch (const std::exception &e) {
            reason += QStringLiteral(": ") + QString::fromUtf8(e.what());
        } catch (...) {
            reason += QStringLiteral(": unknown exception");
        }
    }
    AppLogger::fatal("crash", "std_terminate", reason);
    AppLogger::flush();
    std::abort();
}
} // namespace

void AppLogger::initialize() {
    LoggerState &s = state();
    QMutexLocker locker(&s.mutex);
    if (s.initialized) return;

    s.logsDir = LauncherPaths::logsDir();
    QDir().mkpath(s.logsDir);
    pruneOldLogs(s.logsDir);

    const QString stamp = QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss-zzz");
    const qint64 pid = QCoreApplication::applicationPid();
    s.sessionId = stamp + "-pid" + QString::number(pid) + "-" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    s.latestPath = s.logsDir + "/latest.log";
    s.sessionPath = s.logsDir + "/session-" + s.sessionId + ".log";
    s.crashPath = s.logsDir + "/crash-last.log";
    s.statePath = s.logsDir + "/last-run-state.json";

    const QJsonObject previousState = readStateFile(s.statePath);

    s.latest = std::make_unique<QFile>(s.latestPath);
    s.session = std::make_unique<QFile>(s.sessionPath);
    s.latest->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text);
    s.session->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text);

#ifdef Q_OS_UNIX
    const QByteArray crashPathBytes = QFile::encodeName(s.crashPath);
    s.crashFd = ::open(crashPathBytes.constData(), O_CREAT | O_WRONLY | O_TRUNC, 0644);
#endif

    s.elapsed.start();
    s.initialized = true;

    const QJsonObject runningState{
        {"status", "running"},
        {"sessionId", s.sessionId},
        {"pid", static_cast<double>(pid)},
        {"startedAt", QDateTime::currentDateTime().toString(Qt::ISODateWithMs)},
        {"sessionLog", s.sessionPath},
        {"latestLog", s.latestPath},
        {"crashLog", s.crashPath}
    };
    writeStateFile(s.statePath, runningState);

    locker.unlock();

    if (previousState.value("status").toString() == "running") {
        warning("lifecycle", "previous_session_unclean",
                "上一次会话没有记录到正常退出，可能发生崩溃、强制结束或系统断电。",
                previousState);
    }

    info("lifecycle", "logger_initialized", "日志系统初始化完成", {
        {"sessionId", s.sessionId},
        {"latestLog", s.latestPath},
        {"sessionLog", s.sessionPath},
        {"crashLog", s.crashPath}
    });

    info("environment", "process", "进程环境", {
        {"pid", static_cast<double>(pid)},
        {"application", QCoreApplication::applicationName()},
        {"version", QCoreApplication::applicationVersion()},
        {"qtVersion", QString::fromLatin1(qVersion())},
        {"os", QSysInfo::prettyProductName()},
        {"kernelType", QSysInfo::kernelType()},
        {"kernelVersion", QSysInfo::kernelVersion()},
        {"cpuArchitecture", QSysInfo::currentCpuArchitecture()},
        {"buildAbi", QSysInfo::buildAbi()},
        {"workingDirectory", QDir::currentPath()},
        {"arguments", QJsonArray::fromStringList(QCoreApplication::arguments())}
    });
}

void AppLogger::installQtMessageHandler() {
    qInstallMessageHandler(qtMessageHandler);
    info("lifecycle", "qt_message_handler_installed");
}

void AppLogger::installCrashHandlers() {
    std::set_terminate(terminateHandler);
#ifdef __linux__
    // 预热 libgcc 的回溯路径，降低首次在信号处理器内调用 backtrace() 时分配内存的概率。
    void *warmupFrames[1];
    Q_UNUSED(::backtrace(warmupFrames, 1));
#endif
#ifdef Q_OS_UNIX
    const int fatalSignals[] = {SIGSEGV, SIGABRT, SIGBUS, SIGFPE, SIGILL};
    for (const int signalNumber : fatalSignals) {
        std::signal(signalNumber, crashSignalHandler);
    }
#endif
    info("lifecycle", "crash_handlers_installed");
}

void AppLogger::markCleanShutdown(int exitCode) {
    LoggerState &s = state();
    {
        QMutexLocker locker(&s.mutex);
        if (!s.initialized || s.cleanShutdownWritten) return;
        s.cleanShutdownWritten = true;
    }

    info("lifecycle", "clean_shutdown", "应用正常退出", {{"exitCode", exitCode}});
    flush();

    const QJsonObject cleanState{
        {"status", "clean"},
        {"sessionId", s.sessionId},
        {"pid", static_cast<double>(QCoreApplication::applicationPid())},
        {"endedAt", QDateTime::currentDateTime().toString(Qt::ISODateWithMs)},
        {"exitCode", exitCode},
        {"sessionLog", s.sessionPath},
        {"latestLog", s.latestPath},
        {"crashLog", s.crashPath}
    };
    writeStateFile(s.statePath, cleanState);
}

void AppLogger::flush() {
    LoggerState &s = state();
    QMutexLocker locker(&s.mutex);
    if (s.latest) s.latest->flush();
    if (s.session) s.session->flush();
#ifdef Q_OS_UNIX
    if (s.crashFd >= 0) ::fsync(s.crashFd);
#endif
}

QString AppLogger::logsDir() { return state().logsDir; }
QString AppLogger::latestLogFile() { return state().latestPath; }
QString AppLogger::sessionLogFile() { return state().sessionPath; }
QString AppLogger::crashLogFile() { return state().crashPath; }
QString AppLogger::sessionId() { return state().sessionId; }

void AppLogger::debug(const QString &category, const QString &event,
                      const QString &message, const QJsonObject &details) {
    write("DEBUG", category, event, message, details);
}

void AppLogger::info(const QString &category, const QString &event,
                     const QString &message, const QJsonObject &details) {
    write("INFO", category, event, message, details);
}

void AppLogger::warning(const QString &category, const QString &event,
                        const QString &message, const QJsonObject &details) {
    write("WARN", category, event, message, details);
}

void AppLogger::error(const QString &category, const QString &event,
                      const QString &message, const QJsonObject &details) {
    write("ERROR", category, event, message, details);
}

void AppLogger::fatal(const QString &category, const QString &event,
                      const QString &message, const QJsonObject &details) {
    write("FATAL", category, event, message, details);
}

QJsonObject AppLogger::redactObject(const QJsonObject &value) {
    QJsonObject out;
    const QString semanticKey = value.value("key").toString();
    const bool pairedValueIsSensitive = !semanticKey.isEmpty() && sensitiveKey(semanticKey);
    for (auto it = value.begin(); it != value.end(); ++it) {
        const QString lower = it.key().toLower();
        if (pairedValueIsSensitive && (lower == "value" || lower == "newvalue" || lower == "oldvalue")) {
            out.insert(it.key(), QStringLiteral("<redacted>"));
        } else {
            out.insert(it.key(), redactValue(it.key(), it.value()));
        }
    }
    return out;
}

QString AppLogger::redactText(const QString &value) {
    QString out = value;
    const QList<QRegularExpression> patterns = {
        QRegularExpression(R"redact((?i)(["']?(?:password|passwd|access_token|refresh_token|client_secret|authorization|token|secret|api_key)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;&}]+))redact"),
        QRegularExpression(R"((?i)(Bearer\s+)[A-Za-z0-9._~+/=-]+)"),
        QRegularExpression(R"((?i)(--(?:accessToken|clientToken|password)\s+)[^\s]+)"),
        QRegularExpression(R"((?i)([?&](?:code|token|access_token|refresh_token|password|client_secret)=)[^&\s]+)")
    };
    for (const QRegularExpression &pattern : patterns) {
        out.replace(pattern, QStringLiteral("\\1<redacted>"));
    }
    if (out.size() > 4000) {
        out = out.left(4000) + QStringLiteral("…<truncated>");
    }
    return out;
}

QString AppLogger::summarizeJson(const QString &raw) {
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError) {
        return redactText(raw.left(500));
    }

    if (doc.isArray()) {
        return QStringLiteral("json-array(size=%1)").arg(doc.array().size());
    }

    const QJsonObject object = doc.object();
    QJsonObject summary;
    const QStringList scalarKeys = {
        "id", "active", "success", "status", "percent", "title", "message",
        "count", "selectedInstance", "gameStarted", "shouldHide", "shouldClose",
        "shouldReopen", "visibility", "pid", "error", "source", "version"
    };
    for (const QString &key : scalarKeys) {
        if (object.contains(key) && !object.value(key).isObject() && !object.value(key).isArray()) {
            summary.insert(key, object.value(key));
        }
    }
    for (auto it = object.begin(); it != object.end(); ++it) {
        if (it.value().isArray()) summary.insert(it.key() + "Count", it.value().toArray().size());
    }
    if (summary.isEmpty()) summary.insert("keys", QJsonArray::fromStringList(object.keys()));
    return compactJson(redactObject(summary));
}

void AppLogger::write(const char *level, const QString &category,
                      const QString &event, const QString &message,
                      const QJsonObject &details) {
    LoggerState &s = state();
    if (!s.initialized) {
        const QByteArray fallback = QString("[%1] [%2] %3 %4\n")
            .arg(QString::fromLatin1(level), category, event, normalizedMessage(message))
            .toUtf8();
        std::fwrite(fallback.constData(), 1, static_cast<size_t>(fallback.size()), stderr);
        std::fflush(stderr);
        return;
    }

    QJsonObject safeDetails = redactObject(details);
    safeDetails.insert("elapsedMs", static_cast<double>(s.elapsed.elapsed()));

    const QString line = QString("%1 [%2] [pid=%3 tid=%4] [%5] %6")
        .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs),
             QString::fromLatin1(level),
             QString::number(QCoreApplication::applicationPid()),
             threadIdString(), category,
             event.isEmpty() ? QStringLiteral("event") : event)
        + (message.isEmpty() ? QString() : QStringLiteral(" | ") + normalizedMessage(redactText(message)))
        + (safeDetails.isEmpty() ? QString() : QStringLiteral(" | ") + compactJson(safeDetails))
        + QLatin1Char('\n');

    const QByteArray bytes = line.toUtf8();
    {
        QMutexLocker locker(&s.mutex);
        if (s.latest && s.latest->isOpen()) {
            s.latest->write(bytes);
            s.latest->flush();
        }
        if (s.session && s.session->isOpen()) {
            s.session->write(bytes);
            s.session->flush();
        }
    }

    if (shouldEchoToConsole(level, category, event)) {
        std::fwrite(bytes.constData(), 1, static_cast<size_t>(bytes.size()), stderr);
        std::fflush(stderr);
    }
}

AppLogScope::AppLogScope(QString category, QString operation,
                         QJsonObject details)
    : m_category(std::move(category)),
      m_operation(std::move(operation)),
      m_details(std::move(details)),
      m_uncaughtExceptions(std::uncaught_exceptions()) {
    m_timer.start();
    AppLogger::info(m_category, m_operation + ".begin", QString(), m_details);
}

AppLogScope::~AppLogScope() {
    QJsonObject details = m_details;
    details.insert("durationMs", static_cast<double>(m_timer.elapsed()));
    const bool exceptionEscaping = std::uncaught_exceptions() > m_uncaughtExceptions;
    details.insert("exceptionEscaping", exceptionEscaping);
    if (exceptionEscaping) {
        AppLogger::error(m_category, m_operation + ".end", "调用因异常退出", details);
    } else {
        AppLogger::info(m_category, m_operation + ".end", QString(), details);
    }
}
