import QtQuick
import "../../components"

Item {
    id: root

    required property var style
    property bool checked: false

    signal clicked()

    width: 24
    height: 24

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse
        hoverColor: root.styleValue("cLaunchButton", "#2f6fed")
        rippleColor: root.styleValue("cLaunchButton", "#2f6fed")
        hoverOpacity: 0.08
        rippleOpacity: 0.22
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    // JFoenix/HMCL radio geometry: 14 px outer ring, 2 px stroke,
    // 8 px selected dot. Integer coordinates avoid half-pixel skew.
    Rectangle {
        x: 5
        y: 5
        width: 14
        height: 14
        radius: 7
        border.width: 2
        border.color: root.checked ? root.styleValue("cLaunchButton", "#2f6fed") : root.styleValue("cTextOnSurfaceVariant", "#666666")
        color: "transparent"
        antialiasing: true
    }

    Rectangle {
        x: 8
        y: 8
        width: 8
        height: 8
        radius: 4
        color: root.styleValue("cLaunchButton", "#2f6fed")
        scale: root.checked ? 1.0 : 0.0
        antialiasing: true
        Behavior on scale {
            enabled: !!root.styleValue("animationsEnabled", true)
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { ripple.press(mouse.x, mouse.y) }
        onReleased: ripple.release()
        onCanceled: ripple.cancel()
        onClicked: root.clicked()
    }
}
