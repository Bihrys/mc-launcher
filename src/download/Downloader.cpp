#include "download/Downloader.h"

#include <QCryptographicHash>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>

namespace {

const int kRetriesPerFile = 2;

bool fileMatchesSha1(const QString &path, const QString &sha1) {
    if (sha1.isEmpty()) return false;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return false;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    if (!hash.addData(&f)) return false;
    return hash.result().toHex() == sha1.toLatin1().toLower();
}

} // namespace

Downloader::Downloader(QObject *parent) : QObject(parent) {
    m_manager = new QNetworkAccessManager(this);
}

Downloader::~Downloader() = default;

void Downloader::cancel() {
    m_cancelled.store(true);
    // Marshal the abort onto this object's thread (the worker thread that owns
    // the replies). Direct abort from the GUI thread would touch QNetworkReply
    // objects living in another thread.
    QMetaObject::invokeMethod(this, "abortAll", Qt::QueuedConnection);
}

void Downloader::abortAll() {
    for (auto it = m_active.begin(); it != m_active.end(); ++it) {
        it.key()->abort();
    }
    m_queue.clear();
    maybeQuit();
}

bool Downloader::downloadSync(const QList<QUrl> &urls, const QString &destPath,
                              const QString &sha1) {
    DownloadItem item;
    item.urls = urls;
    item.destPath = destPath;
    item.sha1 = sha1;
    return run({item});
}

bool Downloader::run(const QList<DownloadItem> &items) {
    if (m_cancelled.load()) return false;

    m_queue = items;
    m_totalFiles = items.size();
    m_finishedFiles = 0;
    m_downloadedBytes = 0;
    m_failed = false;
    m_error.clear();

    // Pre-skip already-valid files so re-install is fast and totals are honest.
    QList<DownloadItem> pending;
    pending.reserve(m_queue.size());
    for (const DownloadItem &item : m_queue) {
        if (!item.sha1.isEmpty() && fileMatchesSha1(item.destPath, item.sha1)) {
            ++m_finishedFiles;
            m_downloadedBytes += QFileInfo(item.destPath).size();
            emit progress(m_finishedFiles, m_totalFiles, m_downloadedBytes,
                          QFileInfo(item.destPath).fileName());
        } else {
            pending.append(item);
        }
    }
    m_queue = pending;

    if (m_queue.isEmpty()) return !m_failed;

    QEventLoop loop;
    m_loop = &loop;

    for (int i = 0; i < m_concurrency; ++i) dispatchNext();

    loop.exec();
    m_loop = nullptr;

    return !m_failed && !m_cancelled.load();
}

void Downloader::dispatchNext() {
    if (m_cancelled.load()) { maybeQuit(); return; }
    if (m_queue.isEmpty()) { maybeQuit(); return; }

    const DownloadItem item = m_queue.takeFirst();
    startItem(item, kRetriesPerFile, 0);
}

void Downloader::startItem(const DownloadItem &item, int retriesLeft, int urlIndex) {
    if (m_cancelled.load()) { maybeQuit(); return; }

    if (urlIndex >= item.urls.size()) {
        m_failed = true;
        m_error = "No usable URL for " + item.destPath;
        finishOne();
        return;
    }

    QDir().mkpath(QFileInfo(item.destPath).absolutePath());
    QFile *file = new QFile(item.destPath + ".part");
    if (!file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        delete file;
        m_failed = true;
        m_error = "Cannot open " + item.destPath + ".part for writing";
        finishOne();
        return;
    }

    QNetworkRequest req(item.urls.at(urlIndex));
    req.setRawHeader("User-Agent", "mc-launcher-qt-cpp/0.1");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_manager->get(req);

    Active active;
    active.item = item;
    active.file = file;
    active.retriesLeft = retriesLeft;
    active.urlIndex = urlIndex;
    m_active.insert(reply, active);

    connect(reply, &QNetworkReply::readyRead, this, [this, reply]() {
        auto it = m_active.find(reply);
        if (it != m_active.end() && it->file && reply->isReadable()) {
            it->file->write(reply->readAll());
        }
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, reply](qint64 received, qint64 total) {
        auto it = m_active.find(reply);
        if (it == m_active.end()) return;
        it->receivedBytes = qMax<qint64>(0, received);
        it->expectedBytes = total;
        qint64 visibleBytes = m_downloadedBytes;
        for (auto activeIt = m_active.begin(); activeIt != m_active.end(); ++activeIt) {
            visibleBytes += qMax<qint64>(0, activeIt->receivedBytes);
        }
        emit progress(m_finishedFiles, m_totalFiles, visibleBytes, QFileInfo(it->item.destPath).fileName());
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onReplyFinished(reply);
    });

    emit progress(m_finishedFiles, m_totalFiles, m_downloadedBytes, QFileInfo(item.destPath).fileName());
}

void Downloader::onReplyFinished(QNetworkReply *reply) {
    auto it = m_active.find(reply);
    if (it == m_active.end()) { reply->deleteLater(); return; }

    Active active = it.value();
    m_active.erase(it);

    if (active.file) {
        if (reply->isReadable()) active.file->write(reply->readAll());
        active.file->close();
    }

    const QString partPath = active.item.destPath + ".part";
    const bool netOk = reply->error() == QNetworkReply::NoError;
    reply->deleteLater();

    if (m_cancelled.load()) {
        if (active.file) { delete active.file; }
        QFile::remove(partPath);
        maybeQuit();
        return;
    }

    bool ok = netOk;
    if (ok && !active.item.sha1.isEmpty()) ok = fileMatchesSha1(partPath, active.item.sha1);

    if (ok) {
        QFile::remove(active.item.destPath);
        if (!QFile::rename(partPath, active.item.destPath)) {
            m_failed = true;
            m_error = "Cannot finalize " + active.item.destPath;
        } else {
            m_downloadedBytes += QFileInfo(active.item.destPath).size();
        }
        if (active.file) delete active.file;
        finishOne();
        return;
    }

    // Failure: clean up the temp, then retry (same URL budget) or fall to the
    // next candidate URL before giving up.
    if (active.file) delete active.file;
    QFile::remove(partPath);

    if (active.retriesLeft > 0) {
        startItem(active.item, active.retriesLeft - 1, active.urlIndex);
    } else if (active.urlIndex + 1 < active.item.urls.size()) {
        startItem(active.item, kRetriesPerFile, active.urlIndex + 1);
    } else {
        m_failed = true;
        if (m_error.isEmpty())
            m_error = "Failed to download " + active.item.destPath;
        finishOne();
    }
}

void Downloader::finishOne() {
    ++m_finishedFiles;
    emit progress(m_finishedFiles, m_totalFiles, m_downloadedBytes,
                  QString());
    if (m_failed) {
        // Stop scheduling new work; let in-flight replies drain via maybeQuit.
        m_queue.clear();
        maybeQuit();
        return;
    }
    dispatchNext();
}

void Downloader::maybeQuit() {
    if (m_active.isEmpty() && (m_queue.isEmpty() || m_cancelled.load() || m_failed)) {
        if (m_loop) m_loop->quit();
    }
}
