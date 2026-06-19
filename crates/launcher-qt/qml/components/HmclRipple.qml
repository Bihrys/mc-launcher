import QtQuick

Item {
    id: root

    // HMCL RipplerContainer:
    // - hover cover: onSurface * 0.04, Motion.SHORT4=200ms
    // - JFXRippler fill: css -jfx-rippler-fill
    // - position: BACK
    property color hoverColor: "#000000"
    property color rippleColor: "#000000"
    property real hoverOpacity: 0.04
    property real rippleOpacity: 0.12
    property bool hovered: false
    property bool animationsEnabled: true
    property int hoverDuration: 200
    property int rippleDuration: 300

    property real originX: width / 2
    property real originY: height / 2
    property real maxRadius: Math.sqrt(width * width + height * height)

    clip: true

    Rectangle {
        id: cover

        anchors.fill: parent
        color: root.hoverColor
        opacity: root.hovered ? root.hoverOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.animationsEnabled ? root.hoverDuration : 0
                easing.type: root.hovered ? Easing.InCubic : Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: circle

        width: root.maxRadius * 2
        height: root.maxRadius * 2
        radius: width / 2
        x: root.originX - width / 2
        y: root.originY - height / 2
        color: root.rippleColor
        opacity: 0
        scale: 0
        transformOrigin: Item.Center
    }

    SequentialAnimation {
        id: rippleAnimation

        ParallelAnimation {
            NumberAnimation {
                target: circle
                property: "scale"
                from: 0
                to: 1
                duration: root.animationsEnabled ? root.rippleDuration : 0
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: circle
                property: "opacity"
                from: root.rippleOpacity
                to: 0.07
                duration: root.animationsEnabled ? root.rippleDuration : 0
                easing.type: Easing.OutCubic
            }
        }

        NumberAnimation {
            target: circle
            property: "opacity"
            to: 0
            duration: root.animationsEnabled ? root.hoverDuration : 0
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: {
                circle.scale = 0
                circle.opacity = 0
            }
        }
    }

    function press(x, y) {
        if (!root.animationsEnabled) {
            return
        }

        root.originX = x
        root.originY = y
        rippleAnimation.stop()
        circle.scale = 0
        circle.opacity = root.rippleOpacity
        rippleAnimation.restart()
    }
}
