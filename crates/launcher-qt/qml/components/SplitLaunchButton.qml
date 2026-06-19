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
        clip: true
        color: mainMouse.containsMouse ? root.style.cLaunchButtonHover : root.style.cPrimaryContainer

        Behavior on color {
            ColorAnimation {
                duration: root.style.animationsEnabled ? root.style.motionShort4 : 0
                easing.type: Easing.OutCubic
            }
        }

        HmclRipple {
            id: mainRipple
            anchors.fill: parent
            hovered: mainMouse.containsMouse
            hoverColor: root.style.cTextOnPrimaryContainer
            hoverOpacity: 0.04
            rippleColor: root.style.cTextOnPrimaryContainer
            rippleOpacity: 0.13
            animationsEnabled: root.style.animationsEnabled
            hoverDuration: root.style.motionShort4
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: root.style.cTextOnSurfaceVariant
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.title
                color: root.style.cTextOnPrimaryContainer
                font.pixelSize: 14
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
            onPressed: function(event) {
                mainRipple.press(event.x, event.y)
            }
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
        clip: true
        color: menuMouse.containsMouse ? root.style.cLaunchButtonHover : root.style.cPrimaryContainer

        Behavior on color {
            ColorAnimation {
                duration: root.style.animationsEnabled ? root.style.motionShort4 : 0
                easing.type: Easing.OutCubic
            }
        }

        HmclRipple {
            id: menuRipple
            anchors.fill: parent
            hovered: menuMouse.containsMouse
            hoverColor: root.style.cTextOnPrimaryContainer
            hoverOpacity: 0.04
            rippleColor: root.style.cTextOnPrimaryContainer
            rippleOpacity: 0.13
            animationsEnabled: root.style.animationsEnabled
            hoverDuration: root.style.motionShort4
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            color: menuButton.color
        }

        HmclSvgIcon {
            anchors.centerIn: parent
            icon: "ARROW_DROP_UP"
            iconSize: 20
            iconColor: root.style.cTextOnPrimaryContainer
            animationsEnabled: root.style.animationsEnabled
            animationDuration: root.style.motionShort4
        }

        MouseArea {
            id: menuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(event) {
                menuRipple.press(event.x, event.y)
            }
            onClicked: root.menuClicked()
        }
    }
}
