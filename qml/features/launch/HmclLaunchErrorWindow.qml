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

    property var errorStatus: ({})
    property string taskId: ""
    property bool entered: false

    signal dismissed(string taskId)

    width: 500
    height: 300
    minimumWidth: 500
    minimumHeight: 300
    maximumWidth: 500
    maximumHeight: 300
    visible: false
    modality: Qt.ApplicationModal
    transientParent: parentWindow
    title: errorStatus.title || "启动失败"
    color: style.cSurfaceContainerHigh

    function showError(status) {
        errorStatus = status || ({})
        taskId = String(errorStatus.id || "")
        entered = false
        show()
        raise()
        requestActivate()
        enterTimer.restart()
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
            anchors.margins: 16
            spacing: 12
            opacity: root.entered ? 1 : 0
            scale: root.entered ? 1 : 0.98

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

            Label {
                Layout.fillWidth: true
                text: root.errorStatus.title || "启动失败"
                color: root.style.cTextOnSurface
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                TextArea {
                    width: parent.width
                    text: root.errorStatus.message || "无法启动游戏。"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    readOnly: true
                    selectByMouse: true
                    background: null
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Item { Layout.fillWidth: true }

                Item {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 36

                    Text {
                        anchors.centerIn: parent
                        text: "确定"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        z: 1
                    }

                    HmclRipple {
                        id: closeRipple
                        anchors.fill: parent
                        hovered: closeMouse.containsMouse
                        hoverColor: root.style.cTextOnSurface
                        rippleColor: root.style.cPrimary
                        animationsEnabled: root.style.animationsEnabled
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function(event) { closeRipple.press(event.x, event.y) }
                        onReleased: closeRipple.release()
                        onCanceled: closeRipple.cancel()
                        onClicked: root.close()
                    }
                }
            }
        }
    }
}
