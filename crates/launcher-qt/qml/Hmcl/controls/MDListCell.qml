import QtQuick

Item {
    id: root
    property var style
    property bool hovered: mouse.containsMouse
    signal clicked()
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        color: root.hovered ? root.style.cNavHover : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.style.cBorder
        opacity: 0.7
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }
}
