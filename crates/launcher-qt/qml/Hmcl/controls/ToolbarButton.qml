import QtQuick
import "../icons"
import "../../components"

Rectangle {
    id: root

    property var style
    property string iconKind: ""
    property string text: ""
    property color iconColor: styleValue("cTextOnSurfaceVariant", "#666666")

    signal clicked()

    width: text.length > 0 ? label.implicitWidth + 24 : 30
    height: 30
    radius: 15
    color: "transparent"
    clip: true

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse
        hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
        rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        SvgIcon {
            visible: root.iconKind.length > 0
            icon: root.iconKind
            iconSize: 18
            iconColor: root.iconColor
            animationsEnabled: !!root.styleValue("animationsEnabled", true)
        }

        Text {
            id: label
            visible: root.text.length > 0
            text: root.text
            color: root.styleValue("cTextOnSurface", "#222222")
            font.pixelSize: 12
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
