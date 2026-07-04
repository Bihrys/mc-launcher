import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../Hmcl/icons" as Icons

HmclSettingLine {
    id: root
    property var options: []
    property string value: ""
    signal selected(string value)

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var v = root.style[name]
            if (v !== undefined && v !== null)
                return v
        }
        return fallback
    }

    function currentText() {
        for (var i = 0; i < root.options.length; ++i) {
            if (String(root.options[i].value) === root.value)
                return String(root.options[i].text)
        }
        return root.options.length > 0 ? String(root.options[0].text) : ""
    }

    Rectangle {
        id: button
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(260, parent.width * 0.48)
        height: 36
        radius: 3
        color: mouse.containsMouse ? root.styleValue("cSurfaceContainerHigh", "#ECE9F1") : root.styleValue("cSurfaceContainer", "#F5F2FA")
        opacity: root.enabledRow ? 1.0 : 0.45

        Text {
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            text: root.currentText()
            color: root.styleValue("cTextOnSurface", "#1B1B21")
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Icons.SvgIcon {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            icon: "KEYBOARD_ARROW_DOWN"
            iconSize: 20
            iconColor: root.styleValue("cTextOnSurfaceVariant", "#454651")
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: root.enabledRow
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.open()
        }
    }

    Popup {
        id: popup
        x: button.x
        y: button.y + button.height
        width: Math.max(button.width, 240)
        padding: 0
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: root.styleValue("cSurface", "#FFFBFE")
            radius: 3
            border.color: root.styleValue("cBorder", "#D9D7E2")
            border.width: 1
        }

        Column {
            width: popup.width
            Repeater {
                model: root.options
                delegate: Rectangle {
                    required property var modelData
                    width: popup.width
                    height: 40
                    color: String(modelData.value) === root.value
                           ? root.styleValue("cNavSelected", "#E7E7FF")
                           : optionMouse.containsMouse ? root.styleValue("cSurfaceContainer", "#F5F2FA") : root.styleValue("cSurface", "#FFFBFE")

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: String(modelData.text)
                        color: String(modelData.value) === root.value
                               ? root.styleValue("cLaunchButton", "#4352A5")
                               : root.styleValue("cTextOnSurface", "#1B1B21")
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.close()
                            root.selected(String(modelData.value))
                        }
                    }
                }
            }
        }
    }
}
