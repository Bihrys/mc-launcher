import QtQuick

Item {
    id: root

    required property var style
    property string title: ""

    width: parent ? parent.width : 200
    height: 32
    implicitHeight: 32

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: 0

        Text {
            width: parent.width
            text: root.title
            color: root.styleValue("cTextOnSurface", "#222222")
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            width: parent.width
            height: 1
            color: root.styleValue("cTextOnSurfaceVariant", "#666666")
            opacity: 0.75
        }
    }
}
