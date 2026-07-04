import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var style
    property int topPadding: 12
    property int bottomPadding: 0
    default property alias content: contentColumn.data

    implicitWidth: 200
    implicitHeight: contentColumn.implicitHeight + topPadding + bottomPadding

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.topPadding
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomPadding
        spacing: 0
    }
}
