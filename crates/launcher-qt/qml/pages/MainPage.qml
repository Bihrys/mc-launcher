import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        anchors.bottomMargin: 96
        spacing: 14

        Rectangle {
            width: Math.min(parent.width, 520)
            height: 108
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainerHigh

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Text {
                    text: "Hello Minecraft! Launcher 风格首页"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 19
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: "这是 Qt/QML 主界面壳。后续可以把账号、版本、下载、设置等页面逐步接入 Rust 后端。"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
        }

        Row {
            spacing: 10

            Button {
                text: "检测 Java"
                onClicked: root.backend.detectJava()
            }

            Button {
                text: "刷新版本"
                onClicked: console.log("refresh versions")
            }
        }

        Rectangle {
            width: Math.min(parent.width, 620)
            height: 230
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "后端输出"
                    color: root.style.cTextOnSurface
                    font.bold: true
                    font.pixelSize: 14
                }

                TextArea {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readOnly: true
                    wrapMode: TextEdit.Wrap
                    text: root.backend.output
                    placeholderText: "等待 Rust 后端输出..."
                }
            }
        }
    }
}
