import QtQuick

Item {
    id: root

    required property var style
    property bool checked: false

    signal clicked()

    width: 24
    height: 24

    Rectangle {
        anchors.centerIn: parent
        width: 14
        height: 14
        radius: 7
        border.width: 2
        border.color: root.checked ? root.style.cLaunchButton : root.style.cTextOnSurfaceVariant
        color: "transparent"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 7
        height: 7
        radius: 4
        color: root.style.cLaunchButton
        visible: root.checked
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
