import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../../components"

Window {
    id: root

    required property var style
    required property var backend
    required property var parentWindow

    property var crash: ({})
    property string taskId: ""
    property bool entered: false
    property string exportMessage: ""

    signal dismissed(string taskId)

    width: 800
    height: 480
    minimumWidth: 800
    minimumHeight: 480
    visible: false
    modality: Qt.NonModal
    transientParent: parentWindow
    title: "游戏崩溃"
    color: style.cSurfaceContainerHigh

    function showCrash(status) {
        taskId = String(status && status.id || "")
        crash = status && status.crash ? status.crash : ({})
        exportMessage = ""
        entered = false
        show()
        raise()
        requestActivate()
        enterTimer.restart()
    }

    function loaderText() {
        var values = crash.loaderKinds || []
        if (!values || values.length === 0)
            return "原版"
        return values.join("、")
    }

    function exitTitle() {
        var type = String(crash.exitType || "APPLICATION_ERROR")
        if (type === "JVM_ERROR")
            return "无法创建 Java 虚拟机"
        if (type === "SIGKILL")
            return "游戏被强制结束"
        return "游戏异常退出"
    }

    function memoryText() {
        var value = Number(crash.memoryMiB || 0)
        return value > 0 ? value + " MiB" : "-"
    }

    onClosing: function(close) {
        root.dismissed(root.taskId)
    }

    Timer {
        id: enterTimer
        interval: 1
        repeat: false
        onTriggered: root.entered = true
    }

    Rectangle {
        anchors.fill: parent
        color: root.style.cSurfaceContainerHigh

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            opacity: root.entered ? 1 : 0
            scale: root.entered ? 1 : 0.985

            Behavior on opacity {
                NumberAnimation {
                    duration: root.style.animationsEnabled ? 160 : 0
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.style.animationsEnabled ? 180 : 0
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: root.style.cPrimary

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.exitTitle()
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                contentWidth: infoRow.implicitWidth + 16
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: infoRow
                    x: 8
                    y: 8
                    height: 62
                    spacing: 8

                    Repeater {
                        model: [
                            {"title": "启动器", "subtitle": "HMCL-Qt " + String(root.crash.launcherVersion || "0.1.0")},
                            {"title": "游戏版本", "subtitle": String(root.crash.versionId || "-")},
                            {"title": "内存", "subtitle": root.memoryText()},
                            {"title": "Java", "subtitle": "Java " + String(root.crash.javaMajor || "-")},
                            {"title": "操作系统", "subtitle": String(root.crash.operatingSystem || "-")},
                            {"title": "系统架构", "subtitle": String(root.crash.architecture || "-")}
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: 118
                            height: 62
                            radius: 3
                            color: Qt.rgba(root.style.cPrimary.r,
                                           root.style.cPrimary.g,
                                           root.style.cPrimary.b,
                                           root.style.darkMode ? 0.15 : 0.08)

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: root.style.cTextOnSurface
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.subtitle
                                    color: root.style.cTextOnSurfaceVariant
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 180
                    Layout.fillHeight: true
                    radius: 3
                    color: Qt.rgba(root.style.cPrimary.r,
                                   root.style.cPrimary.g,
                                   root.style.cPrimary.b,
                                   root.style.darkMode ? 0.15 : 0.08)
                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 5
                        spacing: 2
                        Text {
                            width: parent.width
                            text: "加载器"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.loaderText()
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                spacing: 5

                Text {
                    Layout.fillWidth: true
                    text: "游戏目录"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: String(root.crash.gameDirectory || "-")
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
                Text {
                    Layout.fillWidth: true
                    text: "Java 路径"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: String(root.crash.javaExecutable || "-")
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }
                Text {
                    Layout.fillWidth: true
                    text: "崩溃原因"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 12
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 3
                    color: Qt.rgba(root.style.cTextOnSurface.r,
                                   root.style.cTextOnSurface.g,
                                   root.style.cTextOnSurface.b,
                                   root.style.darkMode ? 0.06 : 0.035)

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                        TextArea {
                            width: parent.width
                            text: {
                                var reason = String(root.crash.reason || "无法确定崩溃原因。")
                                var details = String(root.crash.details || "")
                                return details.length > 0 ? reason + "\n\n" + details : reason
                            }
                            color: root.style.cTextOnSurface
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            readOnly: true
                            selectByMouse: true
                            background: null
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 4
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: root.exportMessage
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                }

                Repeater {
                    model: [
                        {"text": "导出游戏崩溃日志", "action": "export"},
                        {"text": "日志", "action": "log"},
                        {"text": "帮助", "action": "help"}
                    ]

                    delegate: Rectangle {
                        id: buttonRoot
                        required property var modelData
                        Layout.preferredWidth: modelData.action === "export" ? 150 : 72
                        Layout.preferredHeight: 36
                        radius: 3
                        color: root.style.cPrimary

                        Text {
                            anchors.centerIn: parent
                            text: buttonRoot.modelData.text
                            color: "white"
                            font.pixelSize: 12
                            z: 1
                        }

                        HmclRipple {
                            id: buttonRipple
                            anchors.fill: parent
                            hovered: buttonMouse.containsMouse
                            hoverColor: "white"
                            rippleColor: "white"
                            animationsEnabled: root.style.animationsEnabled
                        }

                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function(event) { buttonRipple.press(event.x, event.y) }
                            onReleased: buttonRipple.release()
                            onCanceled: buttonRipple.cancel()
                            onClicked: {
                                if (buttonRoot.modelData.action === "export") {
                                    var path = root.backend.exportGameCrashLog(String(root.crash.gameLogFile || ""))
                                    root.exportMessage = path && path.length > 0
                                        ? "已导出到 " + path : "导出失败"
                                } else if (buttonRoot.modelData.action === "log") {
                                    root.backend.openFile(String(root.crash.gameLogFile || ""))
                                } else {
                                    root.backend.openUrl("https://docs.hmcl.net/help.html")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
