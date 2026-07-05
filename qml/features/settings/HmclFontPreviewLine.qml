import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property var style
    property string text: "Hello Minecraft! Launcher"
    property string fontFamily: ""
    property real fontSize: 13

    width: parent ? parent.width : 800
    implicitHeight: 42
    height: implicitHeight
    color: styleValue("cSurface", "#FFFBFE")

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) return value
        }
        return fallback
    }

    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: root.styleValue("cBorder", "#D9D7E2") }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        text: root.text
        color: root.styleValue("cTextOnSurface", "#1B1B21")
        font.pixelSize: root.fontSize
        font.family: root.fontFamily.length > 0 ? root.fontFamily : ""
        elide: Text.ElideRight
    }
}
