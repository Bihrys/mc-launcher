import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var style
    property real radiusValue: 4
    default property alias content: contentColumn.children

    width: parent ? parent.width : 600
    implicitHeight: contentColumn.implicitHeight

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
        anchors.fill: contentColumn
        radius: root.radiusValue
        color: root.styleValue("cSurface", "#FFFBFE")
        border.width: 0
    }

    Column {
        id: contentColumn
        width: root.width
        spacing: 0
    }
}
