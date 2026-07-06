#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QMutex>
#include <QObject>
#include <QString>

#include <atomic>

class QThread;
class Downloader;

struct TaskStage {
    QString id;
    QString title;
    enum Status { Waiting, Running, Success, Failed };
    Status status = Waiting;
    int count = 0;
    int total = 0;

    QJsonObject toJson() const {
        return QJsonObject{
            {"id", id},
            {"title", title},
            {"status", status == Waiting ? "waiting"
                       : status == Running ? "running"
                       : status == Success ? "success" : "failed"},
            {"count", count},
            {"total", total}
        };
    }
};

// Orchestrates the vanilla Minecraft install pipeline, ported from HMCL's
// GameInstallTask chain (VersionJsonDownloadTask -> GameDownloadTask +
// GameAssetDownloadTask + GameLibrariesTask). Runs the whole flow on a worker
// thread and exposes a mutex-guarded status object shaped exactly like the JSON
// the QML download dialog polls every 250ms.
//
// Status field contract (read by qml/features/download/HmclDownloadPage.qml):
//   active, cancelled, percent, title, message, totalFiles, finishedFiles,
//   totalBytes, downloadedBytes, currentFile, speed, status
// status transitions: preparing -> downloading -> finished | failed | cancelled
class GameInstaller : public QObject {
    Q_OBJECT
public:
    explicit GameInstaller(QObject *parent = nullptr);
    ~GameInstaller() override;

    // Fire-and-forget. Kicks off a worker thread and returns immediately; the
    // caller polls task() until status is a terminal value.
    void start(const QString &source, const QString &gameVersion,
               const QString &loaderKind, const QString &loaderVersion);

    // Thread-safe snapshot of the current status object.
    QJsonObject task() const;

    // Thread-safe cancel; the worker notices between/within phases and unwinds.
    void cancel();

    bool isRunning() const { return m_running.load(); }

private:
    void runPipeline(const QString &source, const QString &gameVersion,
                     const QString &loaderKind, const QString &loaderVersion);

    void setTask(const QJsonObject &task);
    void mergeTask(const QJsonObject &patch);
    QJsonObject buildTask(const QString &status, const QString &title,
                          const QString &message, int percent) const;

    void beginStage(const QString &id, const QString &title);
    void updateStageCount(const QString &id, int count, int total);
    void succeedStage(const QString &id);
    void failStage(const QString &id);
    QJsonArray stagesJson() const;

    mutable QMutex m_mutex;
    QJsonObject m_task;
    QList<TaskStage> m_stages;

    QThread *m_thread = nullptr;
    Downloader *m_downloader = nullptr;

    std::atomic_bool m_cancelled{false};
    std::atomic_bool m_running{false};
};
