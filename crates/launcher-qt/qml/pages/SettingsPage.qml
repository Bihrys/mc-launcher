import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    property string themeMode: "light"

    signal themeSelected(string mode)

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 18

        Text {
            text: "启动器设置"
            color: root.style.cTextOnSurface
            font.pixelSize: 24
            font.bold: true
        }

        Rectangle {
            width: Math.min(parent.width, 720)
            height: 86
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 18

                Column {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "启动器主题"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Text {
                        text: "选择浅色、深色，或跟随系统外观。"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 8

                    ThemeOption {
                        style: root.style
                        text: "浅色"
                        mode: "light"
                        selected: root.themeMode === "light"
                        onClicked: root.themeSelected(mode)
                    }

                    ThemeOption {
                        style: root.style
                        text: "深色"
                        mode: "dark"
                        selected: root.themeMode === "dark"
                        onClicked: root.themeSelected(mode)
                    }

                    ThemeOption {
                        style: root.style
                        text: "跟随系统"
                        mode: "system"
                        selected: root.themeMode === "system"
                        onClicked: root.themeSelected(mode)
                    }
                }
            }
        }
    }

    component ThemeOption: Rectangle {
        id: option

        required property var style
        property string text: ""
        property string mode: ""
        property bool selected: false

        signal clicked(string mode)

        width: text === "跟随系统" ? 92 : 62
        height: 34
        radius: 17

        color: selected
               ? style.cButtonSelected
               : optionMouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: selected ? 0 : 1
        border.color: style.cBorder

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            text: option.text
            color: option.selected ? option.style.cButtonSelectedText : option.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: option.selected
        }

        MouseArea {
            id: optionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: option.clicked(option.mode)
        }
    }
}
