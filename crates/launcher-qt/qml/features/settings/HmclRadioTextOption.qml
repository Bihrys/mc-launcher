import QtQuick
import "../../Hmcl/controls" as Hmcl

Item {
    id: root
    property var style
    property string text: ""
    property bool checked: false
    signal clicked()

    width: radio.width + label.implicitWidth + 4
    height: 32

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) return value
        }
        return fallback
    }

    Hmcl.RadioButton {
        id: radio
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        style: root.style
        checked: root.checked
        onClicked: root.clicked()
    }

    Text {
        id: label
        anchors.left: radio.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.styleValue("cTextOnSurface", "#1B1B21")
        font.pixelSize: 13
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
