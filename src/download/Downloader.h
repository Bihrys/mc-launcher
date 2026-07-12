#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QString>
#include <QUrl>

#include <atomic>
#include <memory>

class QNetworkAccessManager;
class QNetworkReply;
class QEventLoop;
class QFile;

struct DownloadItem {
    QList<QUrl> urls;
    QString destPath;
    QString sha1;
    qint64 size = 0;
    QString displayName;
    QString stageId;
};

// Reusable HMCL-style multi-file downloader. Every consumer (Minecraft, Java,
// loaders and future add-ons) receives the same aggregate and per-file task
// stream, so UI code never needs a bespoke download popup.
class Downloader : public QObject {
    Q_OBJECT
public:
    explicit Downloader(QObject *parent = nullptr);
    ~Downloader() override;

    void setConcurrency(int n) { m_concurrency = n > 0 ? n : 1; }
    void setCancellationFlag(std::shared_ptr<std::atomic_bool> flag) {
        m_externalCancellation = std::move(flag);
    }

    bool run(const QList<DownloadItem> &items);
    bool downloadSync(const QList<QUrl> &urls, const QString &destPath,
                      const QString &sha1 = QString(),
                      const QString &displayName = QString());

    void cancel();
    Q_INVOKABLE void abortAll();

signals:
    void progress(int finishedFiles, int totalFiles, qint64 downloadedBytes,
                  const QString &currentFile, qint64 bytesPerSecond,
                  const QJsonArray &files, const QJsonObject &stageProgress);

private:
    struct Active {
        DownloadItem item;
        QFile *file = nullptr;
        int retriesLeft = 0;
        int urlIndex = 0;
        qint64 receivedBytes = 0;
        qint64 expectedBytes = 0;
    };

    void dispatchNext();
    void startItem(const DownloadItem &item, int retriesLeft, int urlIndex);
    void onReplyFinished(QNetworkReply *reply);
    void finishOne();
    void maybeQuit();
    qint64 visibleDownloadedBytes() const;
    qint64 updateRollingSpeed(qint64 visibleBytes);
    QJsonArray filesSnapshot() const;
    QJsonObject stageProgressSnapshot() const;
    void appendRecentFile(const DownloadItem &item, const QString &status,
                          qint64 bytes, qint64 total);
    QString itemName(const DownloadItem &item) const;
    void emitProgress(const QString &currentFile = QString());

    QNetworkAccessManager *m_manager = nullptr;
    QEventLoop *m_loop = nullptr;
    QList<DownloadItem> m_queue;
    QHash<QNetworkReply *, Active> m_active;

    int m_concurrency = 6;
    int m_totalFiles = 0;
    int m_finishedFiles = 0;
    qint64 m_downloadedBytes = 0;

    QElapsedTimer m_speedTimer;
    qint64 m_lastSpeedSampleMs = 0;
    qint64 m_lastSpeedBytes = 0;
    qint64 m_lastProgressEmitMs = -1000;
    qint64 m_smoothedSpeed = 0;
    QJsonArray m_recentFiles;
    QHash<QString, int> m_stageTotals;
    QHash<QString, int> m_stageFinished;

    std::shared_ptr<std::atomic_bool> m_externalCancellation;
    std::atomic_bool m_cancelled{false};
    bool m_failed = false;
    QString m_error;
};
