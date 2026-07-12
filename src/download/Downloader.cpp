#include "download/Downloader.h"

#include "logging/AppLogger.h"

#include <QCryptographicHash>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>

#include <utility>

namespace {

constexpr int kRetriesPerFile = 2;
constexpr int kRecentFileLimit = 4;

bool fileMatchesSha1(const QString &path, const QString &sha1) {
    if (sha1.isEmpty()) return false;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return false;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    if (!hash.addData(&file)) return false;
    return hash.result().toHex() == sha1.toLatin1().toLower();
}

} // namespace

Downloader::Downloader(QObject *parent) : QObject(parent) {
    m_manager = new QNetworkAccessManager(this);
}

Downloader::~Downloader() = default;

QString Downloader::itemName(const DownloadItem &item) const {
    return item.displayName.isEmpty() ? QFileInfo(item.destPath).fileName()
                                      : item.displayName;
}

void Downloader::cancel() {
    m_cancelled.store(true);
    if (m_externalCancellation) m_externalCancellation->store(true);
    QMetaObject::invokeMethod(this, "abortAll", Qt::QueuedConnection);
}

void Downloader::abortAll() {
    for (auto it = m_active.begin(); it != m_active.end(); ++it) {
        QNetworkReply *reply = it.key();
        if (reply && !reply->isFinished() && reply->isOpen())
            reply->abort();
    }
    m_queue.clear();
    maybeQuit();
}

bool Downloader::downloadSync(const QList<QUrl> &urls, const QString &destPath,
                              const QString &sha1, const QString &displayName) {
    DownloadItem item;
    item.urls = urls;
    item.destPath = destPath;
    item.sha1 = sha1;
    item.displayName = displayName;
    return run({item});
}

bool Downloader::run(const QList<DownloadItem> &items) {
    if (m_cancelled.load() || (m_externalCancellation && m_externalCancellation->load()))
        return false;

    AppLogger::info("download.files", "batch_started", QString(), {
        {"files", static_cast<double>(items.size())}, {"concurrency", m_concurrency}
    });

    m_queue = items;
    m_totalFiles = items.size();
    m_finishedFiles = 0;
    m_downloadedBytes = 0;
    m_failed = false;
    m_error.clear();
    m_recentFiles = QJsonArray{};
    m_stageTotals.clear();
    m_stageFinished.clear();
    for (const DownloadItem &item : items) {
        if (!item.stageId.isEmpty())
            m_stageTotals[item.stageId] = m_stageTotals.value(item.stageId) + 1;
    }
    m_speedTimer.restart();
    m_lastSpeedSampleMs = 0;
    m_lastSpeedBytes = 0;
    m_lastProgressEmitMs = -1000;
    m_smoothedSpeed = 0;

    QList<DownloadItem> pending;
    pending.reserve(m_queue.size());
    for (const DownloadItem &item : std::as_const(m_queue)) {
        if (!item.sha1.isEmpty() && fileMatchesSha1(item.destPath, item.sha1)) {
            ++m_finishedFiles;
            const qint64 size = QFileInfo(item.destPath).size();
            m_downloadedBytes += size;
            appendRecentFile(item, QStringLiteral("cached"), size,
                             item.size > 0 ? item.size : size);
            if (!item.stageId.isEmpty())
                m_stageFinished[item.stageId] = m_stageFinished.value(item.stageId) + 1;
            emitProgress(itemName(item));
        } else {
            pending.append(item);
        }
    }
    m_queue = pending;
    emitProgress();

    if (m_queue.isEmpty()) {
        AppLogger::info("download.files", "batch_finished_from_cache", QString(), {
            {"files", m_totalFiles}, {"bytes", static_cast<double>(m_downloadedBytes)}
        });
        return !m_failed;
    }

    QEventLoop loop;
    m_loop = &loop;

    QTimer cancellationTimer;
    cancellationTimer.setInterval(100);
    connect(&cancellationTimer, &QTimer::timeout, this, [this]() {
        if (m_externalCancellation && m_externalCancellation->load()) {
            m_cancelled.store(true);
            abortAll();
        }
    });
    cancellationTimer.start();

    for (int i = 0; i < m_concurrency; ++i) dispatchNext();
    loop.exec();

    cancellationTimer.stop();
    m_loop = nullptr;

    const bool succeeded = !m_failed && !m_cancelled.load()
        && !(m_externalCancellation && m_externalCancellation->load());
    AppLogger::info("download.files", "batch_finished", m_error, {
        {"succeeded", succeeded}, {"cancelled", !succeeded && !m_failed},
        {"finishedFiles", m_finishedFiles}, {"totalFiles", m_totalFiles},
        {"bytes", static_cast<double>(m_downloadedBytes)}
    });
    return succeeded;
}

void Downloader::dispatchNext() {
    if (m_cancelled.load() || (m_externalCancellation && m_externalCancellation->load())) {
        maybeQuit();
        return;
    }
    if (m_queue.isEmpty()) {
        maybeQuit();
        return;
    }
    startItem(m_queue.takeFirst(), kRetriesPerFile, 0);
}

