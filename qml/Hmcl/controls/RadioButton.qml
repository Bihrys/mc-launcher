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

    Rectangle {
        anchors.centerIn: parent
        width: 14
        height: 14
        radius: 7
        border.width: 2
        border.color: root.checked ? root.styleValue("cLaunchButton", "#2f6fed") : root.styleValue("cTextOnSurfaceVariant", "#666666")
        color: "transparent"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 7
        height: 7
        radius: 4
        color: root.styleValue("cLaunchButton", "#2f6fed")
        visible: root.checked
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
