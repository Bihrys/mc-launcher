import QtQuick
import "../../components"

Item {
    id: root

    required property var style
    property string title: ""
    property string subtitle: ""
    property string iconKind: ""
    property string imageSource: ""
    property bool active: false

    signal clicked()
    signal entered()

    width: parent ? parent.width : 200
    height: subtitle.length > 0 ? 48 : 40

    Rectangle {
        anchors.fill: parent
        color: root.active ? root.style.cNavSelected : "transparent"
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse
        hoverColor: root.style.cTextOnSurface
        hoverOpacity: 0.04
        rippleColor: root.style.cTextOnSurfaceVariant
        rippleOpacity: 0.10
        animationsEnabled: root.style.animationsEnabled
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.entered()
        onPressed: function(event) {
            ripple.press(event.x, event.y)
        }
        onClicked: root.clicked()
    }

    Image {
        visible: root.imageSource.length > 0
        source: root.imageSource
        width: 32
        height: 32
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        sourceSize.width: 32
        sourceSize.height: 32
        smooth: true
    }

    HmclSvgIcon {
        visible: root.imageSource.length === 0
        icon: root.iconKind
        iconSize: 20
        iconColor: root.style.cTextOnSurface
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        animationsEnabled: root.style.animationsEnabled
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 58
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.subtitle.length > 0 ? root.title + "\n" + root.subtitle : root.title
        color: root.style.cTextOnSurface
        font.pixelSize: root.subtitle.length > 0 ? 12 : 13
        lineHeight: 0.92
        elide: Text.ElideRight
    }
}