void Downloader::startItem(const DownloadItem &item, int retriesLeft, int urlIndex) {
    if (m_cancelled.load() || (m_externalCancellation && m_externalCancellation->load())) {
        maybeQuit();
        return;
    }

    if (urlIndex >= item.urls.size()) {
        m_failed = true;
        m_error = "No usable URL for " + item.destPath;
        appendRecentFile(item, QStringLiteral("failed"), 0, item.size);
        finishOne();
        return;
    }

    QDir().mkpath(QFileInfo(item.destPath).absolutePath());
    QFile *file = new QFile(item.destPath + ".part");
    if (!file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        delete file;
        m_failed = true;
        m_error = "Cannot open " + item.destPath + ".part for writing";
        appendRecentFile(item, QStringLiteral("failed"), 0, item.size);
        finishOne();
        return;
    }

    QNetworkRequest request(item.urls.at(urlIndex));
    request.setRawHeader("User-Agent", "mc-launcher-qt-cpp/0.1 HMCL-transfer");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, true);
    request.setTransferTimeout(30000);
    QNetworkReply *reply = m_manager->get(request);

    Active active;
    active.item = item;
    active.file = file;
    active.retriesLeft = retriesLeft;
    active.urlIndex = urlIndex;
    active.expectedBytes = item.size;
    m_active.insert(reply, active);

    connect(reply, &QNetworkReply::readyRead, this, [this, reply]() {
        auto it = m_active.find(reply);
        if (it != m_active.end() && it->file && it->file->isOpen()
                && reply->isOpen() && reply->isReadable())
            it->file->write(reply->readAll());
    });
    connect(reply, &QNetworkReply::downloadProgress, this,
            [this, reply](qint64 received, qint64 total) {
        auto it = m_active.find(reply);
        if (it == m_active.end()) return;
        it->receivedBytes = qMax<qint64>(0, received);
        if (total > 0) it->expectedBytes = total;
        emitProgress(itemName(it->item));
    });
    connect(reply, &QNetworkReply::finished, this,
            [this, reply]() { onReplyFinished(reply); });

    emitProgress(itemName(item));
}

qint64 Downloader::visibleDownloadedBytes() const {
    qint64 visible = m_downloadedBytes;
    for (auto it = m_active.cbegin(); it != m_active.cend(); ++it)
        visible += qMax<qint64>(0, it->receivedBytes);
    return visible;
}

qint64 Downloader::updateRollingSpeed(qint64 visibleBytes) {
    const qint64 now = m_speedTimer.elapsed();
    const qint64 deltaMs = now - m_lastSpeedSampleMs;
    if (deltaMs < 250) return m_smoothedSpeed;

    const qint64 deltaBytes = qMax<qint64>(0, visibleBytes - m_lastSpeedBytes);
    const qint64 instantaneous = deltaMs > 0 ? deltaBytes * 1000 / deltaMs : 0;
    m_smoothedSpeed = m_smoothedSpeed <= 0
        ? instantaneous
        : static_cast<qint64>(m_smoothedSpeed * 0.65 + instantaneous * 0.35);
    m_lastSpeedSampleMs = now;
    m_lastSpeedBytes = visibleBytes;
    return m_smoothedSpeed;
}

QJsonArray Downloader::filesSnapshot() const {
    QJsonArray files;
    for (auto it = m_active.cbegin(); it != m_active.cend(); ++it) {
        const Active &active = it.value();
        const qint64 total = active.expectedBytes > 0 ? active.expectedBytes
                                                      : active.item.size;
        const int percent = total > 0
            ? qBound(0, static_cast<int>(active.receivedBytes * 100 / total), 100)
            : 0;
        files.append(QJsonObject{
            {"name", itemName(active.item)},
            {"path", active.item.destPath},
            {"stageId", active.item.stageId},
            {"status", "downloading"},
            {"downloadedBytes", static_cast<double>(active.receivedBytes)},
            {"totalBytes", static_cast<double>(total)},
            {"percent", percent}
        });
    }
    for (const QJsonValue &value : m_recentFiles)
        files.append(value);
    return files;
}


QJsonObject Downloader::stageProgressSnapshot() const {
    QJsonObject out;
    for (auto it = m_stageTotals.cbegin(); it != m_stageTotals.cend(); ++it) {
        out.insert(it.key(), QJsonObject{
            {"finished", m_stageFinished.value(it.key())},
            {"total", it.value()}
        });
    }
    return out;
}

