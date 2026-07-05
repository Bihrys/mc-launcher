pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.bihrys.launcher
import "../../components"
import "../../Hmcl/controls"

// 主页（对齐 HMCL MainPage）。
//
// 中心大留白；右上角更新气泡（滑入动画）；右下角的启动按钮由 RootShell 叠加。
// 菜单键弹出“实例快速切换”列表（对齐 HMCL GameListPopupMenu）：图标 + 标题 + 副标题 + tag，
// 点击即切换当前实例并关闭。数据来自真模型 GameListModel（无 JSON.parse）；
// 切换走 backend.selectInstance 以同步 selectedGameVersion（启动按钮副标题）。
Item {
    id: root

    required property var style
    required property var backend

    property bool showUpdateBubble: false
    property string latestVersionText: ""

    readonly property string iconBase: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/"

    // 供 RootShell 在菜单键点击时调用。x/y 为相对本页的弹出锚点（按钮左上）。
    function openQuickSwitch(x, y) {
        gameListModel.refresh()
        var w = quickSwitch.width
        var h = quickSwitch.height
        quickSwitch.x = Math.max(8, Math.min(x - w, root.width - w - 8))
        quickSwitch.y = Math.max(8, Math.min(y - h, root.height - h - 8))
        quickSwitch.visible = true
    }

    GameListModel { id: gameListModel }

    // —— 更新气泡（HMCL: 右上角，滑入）——
    Rectangle {
        id: updatePane

        visible: root.showUpdateBubble
        width: 230
        height: 55
        radius: 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        color: root.style.cInverseSurfaceTransparent80
        border.width: 0
        border.color: "transparent"

        // HMCL doAnimation：从右侧 260px 滑入。
        transform: Translate {
            id: bubbleShift
            x: root.showUpdateBubble ? 0 : 260
            Behavior on x {
                NumberAnimation {
                    duration: root.style.animationsEnabled ? root.style.motionMedium3 : 0
                    easing.type: Easing.OutSine
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 10

            HmclSvgIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                icon: "UPDATE"
                iconSize: 20
                iconColor: root.style.cInverseOnSurface
                animationsEnabled: root.style.animationsEnabled
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.latestVersionText.length > 0 ? "发现更新：" + root.latestVersionText : "发现更新"
                    color: root.style.cInverseOnSurface
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: "点击此处进行升级"
                    color: root.style.cInverseOnSurface
                    opacity: 0.86
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            ToolbarButton {
                style: root.style
                iconKind: "CLOSE"
                iconColor: root.style.cInverseOnSurface
                onClicked: root.showUpdateBubble = false
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backend.output = "检查更新功能稍后接入。"
        }
    }

    // —— 实例快速切换弹窗（HMCL GameListPopupMenu）——
    // 点击页面其它位置关闭。
    MouseArea {
        anchors.fill: parent
        visible: quickSwitch.visible
        z: 900
        acceptedButtons: Qt.AllButtons
        onClicked: quickSwitch.visible = false
    }

    Rectangle {
        id: quickSwitch

        visible: false
        z: 901
        width: 300
        height: Math.min(365, Math.max(52, switchList.contentHeight + 2))
        radius: 4
        color: root.style.cSurface
        border.width: 1
        border.color: root.style.cBorder
        clip: true

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        // 空态占位（对齐 HMCL version.empty）。
        Text {
            anchors.centerIn: parent
            visible: gameListModel.isEmpty
            text: "还没有任何实例"
            color: root.style.cTextOnSurfaceVariant
            font.pixelSize: 12
            font.italic: true
        }

        ListView {
            id: switchList
            anchors.fill: parent
            visible: !gameListModel.isEmpty
            clip: true
            model: gameListModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                id: switchCell

                required property string instanceId
                required property string title
                required property string subtitle
                required property string tag
                required property string iconName
                required property bool selected

                width: switchList.width
                height: 50

                Rectangle {
                    anchors.fill: parent
                    color: switchMouse.containsMouse
                           ? root.style.cButtonHover
                           : (switchCell.selected ? root.style.cNavSelected : "transparent")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        sourceSize.width: 32
                        sourceSize.height: 32
                        source: root.iconBase + (switchCell.iconName.length > 0 ? switchCell.iconName : "grass") + ".png"
                    }

                    TwoLineListItem {
                        Layout.fillWidth: true
                        style: root.style
                        title: switchCell.title
                        subtitle: switchCell.subtitle
                        tag: switchCell.tag
                    }
                }

                MouseArea {
                    id: switchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.backend.selectInstance(switchCell.instanceId)
                        quickSwitch.visible = false
                    }
                }
            }
        }
    }
}
