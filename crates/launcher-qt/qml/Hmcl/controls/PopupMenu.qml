import QtQuick

Rectangle {
    id: root
    property var style
    implicitWidth: 188
    implicitHeight: childrenRect.height
    color: style ? style.cSurface : "#ffffff"
    radius: 2
    border.width: 1
    border.color: style ? style.cBorder : "#dddddd"
    clip: true
}
