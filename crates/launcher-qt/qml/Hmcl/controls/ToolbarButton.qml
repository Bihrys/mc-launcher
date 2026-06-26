import QtQuick
import "../../components"

Item {
    id: root

    required property var style
    property string text: ""
    property string iconKind: ""

    signal clicked()

    width: Math.max(70, label.implicitWidth + 34)
    height: 32

    HmclSvgIcon {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        icon: root.iconKind
        iconSize: 18
        iconColor: root.style.cTextOnSurface
        animationsEnabled: root.style.animationsEnabled
    }

    Text {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.style.cTextOnSurface
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
