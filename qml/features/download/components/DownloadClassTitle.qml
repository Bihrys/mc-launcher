import QtQuick

Item {
    id: root
    required property var style
    property string text: ""
    height: 28
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.style.cTextOnSurfaceVariant
        font.pixelSize: 11
        font.bold: true
    }
}
