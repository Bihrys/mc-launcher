import QtQuick

Rectangle {
    id: root
    objectName: "NavItem:" + root.page + ":" + root.title

    required property var style

    property string title: ""
    property string subtitle: ""
    property string page: ""
    property string currentPage: ""

    signal clicked(string page)
    signal entered(string page)

    width: parent ? parent.width : 220
    height: subtitle.length > 0 ? 58 : 46
    radius: 6

    color: page === currentPage
           ? style.cNavSelected
           : navMouse.containsMouse ? style.cNavHover : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    MouseArea {
        id: navMouse
        objectName: "NavItemMouse:" + root.page + ":" + root.title
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked(root.page)
        onEntered: root.entered(root.page)
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 12
        spacing: 3

        Text {
            width: parent.width
            text: root.title
            color: root.style.cTextOnSurface
            font.pixelSize: 14
            font.bold: root.page === root.currentPage
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: root.style.cTextOnSurfaceVariant
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
