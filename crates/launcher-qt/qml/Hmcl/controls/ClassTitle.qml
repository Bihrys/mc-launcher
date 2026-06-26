import QtQuick
Item {
    id: root
    required property var style
    property string title: ""
    width: parent ? parent.width : 200
    height: 34
    Text { anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: root.title; color: root.style.cTextOnSurface; font.pixelSize: 12; elide: Text.ElideRight }
    Rectangle { anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: parent.right; anchors.rightMargin: 16; anchors.bottom: parent.bottom; height: 1; color: root.style.cTextOnSurfaceVariant; opacity: 0.75 }
}
