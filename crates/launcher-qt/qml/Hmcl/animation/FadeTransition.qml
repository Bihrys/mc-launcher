import QtQuick
Item {
    id: root
    default property alias content: contentItem.data
    property bool animationsEnabled: true

    Item {
        id: contentItem
        anchors.fill: parent
        opacity: root.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.animationsEnabled ? 160 : 0; easing.type: Easing.OutCubic }
        }
    }
}
