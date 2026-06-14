import QtQuick

Text {
    required property var style

    width: parent ? parent.width : implicitWidth
    color: style.onSurfaceVariant
    font.pixelSize: 11
    font.bold: true
    leftPadding: 10
    topPadding: 14
    bottomPadding: 5
}
