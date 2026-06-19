import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    property bool showUpdateBubble: false
    property string latestVersionText: ""

    Rectangle {
        id: updatePane

        visible: root.showUpdateBubble
        width: 260
        height: 80
        radius: 4
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        color: root.style.cSurfaceContainerHigh
        border.width: 1
        border.color: root.style.cBorder

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                width: 24
                height: 24
                text: "↻"
                color: root.style.cTextOnSurface
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Column {
                width: parent.width - 44
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: root.latestVersionText.length > 0
                          ? "发现新版本 " + root.latestVersionText
                          : "发现新版本"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: "点击查看更新内容"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }
    }
}
