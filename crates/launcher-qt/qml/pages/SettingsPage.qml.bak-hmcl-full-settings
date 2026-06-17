import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    property string themeMode: "light"
    property string launcherVisibility: "hide"

    signal themeSelected(string mode)
    signal launcherVisibilitySelected(string mode)

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

        SettingCard {
            width: Math.min(parent.width, 860)
            height: 86
            style: root.style
            title: "启动器主题"
            subtitle: "选择浅色、深色，或跟随系统外观。"

            Row {
                spacing: 8

                SelectOption {
                    style: root.style
                    text: "浅色"
                    mode: "light"
                    selected: root.themeMode === "light"
                    onClicked: root.themeSelected(mode)
                }

                SelectOption {
                    style: root.style
                    text: "深色"
                    mode: "dark"
                    selected: root.themeMode === "dark"
                    onClicked: root.themeSelected(mode)
                }

                SelectOption {
                    style: root.style
                    text: "跟随系统"
                    mode: "system"
                    selected: root.themeMode === "system"
                    widthOverride: 92
                    onClicked: root.themeSelected(mode)
                }
            }
        }

        SettingCard {
            width: Math.min(parent.width, 860)
            height: 118
            style: root.style
            title: "启动器可见性"
            subtitle: "对应 HMCL 的启动器可见性：关闭、隐藏、保持可见、隐藏并在游戏退出后重开。"

            Flow {
                width: 430
                spacing: 8

                SelectOption {
                    style: root.style
                    text: "启动后关闭"
                    mode: "close"
                    selected: root.launcherVisibility === "close"
                    widthOverride: 102
                    onClicked: root.launcherVisibilitySelected(mode)
                }

                SelectOption {
                    style: root.style
                    text: "启动后隐藏"
                    mode: "hide"
                    selected: root.launcherVisibility === "hide"
                    widthOverride: 102
                    onClicked: root.launcherVisibilitySelected(mode)
                }

                SelectOption {
                    style: root.style
                    text: "保持可见"
                    mode: "keep"
                    selected: root.launcherVisibility === "keep"
                    widthOverride: 88
                    onClicked: root.launcherVisibilitySelected(mode)
                }

                SelectOption {
                    style: root.style
                    text: "隐藏并重开"
                    mode: "hide_and_reopen"
                    selected: root.launcherVisibility === "hide_and_reopen"
                    widthOverride: 104
                    onClicked: root.launcherVisibilitySelected(mode)
                }
            }
        }
    }

    component SettingCard: Rectangle {
        id: card

        required property var style
        property string title: ""
        property string subtitle: ""
        default property alias content: contentSlot.data

        radius: style.radiusValue
        color: style.cSurfaceContainerHigh
        border.color: style.cBorder
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
                    text: card.title
                    color: card.style.cTextOnSurface
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: card.subtitle
                    color: card.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: contentSlot
                Layout.preferredWidth: 440
                Layout.fillHeight: true
            }
        }
    }

    component SelectOption: Rectangle {
        id: option

        required property var style
        property string text: ""
        property string mode: ""
        property bool selected: false
        property int widthOverride: 0

        signal clicked(string mode)

        width: widthOverride > 0 ? widthOverride : 62
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
