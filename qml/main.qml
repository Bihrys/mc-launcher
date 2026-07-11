import QtQuick
import QtQuick.Controls
import QtQuick.Window
import com.bihrys.launcher

ApplicationWindow {
    id: appWindow
    objectName: "mainApplicationWindow"

    width: 960
    height: 600
    minimumWidth: 840
    minimumHeight: 520
    visible: true
    title: "MC Launcher"
    flags: Qt.Window | Qt.FramelessWindowHint

    LauncherBackend {
        id: backend
        objectName: "launcherBackendQmlInstance"
    }

    FpsMonitor {
        id: fpsMonitor
        objectName: "qtQuickFpsMonitor"
        window: appWindow
        enabled: true
    }

    function logWindow(action, details) {
        backend.logUiAction("ui.window.semantic", action, JSON.stringify(details || {}))
    }

    Component.onCompleted: {
        appWindow.logWindow("application_window_completed", {
            "width": appWindow.width,
            "height": appWindow.height,
            "visibility": appWindow.visibility,
            "logFile": backend.logFilePath,
            "sessionLogFile": backend.sessionLogFilePath,
            "crashLogFile": backend.crashLogFilePath
        })
    }

    onClosing: function(close) {
        appWindow.logWindow("closing", {
            "accepted": close.accepted,
            "visibility": appWindow.visibility,
            "active": appWindow.active
        })
        backend.flushLogs()
    }

    onVisibleChanged: appWindow.logWindow("visible_changed", {"visible": appWindow.visible})
    onVisibilityChanged: appWindow.logWindow("visibility_changed", {"visibility": appWindow.visibility})
    onActiveChanged: appWindow.logWindow("active_changed", {"active": appWindow.active})

    RootShell {
        anchors.fill: parent
        appWindow: appWindow
        backend: backend
        fpsMonitor: fpsMonitor
    }
}
