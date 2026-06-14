import QtQuick

Rectangle {
    id: root

    required property var style

    property string title: ""
    property string subtitle: ""
    property bool selected: false

    signal clicked()

    width: parent ? parent.width : 220
    height: subtitle.length > 0 ? 58 : 46
    radius: 6
    color: selected ? style.navSelected : mouse.containsMouse ? style.navHover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 12
        spacing: 3

        Text {
            width: parent.width
            text: root.title
            color: style.onSurface
            font.pixelSize: 14
            font.bold: root.selected
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: style.onSurfaceVariant
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
