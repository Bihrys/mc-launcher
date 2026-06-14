import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property var style

    property string title: "启动游戏"
    property string subtitle: "未选择版本"

    signal launchClicked()
    signal menuClicked()

    width: 245
    height: 56
    radius: 8
    color: launchMouse.containsMouse || menuMouse.containsMouse
           ? style.launchButtonHover
           : style.launchButton

    Row {
        anchors.fill: parent

        Item {
            width: root.width - 38
            height: root.height

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.title
                    color: style.launchButtonText
                    font.bold: true
                    font.pixelSize: 16
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.subtitle
                    color: style.launchButtonText
                    opacity: 0.82
                    font.pixelSize: 11
                }
            }

            MouseArea {
                id: launchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchClicked()
            }
        }

        Rectangle {
            width: 1
            height: root.height
            color: "#55FFFFFF"
        }

        Item {
            width: 37
            height: root.height

            Text {
                anchors.centerIn: parent
                text: "▲"
                color: style.launchButtonText
                font.pixelSize: 12
            }

            MouseArea {
                id: menuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.menuClicked()
            }
        }
    }
}
