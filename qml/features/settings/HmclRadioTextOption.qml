import QtQuick
import "../../Hmcl/controls" as Hmcl
import "../../components"

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

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse
        hoverColor: root.styleValue("cLaunchButton", "#4352A5")
        rippleColor: root.styleValue("cLaunchButton", "#4352A5")
        hoverOpacity: 0.08
        rippleOpacity: 0.22
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
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
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { ripple.press(mouse.x, mouse.y) }
        onReleased: ripple.release()
        onCanceled: ripple.cancel()
        onClicked: root.clicked()
    }
}