void Downloader::appendRecentFile(const DownloadItem &item, const QString &status,
                                  qint64 bytes, qint64 total) {
    // HMCL TaskListPane removes successful ProgressListNode entries as soon as
    // their task finishes. Keep only failed rows; active rows come from m_active.
    if (status != QStringLiteral("failed")) return;
    QJsonArray next;
    next.append(QJsonObject{
        {"name", itemName(item)}, {"path", item.destPath},
        {"stageId", item.stageId}, {"status", status},
        {"downloadedBytes", static_cast<double>(bytes)},
        {"totalBytes", static_cast<double>(total > 0 ? total : bytes)},
        {"percent", status == "failed" ? 0 : 100}
    });
    for (int i = 0; i < m_recentFiles.size() && next.size() < kRecentFileLimit; ++i)
        next.append(m_recentFiles.at(i));
    m_recentFiles = next;
}

void Downloader::emitProgress(const QString &currentFile) {
    const qint64 now = m_speedTimer.elapsed();
    // QNetworkReply may emit progress for every small buffer on dozens of
    // concurrent requests. Rebuilding JSON and crossing into the UI thread for
    // every buffer can itself become the long-download slowdown. Terminal
    // updates (empty currentFile) are never throttled.
    if (!currentFile.isEmpty() && now - m_lastProgressEmitMs < 100) return;
    m_lastProgressEmitMs = now;

    const qint64 visible = visibleDownloadedBytes();
    const qint64 speed = updateRollingSpeed(visible);
    emit progress(m_finishedFiles, m_totalFiles, visible, currentFile,
                  speed, filesSnapshot(), stageProgressSnapshot());
}

void Downloader::onReplyFinished(QNetworkReply *reply) {
    auto it = m_active.find(reply);
    if (it == m_active.end()) {
        reply->deleteLater();
        return;
    }

    Active active = it.value();
    m_active.erase(it);

    if (active.file) {
        if (active.file->isOpen() && reply->isOpen() && reply->isReadable())
            active.file->write(reply->readAll());
        if (active.file->isOpen()) active.file->close();
    }

    const QString partPath = active.item.destPath + ".part";
    const bool netOk = reply->error() == QNetworkReply::NoError;
    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QString networkError = reply->errorString();
    const QString safeUrl = reply->url().toString(QUrl::RemoveQuery | QUrl::RemoveFragment);
    reply->deleteLater();

    if (m_cancelled.load() || (m_externalCancellation && m_externalCancellation->load())) {
        delete active.file;
        QFile::remove(partPath);
        maybeQuit();
        return;
    }

    bool ok = netOk;
    if (ok && !active.item.sha1.isEmpty())
        ok = fileMatchesSha1(partPath, active.item.sha1);

    if (ok) {
        QFile::remove(active.item.destPath);
        if (!QFile::rename(partPath, active.item.destPath)) {
            m_failed = true;
            m_error = "Cannot finalize " + active.item.destPath;
            appendRecentFile(active.item, QStringLiteral("failed"), 0,
                             active.item.size);
        } else {
            const qint64 size = QFileInfo(active.item.destPath).size();
            m_downloadedBytes += size;
            appendRecentFile(active.item, QStringLiteral("finished"), size,
                             active.item.size > 0 ? active.item.size : size);
            if (!active.item.stageId.isEmpty())
                m_stageFinished[active.item.stageId] = m_stageFinished.value(active.item.stageId) + 1;
        }
        delete active.file;
        finishOne();
        return;
    }

    delete active.file;
    QFile::remove(partPath);

    if (active.retriesLeft > 0) {
        AppLogger::warning("download.files", "file_retry", networkError, {
            {"url", safeUrl}, {"httpStatus", httpStatus},
            {"destination", active.item.destPath},
            {"retriesRemaining", active.retriesLeft - 1},
            {"candidateIndex", active.urlIndex}
        });
        startItem(active.item, active.retriesLeft - 1, active.urlIndex);
    } else if (active.urlIndex + 1 < active.item.urls.size()) {
        AppLogger::warning("download.files", "file_fallback_provider", networkError, {
            {"url", safeUrl}, {"httpStatus", httpStatus},
            {"destination", active.item.destPath},
            {"fromCandidate", active.urlIndex},
            {"toCandidate", active.urlIndex + 1}
        });
        startItem(active.item, kRetriesPerFile, active.urlIndex + 1);
    } else {
        m_failed = true;
        if (m_error.isEmpty()) m_error = "Failed to download " + active.item.destPath;
        appendRecentFile(active.item, QStringLiteral("failed"), 0,
                         active.item.size);
        AppLogger::error("download.files", "file_failed", networkError, {
            {"url", safeUrl}, {"httpStatus", httpStatus},
            {"destination", active.item.destPath},
            {"candidateCount", static_cast<double>(active.item.urls.size())}
        });
        finishOne();
    }
}

void Downloader::finishOne() {
    ++m_finishedFiles;
    emitProgress();
    if (m_failed) {
        m_queue.clear();
        maybeQuit();
        return;
    }
    dispatchNext();
}

void Downloader::maybeQuit() {
    if (m_active.isEmpty()
            && (m_queue.isEmpty() || m_cancelled.load() || m_failed
                || (m_externalCancellation && m_externalCancellation->load()))) {
        if (m_loop) m_loop->quit();
    }
}
