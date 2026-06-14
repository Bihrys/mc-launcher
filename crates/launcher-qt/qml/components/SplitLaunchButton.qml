import QtQuick

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

    color: launchMainMouse.containsMouse || launchMenuMouse.containsMouse
           ? style.cLaunchButtonHover
           : style.cLaunchButton

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
                    color: root.style.cLaunchButtonText
                    font.bold: true
                    font.pixelSize: 16
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.subtitle
                    color: root.style.cLaunchButtonText
                    opacity: 0.82
                    font.pixelSize: 11
                }
            }

            MouseArea {
                id: launchMainMouse
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
                color: root.style.cLaunchButtonText
                font.pixelSize: 12
            }

            MouseArea {
                id: launchMenuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.menuClicked()
            }
        }
    }
}
