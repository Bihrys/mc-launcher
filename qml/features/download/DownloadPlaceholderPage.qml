import QtQuick

Rectangle {
    id: root
    required property var style
    required property string title
    property string message: ""
    color: "transparent"
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 560)
        height: 220
        radius: 4
        color: root.style.cSurfaceContainerHigh
        border.color: root.style.cBorder
        border.width: 1
        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 10
            Text {
                width: parent.width
                text: root.title
                color: root.style.cTextOnSurface
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                width: parent.width
                text: root.message
                color: root.style.cTextOnSurfaceVariant
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }
}
