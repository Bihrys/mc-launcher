import QtQuick
import QtQuick.Controls
import QtQuick.Window
import com.bihrys.launcher

ApplicationWindow {
    id: window
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

    function logWindow(action, details) {
        backend.logUiAction("ui.window.semantic", action, JSON.stringify(details || {}))
    }

    Component.onCompleted: {
        window.logWindow("application_window_completed", {
            "width": window.width,
            "height": window.height,
            "visibility": window.visibility,
            "logFile": backend.logFilePath,
            "sessionLogFile": backend.sessionLogFilePath,
            "crashLogFile": backend.crashLogFilePath
        })
    }

    onClosing: function(close) {
        window.logWindow("closing", {
            "accepted": close.accepted,
            "visibility": window.visibility,
            "active": window.active
        })
        backend.flushLogs()
    }

    onVisibleChanged: window.logWindow("visible_changed", {"visible": window.visible})
    onVisibilityChanged: window.logWindow("visibility_changed", {"visibility": window.visibility})
    onActiveChanged: window.logWindow("active_changed", {"active": window.active})

    RootShell {
        anchors.fill: parent
        appWindow: window
        backend: backend
    }
}
