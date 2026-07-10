import QtQuick
import "../../components"

Rectangle {
    id: root
    objectName: "SettingsTextButton:" + root.text
    property var style
    property string text: "执行"
    property bool enabledButton: true
    signal clicked()

    width: Math.max(78, label.implicitWidth + 28)
    height: 30
    radius: 2
    border.width: 1
    border.color: styleValue("cBorder", "#D9D7E2")
    color: "transparent"
    opacity: enabledButton ? 1.0 : 0.45
    clip: true

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse && root.enabledButton
        hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
        rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) return value
        }
        return fallback
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.styleValue("cTextOnSurface", "#1B1B21")
        font.pixelSize: 13
    }

    MouseArea {
        id: mouse
        objectName: "SettingsTextButtonMouse:" + root.text
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledButton
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function(mouse) { ripple.press(mouse.x, mouse.y) }
        onReleased: ripple.release()
        onCanceled: ripple.cancel()
        onClicked: root.clicked()
    }
}
