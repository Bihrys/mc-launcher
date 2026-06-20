import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root

    required property var appWindow
    required property var style

    // HMCL 的标题不是全局常驻，而是由当前 DecoratorPage.State 决定。
    // 这里先按当前项目结构：只有主页显示启动器标题。
    property bool showBrand: true
    property string titleText: "Hello Minecraft! Launcher"

    height: style.titleBarHeightValue
    color: style.cPrimaryContainer

    DragHandler {
        onActiveChanged: {
            if (active) {
                root.appWindow.startSystemMove()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        spacing: 8

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: root.showBrand
                opacity: root.showBrand ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.style.animationsEnabled ? root.style.motionShort4 : 0
                        easing.type: Easing.OutCubic
                    }
                }

                Image {
                    width: 24
                    height: 24
                    source: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/icon-title.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.titleText
                    color: root.style.cTextOnPrimaryContainer
                    font.bold: true
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            width: 42
            height: root.style.titleBarHeightValue
            color: minMouse.containsMouse ? "#225B62C8" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "—"
                color: root.style.cTextOnPrimaryContainer
                font.pixelSize: 15
            }

            MouseArea {
                id: minMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.appWindow.showMinimized()
            }
        }

        Rectangle {
            width: 42
            height: root.style.titleBarHeightValue
            color: maxMouse.containsMouse ? "#225B62C8" : "transparent"

            Text {
                anchors.centerIn: parent
                text: root.appWindow.visibility === Window.Maximized ? "❐" : "□"
                color: root.style.cTextOnPrimaryContainer
                font.pixelSize: 15
            }

            MouseArea {
                id: maxMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (root.appWindow.visibility === Window.Maximized) {
                        root.appWindow.showNormal()
                    } else {
                        root.appWindow.showMaximized()
                    }
                }
            }
        }

        Rectangle {
            width: 42
            height: root.style.titleBarHeightValue
            color: closeMouse.containsMouse ? "#D32F2F" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "×"
                color: root.style.cTextOnPrimaryContainer
                font.pixelSize: 15
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.quit()
            }
        }
    }
}
