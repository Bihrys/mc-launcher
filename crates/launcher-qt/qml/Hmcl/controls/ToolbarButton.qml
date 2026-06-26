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
    color: mouse.containsMouse ? root.style.cButtonHover : "transparent"

    Row {
        anchors.centerIn: parent
        spacing: 6
        SvgIcon {
            visible: root.iconKind.length > 0
            icon: root.iconKind
            iconSize: 18
            iconColor: root.style.cTextOnSurfaceVariant
            animationsEnabled: root.style.animationsEnabled
        }
        Text {
            id: label
            visible: root.text.length > 0
            text: root.text
            color: root.style.cTextOnSurface
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
