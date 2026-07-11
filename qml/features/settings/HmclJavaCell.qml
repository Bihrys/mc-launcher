import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl

Item {
    id: root

    property var style
    property string version: ""
    property int major: -1
    property string vendor: ""
    property string architecture: ""
    property string path: ""
    property string home: ""
    property bool managed: false
    property bool isJdk: false

    signal reveal(string path)
    signal removeRequested(string path, bool managed)

    width: parent ? parent.width : 800
    height: 64

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    Rectangle {
        anchors.fill: parent
        color: hoverArea.containsMouse
               ? root.styleValue("cNavHover", "#0D000000")
               : "transparent"
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
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: 2
            color: root.styleValue("cSecondaryContainer", "#E2E0F0")

            Text {
                anchors.centerIn: parent
                text: root.major > 0 ? String(root.major) : "?"
                color: root.styleValue("cTextOnSurface", "#222222")
                font.pixelSize: 12
            }
        }

        Hmcl.TwoLineListItem {
            Layout.fillWidth: true
            style: root.style
            title: (root.isJdk ? "JDK " : "JRE ") + (root.version.length > 0 ? root.version : "未知版本")
            subtitle: root.path
            tag: root.tagString()
        }

        Hmcl.ToolbarButton {
            style: root.style
            iconKind: "FOLDER_OPEN"
            onClicked: root.reveal(root.home.length > 0 ? root.home : root.path)
        }

        Hmcl.ToolbarButton {
            style: root.style
            iconKind: root.managed ? "DELETE_FOREVER" : "DELETE"
            onClicked: root.removeRequested(root.path, root.managed)
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    function tagString() {
        var out = []
        if (root.architecture.length > 0)
            out.push("架构: " + root.architecture)
        if (root.vendor.length > 0)
            out.push("发行商: " + root.vendor)
        if (root.managed)
            out.push("由启动器管理")
        return out.join("   ")
    }
}
