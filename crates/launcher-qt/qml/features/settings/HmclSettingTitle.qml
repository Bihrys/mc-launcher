import QtQuick

Item {
    id: root
    property var style
    property string title: ""
    width: parent ? parent.width : 800
    height: 28

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) return value
        }
        return fallback
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: root.title
        color: root.styleValue("cTextOnSurface", "#1B1B21")
        font.pixelSize: 13
        elide: Text.ElideRight
    }
}
