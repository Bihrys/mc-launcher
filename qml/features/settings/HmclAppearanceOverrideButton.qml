import QtQuick
import "../../components"

Rectangle {
    id: root

    property var style
    property bool overridden: false
    signal clicked()

    width: 15
    height: 15
    radius: 8
    color: "transparent"
    clip: true

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse
        hoverColor: root.styleValue("cPrimary", "#4352A5")
        rippleColor: root.styleValue("cPrimary", "#4352A5")
        hoverOpacity: 0.08
        rippleOpacity: 0.22
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
        circularMask: true
    }

    HmclSvgIcon {
        anchors.centerIn: parent
        icon: root.overridden ? "EDIT" : "STYLE"
        iconSize: 12
        iconColor: root.overridden ? root.styleValue("cPrimary", "#4352A5") : "#CCCC33"
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
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
