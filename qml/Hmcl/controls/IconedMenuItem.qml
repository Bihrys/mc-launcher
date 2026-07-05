import QtQuick
import "../../components"

Item {
    id: root

    required property var style
    property string title: ""
    property string iconKind: ""

    signal clicked()

    width: parent ? parent.width : 180
    height: 40

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse
        hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
        rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    HmclSvgIcon {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: root.iconKind
        iconSize: 18
        iconColor: root.styleValue("cTextOnSurface", "#222222")
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 44
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: root.styleValue("cTextOnSurface", "#222222")
        font.pixelSize: 12
        elide: Text.ElideRight
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
