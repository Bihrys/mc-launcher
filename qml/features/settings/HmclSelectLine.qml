import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import "../../Hmcl/icons" as Icons
import "../../components"

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

    function availableWindowHeight() {
        var w = button.Window.window
        return w ? w.height : 720
    }

    function preparePopupGeometry() {
        var itemHeight = 40
        var preferredHeight = Math.max(1, root.options.length) * itemHeight
        var p = button.mapToItem(null, 0, 0)
        var windowHeight = root.availableWindowHeight()
        var below = windowHeight - p.y - button.height - 8
        var above = p.y - 8
        popup.openUp = below < preferredHeight && above > below
        popup.height = Math.min(preferredHeight, Math.max(80, popup.openUp ? above : below))
        popup.y = popup.openUp ? -popup.height : button.height
    }

    Rectangle {
        id: button
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(260, parent.width * 0.48)
        height: 36
        radius: 3
        color: mouse.containsMouse || popup.opened ? root.styleValue("cSurfaceContainerHigh", "#ECE9F1") : root.styleValue("cSurfaceContainer", "#F5F2FA")
        opacity: root.enabledRow ? 1.0 : 0.45

        HmclRipple {
            id: buttonRipple
            anchors.fill: parent
            hovered: mouse.containsMouse && root.enabledRow
            hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
            rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
            animationsEnabled: !!root.styleValue("animationsEnabled", true)
        }

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
            rotation: popup.opened ? 180 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0.0, 0, 1.0, 1, 1]
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: root.enabledRow
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) { buttonRipple.press(mouse.x, mouse.y) }
            onReleased: buttonRipple.release()
            onCanceled: buttonRipple.cancel()
            onClicked: {
                if (popup.opened) {
                    popup.close()
                } else {
                    root.preparePopupGeometry()
                    popup.open()
                }
            }
        }

        Popup {
            id: popup
            property bool openUp: false
            x: 0
            y: button.height
            width: Math.max(button.width, 240)
            height: Math.max(1, contentColumn.implicitHeight)
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

            contentItem: Flickable {
                id: popupFlick
                width: popup.width
                height: popup.height
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentColumn
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

                            HmclRipple {
                                id: optionRipple
                                anchors.fill: parent
                                hovered: optionMouse.containsMouse
                                hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
                                rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
                                animationsEnabled: !!root.styleValue("animationsEnabled", true)
                            }

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
                                onPressed: function(mouse) { optionRipple.press(mouse.x, mouse.y) }
                                onReleased: optionRipple.release()
                                onCanceled: optionRipple.cancel()
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
    }
}
