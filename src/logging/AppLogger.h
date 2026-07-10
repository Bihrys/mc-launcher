#pragma once

#include <QElapsedTimer>
#include <QJsonObject>
#include <QMutex>
#include <QString>

#include <exception>

class QFile;

class AppLogger {
public:
    static void initialize();
    static void installQtMessageHandler();
    static void installCrashHandlers();
    static void markCleanShutdown(int exitCode);
    static void flush();

    static QString logsDir();
    static QString latestLogFile();
    static QString sessionLogFile();
    static QString crashLogFile();
    static QString sessionId();

    static void debug(const QString &category, const QString &event,
                      const QString &message = QString(),
                      const QJsonObject &details = {});
    static void info(const QString &category, const QString &event,
                     const QString &message = QString(),
                     const QJsonObject &details = {});
    static void warning(const QString &category, const QString &event,
                        const QString &message = QString(),
                        const QJsonObject &details = {});
    static void error(const QString &category, const QString &event,
                      const QString &message = QString(),
                      const QJsonObject &details = {});
    static void fatal(const QString &category, const QString &event,
                      const QString &message = QString(),
                      const QJsonObject &details = {});

    static QJsonObject redactObject(const QJsonObject &value);
    static QString redactText(const QString &value);
    static QString summarizeJson(const QString &raw);

private:
    static void write(const char *level, const QString &category,
                      const QString &event, const QString &message,
                      const QJsonObject &details);
};

class AppLogScope {
public:
    AppLogScope(QString category, QString operation,
                QJsonObject details = {});
    ~AppLogScope();

    AppLogScope(const AppLogScope &) = delete;
    AppLogScope &operator=(const AppLogScope &) = delete;

private:
    QString m_category;
    QString m_operation;
    QJsonObject m_details;
    QElapsedTimer m_timer;
    int m_uncaughtExceptions = 0;
};
