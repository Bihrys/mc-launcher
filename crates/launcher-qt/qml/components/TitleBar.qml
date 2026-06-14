import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root

    required property var appWindow
    required property var style

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

        Rectangle {
            width: 22
            height: 22
            radius: 5
            color: root.style.cPrimary

            Text {
                anchors.centerIn: parent
                text: "M"
                color: root.style.cLaunchButtonText
                font.bold: true
                font.pixelSize: 13
            }
        }

        Text {
            text: "MC Launcher"
            color: root.style.cTextOnPrimaryContainer
            font.bold: true
            font.pixelSize: 14
            Layout.fillWidth: true
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
