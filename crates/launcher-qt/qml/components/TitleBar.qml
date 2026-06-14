import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root

    required property var window
    required property var style

    height: style.titleBarHeight
    color: style.primaryContainer

    DragHandler {
        onActiveChanged: {
            if (active && root.window) {
                root.window.startSystemMove()
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
            color: style.primary

            Text {
                anchors.centerIn: parent
                text: "M"
                color: style.launchButtonText
                font.bold: true
                font.pixelSize: 13
            }
        }

        Text {
            text: "MC Launcher"
            color: style.onPrimaryContainer
            font.bold: true
            font.pixelSize: 14
            Layout.fillWidth: true
        }

        WindowButton {
            label: "—"
            style: root.style
            onClicked: root.window.showMinimized()
        }

        WindowButton {
            label: root.window.visibility === Window.Maximized ? "❐" : "□"
            style: root.style
            onClicked: {
                if (root.window.visibility === Window.Maximized) {
                    root.window.showNormal()
                } else {
                    root.window.showMaximized()
                }
            }
        }

        WindowButton {
            label: "×"
            style: root.style
            danger: true
            onClicked: Qt.quit()
        }
    }

    component WindowButton: Rectangle {
        id: btn

        required property var style
        property string label: ""
        property bool danger: false
        signal clicked()

        width: 42
        height: root.height
        color: mouse.containsMouse
               ? danger ? "#D32F2F" : "#225B62C8"
               : "transparent"

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.style.onPrimaryContainer
            font.pixelSize: 15
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
