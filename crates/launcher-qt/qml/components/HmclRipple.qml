import QtQuick

Item {
    id: root

    property color rippleColor: "#000000"
    property real rippleOpacity: 0.12
    property real originX: width / 2
    property real originY: height / 2
    property real rippleSize: Math.max(width, height) * 2.2
    property bool animationsEnabled: true

    clip: true

    Rectangle {
        id: circle
        width: root.rippleSize
        height: root.rippleSize
        radius: width / 2
        x: root.originX - width / 2
        y: root.originY - height / 2
        color: root.rippleColor
        opacity: 0
        scale: 0
    }

    SequentialAnimation {
        id: rippleAnimation

        ParallelAnimation {
            NumberAnimation {
                target: circle
                property: "scale"
                from: 0
                to: 1
                duration: root.animationsEnabled ? 300 : 0
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: circle
                property: "opacity"
                from: root.rippleOpacity
                to: 0.07
                duration: root.animationsEnabled ? 300 : 0
                easing.type: Easing.OutCubic
            }
        }

        NumberAnimation {
            target: circle
            property: "opacity"
            to: 0
            duration: root.animationsEnabled ? 300 : 0
            easing.type: Easing.OutCubic
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
