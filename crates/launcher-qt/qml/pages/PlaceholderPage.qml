import QtQuick

Item {
    id: root

    required property var style
    property string pageTitle: ""

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 24
        width: Math.min(parent.width - 48, 520)
        height: 120
        radius: style.radius
        color: style.surfaceContainerHigh

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            Text {
                text: root.pageTitle
                color: style.onSurface
                font.pixelSize: 21
                font.bold: true
            }

            Text {
                width: parent.width
                text: "页面占位。下一步把 HMCL 对应页面的控件和 Rust 后端接口接进这里。"
                color: style.onSurfaceVariant
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }
}
