import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/icons" as Icons

Rectangle {
    id: root
    property var style
    property string textValue: ""
    property string placeholderText: ""
    property bool enabledBox: true
    signal accepted(string value)
    signal browse()

    width: 180
    height: 32
    radius: 3
    color: root.styleValue("cSurfaceContainerHigh", "#ECE9F1")
    opacity: root.enabledBox ? 1.0 : 0.45

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 6

        TextField {
            id: input
            Layout.fillWidth: true
            enabled: root.enabledBox
            text: root.textValue
            placeholderText: root.placeholderText
            selectByMouse: true
            font.pixelSize: 12
            color: root.styleValue("cTextOnSurface", "#1B1B21")
            background: Item {}
            onAccepted: root.accepted(text)
            onEditingFinished: root.accepted(text)
        }

        Icons.SvgIcon {
            icon: "FOLDER_OPEN"
            iconSize: 18
            iconColor: root.styleValue("cTextOnSurfaceVariant", "#454651")
            opacity: root.enabledBox ? 1 : 0.4
            MouseArea {
                anchors.fill: parent
                enabled: root.enabledBox
                cursorShape: Qt.PointingHandCursor
                onClicked: root.browse()
            }
        }
    }
}
