import QtQuick

Item {
    id: root

    required property var style
    property bool checked: false

    signal clicked()

    width: 24
    height: 24

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    Rectangle {
        anchors.centerIn: parent
        width: 14
        height: 14
        radius: 7
        border.width: 2
        border.color: root.checked ? root.styleValue("cLaunchButton", "#2f6fed") : root.styleValue("cTextOnSurfaceVariant", "#666666")
        color: "transparent"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 7
        height: 7
        radius: 4
        color: root.styleValue("cLaunchButton", "#2f6fed")
        visible: root.checked
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
