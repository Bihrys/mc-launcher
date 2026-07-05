import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl

Item {
    id: root
    property var style
    property string version: ""
    property string major: ""
    property string vendor: ""
    property string path: ""
    property bool managed: path.indexOf("mc-launcher") >= 0
    signal reveal(string path)
    signal remove(string path)

    width: parent ? parent.width : 800
    height: 64

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) return value
        }
        return fallback
    }

    Rectangle {
        anchors.fill: parent
        color: mouse.containsMouse ? root.styleValue("cNavHover", "transparent") : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.styleValue("cBorder", "#D9D7E2")
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Hmcl.TwoLineListItem {
            Layout.fillWidth: true
            style: root.style
            title: (root.major.length > 0 ? (Number(root.major) >= 9 ? "JDK " : "JRE ") : "Java ") + (root.version.length > 0 ? root.version : root.major)
            subtitle: root.path
            tag: tagString()
        }

        Hmcl.ToolbarButton {
            style: root.style
            iconKind: "FOLDER_OPEN"
            onClicked: root.reveal(root.path)
        }

        Hmcl.ToolbarButton {
            style: root.style
            iconKind: root.managed ? "DELETE_FOREVER" : "DELETE"
            onClicked: root.remove(root.path)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    function tagString() {
        var out = []
        if (root.major.length > 0) out.push("架构: 当前平台")
        if (root.vendor.length > 0) out.push("发行商: " + root.vendor)
        return out.join("   ")
    }
}
