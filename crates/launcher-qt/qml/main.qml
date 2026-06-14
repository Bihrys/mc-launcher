import QtQuick
import QtQuick.Controls
import QtQuick.Window
import com.bihrys.launcher

ApplicationWindow {
    id: window

    width: 960
    height: 600
    minimumWidth: 840
    minimumHeight: 520
    visible: true
    title: "MC Launcher"
    flags: Qt.Window | Qt.FramelessWindowHint

    LauncherBackend {
        id: backend
    }

    RootShell {
        anchors.fill: parent
        appWindow: window
        backend: backend
    }
}
