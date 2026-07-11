import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import "../../Hmcl/icons" as Icons
import "../../components"

HmclSettingLine {
    id: root
    property string resolution: "854x480"
    property bool fullscreen: false
    property var options: ["854x480", "1280x720", "1366x768", "1600x900", "1920x1080"]
    signal resolutionSelected(string value)
    signal fullscreenChangedByUser(bool value)

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var v = root.style[name]
            if (v !== undefined && v !== null)
                return v
        }
        return fallback
    }

    function preparePopupGeometry() {
        var itemHeight = 40
        var preferredHeight = Math.max(1, root.options.length) * itemHeight
        var p = button.mapToItem(null, 0, 0)
        var windowHeight = button.Window.window ? button.Window.window.height : 720
        var below = windowHeight - p.y - button.height - 8
        var above = p.y - 8
        popup.openUp = below < preferredHeight && above > below
        popup.height = Math.min(preferredHeight, Math.max(80, popup.openUp ? above : below))
        popup.y = popup.openUp ? -popup.height : button.height
    }

    RowLayout {
        enabled: root.effectiveEnabled
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 300
        spacing: 12

        Rectangle {
            id: button
            Layout.preferredWidth: 150
            Layout.preferredHeight: 36
            radius: 3
            color: selectMouse.containsMouse || popup.opened ? root.styleValue("cSurfaceContainerHigh", "#ECE9F1") : root.styleValue("cSurfaceContainer", "#F5F2FA")
            opacity: root.effectiveEnabled && !root.fullscreen ? 1.0 : 0.45

            HmclRipple {
                id: buttonRipple
                anchors.fill: parent
                hovered: selectMouse.containsMouse && root.effectiveEnabled && !root.fullscreen
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
                text: root.resolution
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
                Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
            }

            MouseArea {
                id: selectMouse
                anchors.fill: parent
                enabled: root.effectiveEnabled && !root.fullscreen
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
                width: button.width
                height: 1
                padding: 0
                modal: false
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle { color: root.styleValue("cSurface", "#FFFBFE"); radius: 3; border.color: root.styleValue("cBorder", "#D9D7E2"); border.width: 1 }
                contentItem: Flickable {
                    width: popup.width
                    height: popup.height
                    contentWidth: width
                    contentHeight: optionColumn.implicitHeight
                    clip: true
                    Column {
                        id: optionColumn
                        width: popup.width
                        Repeater {
                            model: root.options
                            delegate: Rectangle {
                                required property var modelData
                                width: popup.width
                                height: 40
                                color: root.resolution === modelData ? root.styleValue("cNavSelected", "#E7E7FF") : optionMouse.containsMouse ? root.styleValue("cSurfaceContainer", "#F5F2FA") : root.styleValue("cSurface", "#FFFBFE")
                                HmclRipple { id: optionRipple; anchors.fill: parent; hovered: optionMouse.containsMouse; hoverColor: root.styleValue("cTextOnSurface", "#1B1B21"); rippleColor: root.styleValue("cTextOnSurface", "#1B1B21"); animationsEnabled: !!root.styleValue("animationsEnabled", true) }
                                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 12; text: modelData; color: root.styleValue("cTextOnSurface", "#1B1B21"); font.pixelSize: 12 }
                                MouseArea { id: optionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPressed: function(mouse) { optionRipple.press(mouse.x, mouse.y) }; onReleased: optionRipple.release(); onCanceled: optionRipple.cancel(); onClicked: { popup.close(); root.resolutionSelected(modelData) } }
                            }
                        }
                    }
                }
            }
        }

        HmclCheckBox {
            style: root.style
            checked: root.fullscreen
            onToggled: function(v) { root.fullscreenChangedByUser(v) }
        }
        Text { text: "全屏"; font.pixelSize: 13; color: root.styleValue("cTextOnSurface", "#1B1B21") }
    }
}
