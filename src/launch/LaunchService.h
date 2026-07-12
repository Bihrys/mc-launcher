#pragma once

#include "launch/DefaultLauncher.h"
#include "launch/LaunchOptions.h"
#include "launch/ProcessListener.h"

#include <QElapsedTimer>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QObject>

#include <memory>

class QNetworkReply;

class LaunchService final : public QObject, private ProcessListener {
    Q_OBJECT
public:
    explicit LaunchService(QObject *parent = nullptr);

    QJsonObject idle() const;
    QJsonObject status() const { return m_status; }
    void start(const LaunchOptions &options, const QString &visibility);
    void cancel();

signals:
    void statusChanged(const QJsonObject &status);

private:
    void publish();
    void setStageStatus(const QString &id, const QString &status,
                        const QString &message = QString());
    void setTask(const QString &stageId, const QString &name,
                 const QString &message = QString(), int percent = -1);
    void clearTasks();
    void fail(const QString &title, const QString &message);
    void startAuthenticationStage();
    void downloadAuthlibInjector(int candidateIndex = 0);
    void startProcess();
    QString gameLogTail() const;

    // ProcessListener
    void onProcessStarted(qint64 pid) override;
    void onProcessLog(const QByteArray &data, bool standardError) override;
    void onProcessReady() override;
    void onProcessExited(int exitCode, bool crashed, bool exitedBeforeReady) override;
    void onProcessError(const QString &message) override;

    QJsonObject m_status;
    LaunchOptions m_options;
    QString m_visibility = QStringLiteral("hide");
    std::unique_ptr<DefaultLauncher> m_launcher;

    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_authlibReply;
    QElapsedTimer m_authlibTimer;
    qint64 m_authlibLastBytes = 0;
    qint64 m_authlibLastMs = 0;
    bool m_processReady = false;
    bool m_terminal = false;
};
