#pragma once

#include <QHash>
#include <QList>
#include <QObject>
#include <QString>
#include <QUrl>

#include <atomic>

class QNetworkAccessManager;
class QNetworkReply;
class QEventLoop;
class QFile;

// One file to fetch. sha1 empty means "no integrity check". Candidate URLs are
// tried in order (first is primary, rest are mirrors) — HMCL tries multiple
// download providers per file; this slice only fills in the Mojang URL but the
// list shape lets mirrors drop in later without touching call sites.
struct DownloadItem {
    QList<QUrl> urls;
    QString destPath;
    QString sha1;
    qint64 size = 0;
};

// Concurrent multi-file downloader, ported in spirit from HMCL's
// FileDownloadTask + task scheduler. Runs up to `concurrency` simultaneous
// replies from a queue, writes to a `.part` temp then renames on success, and
// verifies SHA-1 with a small retry budget. Blocking run()/downloadSync() drive
// an internal event loop, so they are meant to be called from a worker thread
// that owns this object. cancel() is thread-safe.
class Downloader : public QObject {
    Q_OBJECT
public:
    explicit Downloader(QObject *parent = nullptr);
    ~Downloader() override;

    void setConcurrency(int n) { m_concurrency = n > 0 ? n : 1; }

    // Downloads every item; returns true only if all succeeded. Files already
    // present with a matching SHA-1 are skipped (idempotent re-install).
    bool run(const QList<DownloadItem> &items);

    // Blocking single-file fetch for the sequential head of the pipeline
    // (manifest, version JSON, asset index). Returns true on success.
    bool downloadSync(const QList<QUrl> &urls, const QString &destPath,
                      const QString &sha1 = QString());

    // Callable from any thread; aborts in-flight replies and stops dispatch.
    void cancel();

    Q_INVOKABLE void abortAll();

signals:
    void progress(int finishedFiles, int totalFiles, qint64 downloadedBytes,
                  const QString &currentFile);

private:
    struct Active {
        DownloadItem item;
        QFile *file = nullptr;
        int retriesLeft = 0;
        int urlIndex = 0;
    };

    void dispatchNext();
    void startItem(const DownloadItem &item, int retriesLeft, int urlIndex);
    void onReplyFinished(QNetworkReply *reply);
    void finishOne();
    void maybeQuit();

    QNetworkAccessManager *m_manager = nullptr;
    QEventLoop *m_loop = nullptr;
    QList<DownloadItem> m_queue;
    QHash<QNetworkReply *, Active> m_active;

    int m_concurrency = 6;
    int m_totalFiles = 0;
    int m_finishedFiles = 0;
    qint64 m_downloadedBytes = 0;

    std::atomic_bool m_cancelled{false};
    bool m_failed = false;
    QString m_error;
};
