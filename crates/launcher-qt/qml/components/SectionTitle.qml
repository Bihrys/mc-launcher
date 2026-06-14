import QtQuick

Item {
    id: root

    required property var style
    property string title: ""

    width: parent ? parent.width : 220
    height: 34

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5

        text: root.title
        color: root.style.cTextOnSurfaceVariant
        font.pixelSize: 11
        font.bold: true
    }
}
