import QtQuick

Rectangle {
    id: root

    property var style

    implicitWidth: 188
    implicitHeight: childrenRect.height
    color: root.styleValue("cSurface", "#ffffff")
    radius: 2
    border.width: 1
    border.color: root.styleValue("cBorder", "#dddddd")
    clip: true

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }
}
