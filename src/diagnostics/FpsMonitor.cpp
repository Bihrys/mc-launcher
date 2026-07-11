#include "diagnostics/FpsMonitor.h"

#include "logging/AppLogger.h"

#include <QQuickWindow>

#include <cmath>

FpsMonitor::FpsMonitor(QObject *parent)
    : QObject(parent) {
    m_sampleTimer.setInterval(500);
    m_sampleTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_sampleTimer, &QTimer::timeout,
            this, &FpsMonitor::publishSample);
    m_sampleClock.start();
    m_sampleTimer.start();
}

QQuickWindow *FpsMonitor::window() const {
    return m_window.data();
}

void FpsMonitor::setWindow(QQuickWindow *window) {
    if (m_window == window)
        return;

    detachWindow();
    m_window = window;
    attachWindow();
    resetSample();
    emit windowChanged();
}

bool FpsMonitor::enabled() const {
    return m_enabled;
}

void FpsMonitor::setEnabled(bool enabled) {
    if (m_enabled == enabled)
        return;

    m_enabled = enabled;
    if (m_enabled) {
        attachWindow();
        if (!m_sampleTimer.isActive())
            m_sampleTimer.start();
    } else {
        detachWindow();
        m_sampleTimer.stop();
        setPublishedFps(0);
    }

    resetSample();
    emit enabledChanged();
}

int FpsMonitor::fps() const {
    return m_fps;
}

qreal FpsMonitor::frameTimeMs() const {
    return m_frameTimeMs;
}

void FpsMonitor::publishSample() {
    const qint64 elapsedMs = m_sampleClock.restart();
    const int frames = m_pendingFrames.exchange(0, std::memory_order_relaxed);

    if (!m_enabled || !m_window || elapsedMs <= 0) {
        setPublishedFps(0);
        return;
    }

    const int sampledFps = qMax(0, qRound((frames * 1000.0) / elapsedMs));
    setPublishedFps(sampledFps);
}

void FpsMonitor::attachWindow() {
    if (!m_enabled || !m_window || m_frameConnection)
        return;

    // frameSwapped 对应真正提交到窗口系统的 Qt Quick 帧，不是普通 QML
    // Timer 的理论刷新频率。渲染线程只做原子计数，UI 线程每 500 ms 发布。
    m_frameConnection = connect(
        m_window.data(), &QQuickWindow::frameSwapped,
        this, [this]() {
            m_pendingFrames.fetch_add(1, std::memory_order_relaxed);
        }, Qt::DirectConnection);

    // Keep the scene graph producing frames while the overlay is enabled.
    // The request is queued back to the GUI thread and the render loop still
    // decides the actual cadence (vsync / renderer / compositor).
    m_updateConnection = connect(
        m_window.data(), &QQuickWindow::frameSwapped,
        m_window.data(), &QQuickWindow::update,
        Qt::QueuedConnection);
    m_window->update();

    m_destroyConnection = connect(
        m_window.data(), &QObject::destroyed,
        this, [this]() {
            detachWindow();
            m_window = nullptr;
            resetSample();
            emit windowChanged();
        });

    AppLogger::info("diagnostics.fps", "window_attached", QString(), {
        {"windowTitle", m_window->title()},
        {"sampleIntervalMs", m_sampleTimer.interval()},
        {"continuousSampling", true}
    });
}

void FpsMonitor::detachWindow() {
    if (m_frameConnection)
        disconnect(m_frameConnection);
    if (m_updateConnection)
        disconnect(m_updateConnection);
    if (m_destroyConnection)
        disconnect(m_destroyConnection);
    m_frameConnection = {};
    m_updateConnection = {};
    m_destroyConnection = {};
}

void FpsMonitor::resetSample() {
    m_pendingFrames.store(0, std::memory_order_relaxed);
    m_sampleClock.restart();
}

void FpsMonitor::setPublishedFps(int fps) {
    const qreal frameTime = fps > 0 ? 1000.0 / fps : 0.0;
    const bool fpsUpdated = m_fps != fps;
    const bool frameTimeUpdated = !qFuzzyCompare(m_frameTimeMs + 1.0,
                                                 frameTime + 1.0);

    m_fps = fps;
    m_frameTimeMs = frameTime;

    if (fpsUpdated)
        emit fpsChanged();
    if (frameTimeUpdated)
        emit frameTimeMsChanged();
}
