#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>

#include <atomic>


class FpsMonitor : public QObject {
    Q_OBJECT
    Q_PROPERTY(QQuickWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int fps READ fps NOTIFY fpsChanged)
    Q_PROPERTY(qreal frameTimeMs READ frameTimeMs NOTIFY frameTimeMsChanged)

public:
    explicit FpsMonitor(QObject *parent = nullptr);

    QQuickWindow *window() const;
    void setWindow(QQuickWindow *window);

    bool enabled() const;
    void setEnabled(bool enabled);

    int fps() const;
    qreal frameTimeMs() const;

signals:
    void windowChanged();
    void enabledChanged();
    void fpsChanged();
    void frameTimeMsChanged();

private slots:
    void publishSample();

private:
    void attachWindow();
    void detachWindow();
    void resetSample();
    void setPublishedFps(int fps);

    QPointer<QQuickWindow> m_window;
    QMetaObject::Connection m_frameConnection;
    QMetaObject::Connection m_updateConnection;
    QMetaObject::Connection m_destroyConnection;
    QTimer m_sampleTimer;
    QElapsedTimer m_sampleClock;
    std::atomic_int m_pendingFrames{0};
    bool m_enabled = true;
    int m_fps = 0;
    qreal m_frameTimeMs = 0.0;
};
