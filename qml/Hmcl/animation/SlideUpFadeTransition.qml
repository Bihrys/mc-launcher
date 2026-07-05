import QtQuick

Item {
    id: root

    default property alias content: contentItem.data

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
