import QtQuick

Item {
    id: root

    required property var style

    property string title: "启动游戏"
    property string subtitle: ""

    signal launchClicked()
    signal menuClicked()

    width: 230
    height: 57

    Rectangle {
        id: mainButton

        x: 0
        y: 1
        width: 207
        height: 55
        radius: 4
        color: mainMouse.containsMouse ? root.style.cLaunchButtonHover : root.style.cPrimaryContainer

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: root.style.cTextOnSurfaceVariant
            opacity: 0.9
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.title
                color: root.style.cTextOnPrimaryContainer
                font.pixelSize: 16
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: root.style.cTextOnPrimaryContainer
                opacity: 0.88
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: mainMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launchClicked()
        }
    }

    Rectangle {
        id: menuButton

        x: 210
        y: 1
        width: 20
        height: 55
        radius: 4
        color: menuMouse.containsMouse ? root.style.cLaunchButtonHover : root.style.cPrimaryContainer

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            color: menuButton.color
        }

        Text {
            anchors.centerIn: parent
            text: "▲"
            color: root.style.cTextOnPrimaryContainer
            font.pixelSize: 15
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
