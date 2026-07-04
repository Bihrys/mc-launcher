import QtQuick
import "../../Hmcl/icons" as Icons

Item {
    id: root
    property var style
    property bool checked: false
    property bool enabledBox: true
    signal toggled(bool value)

    width: 22
    height: 22
    opacity: enabledBox ? 1.0 : 0.42

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    Rectangle {
        anchors.centerIn: parent
        width: 18
        height: 18
        radius: 2
        border.width: root.checked ? 0 : 2
        border.color: root.styleValue("cTextOnSurfaceVariant", "#454651")
        color: root.checked ? root.styleValue("cLaunchButton", "#4352A5") : "transparent"

        Icons.SvgIcon {
            anchors.centerIn: parent
            visible: root.checked
            icon: "CHECK"
            iconSize: 16
            iconColor: root.styleValue("cLaunchButtonText", "#FFFFFF")
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabledBox
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) { mouse.accepted = true; root.toggled(!root.checked) }
    }
}
