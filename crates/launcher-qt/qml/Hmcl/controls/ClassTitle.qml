import QtQuick

Item {
    id: root

    required property var style
    property string title: ""

    width: parent ? parent.width : 200
    height: 34

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: root.styleValue("cTextOnSurface", "#222222")
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        height: 1
        color: root.styleValue("cTextOnSurfaceVariant", "#666666")
        opacity: 0.75
    }
}
