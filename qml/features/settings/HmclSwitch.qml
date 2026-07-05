import QtQuick
import "../../components"

Item {
    id: root

    property var style
    property bool checked: false
    property bool enabledControl: true
    property bool interactive: true
    signal toggled(bool value)

    implicitWidth: 44
    implicitHeight: 28
    width: 44
    height: 28
    opacity: enabledControl ? 1.0 : 0.40

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var v = root.style[name]
            if (v !== undefined && v !== null)
                return v
        }
        return fallback
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse && root.enabledControl
        hoverColor: root.styleValue("cLaunchButton", "#4352A5")
        rippleColor: root.styleValue("cLaunchButton", "#4352A5")
        hoverOpacity: 0.08
        rippleOpacity: 0.22
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    Rectangle {
        id: line
        anchors.centerIn: parent
        width: 34
        height: 14
        radius: 7
        color: root.checked
               ? root.styleValue("cSecondaryContainer", "#C6C5DD")
               : root.styleValue("cSurfaceContainerHighest", "#E7E0EC")
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Rectangle {
        id: knob
        width: 20
        height: 20
        radius: 10
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? 22 : 2
        color: root.checked
               ? root.styleValue("cLaunchButton", "#4352A5")
               : root.styleValue("cTextOnSurfaceVariant", "#767680")

        Behavior on x {
            enabled: root.styleValue("animationsEnabled", true)
            NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.0, 0, 1.0, 1, 1] }
        }
        Behavior on color {
            enabled: root.styleValue("animationsEnabled", true)
            ColorAnimation { duration: 200 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabledControl && root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { ripple.press(mouse.x, mouse.y) }
        onReleased: ripple.release()
        onCanceled: ripple.cancel()
        onClicked: function(mouse) {
            mouse.accepted = true
            root.toggled(!root.checked)
        }
    }
}
