import QtQuick

Item {
    id: root

    required property var style
    property string titleText: "页面"

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 24

        width: Math.min(parent.width - 48, 520)
        height: 120
        radius: root.style.radiusValue
        color: root.style.cSurfaceContainerHigh

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            Text {
                text: root.titleText
                color: root.style.cTextOnSurface
                font.pixelSize: 21
                font.bold: true
            }

            Text {
                width: parent.width
                text: "页面占位。下一步把 HMCL 对应页面的控件和 Rust 后端接口接进这里。"
                color: root.style.cTextOnSurfaceVariant
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }
}
