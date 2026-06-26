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

    HmclSvgIcon {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: root.iconKind
        iconSize: 18
        iconColor: root.style.cTextOnSurface
        animationsEnabled: root.style.animationsEnabled
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 44
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
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
