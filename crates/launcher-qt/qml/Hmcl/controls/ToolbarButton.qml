import QtQuick
import "../icons"

Rectangle {
    id: root

    property var style
    property string iconKind: ""
    property string text: ""

    signal clicked()

    width: text.length > 0 ? label.implicitWidth + 24 : 30
    height: 30
    radius: 15
    color: mouse.containsMouse ? root.styleValue("cButtonHover", "#00000010") : "transparent"

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
            iconColor: root.styleValue("cTextOnSurfaceVariant", "#666666")
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
        onClicked: root.clicked()
    }
}
