import QtQuick
import QtQuick.Layouts
import "../icons"

Item {
    id: root
    property var style
    property string title: ""
    property string subtitle: ""
    property string iconKind: ""
    property bool selected: false
    property bool enabledItem: true
    signal clicked()

    width: parent ? parent.width : 220
    height: subtitle.length > 0 ? 48 : 40

    Rectangle {
        anchors.fill: parent
        color: root.selected ? root.style.cNavSelected : mouse.containsMouse ? root.style.cNavHover : "transparent"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8
        SvgIcon {
            visible: root.iconKind.length > 0
            icon: root.iconKind
            iconSize: 20
            iconColor: root.selected ? root.style.cButtonSelected : root.style.cTextOnSurfaceVariant
            animationsEnabled: root.style.animationsEnabled
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: root.title; color: root.style.cTextOnSurface; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { visible: root.subtitle.length > 0; text: root.subtitle; color: root.style.cTextOnSurfaceVariant; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledItem
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
