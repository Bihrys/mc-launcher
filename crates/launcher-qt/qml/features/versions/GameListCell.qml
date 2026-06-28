import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls"

// 实例列表的单行 delegate（对齐 HMCL GameListCell）。
// 作为 ListView 的 delegate，数据字段用 required property 直接绑定 GameListModel 的角色，
// 不经过 JSON。
MDListCell {
    id: root

    // —— 来自 GameListModel 的角色（ListView 自动按名绑定）——
    required property string instanceId
    required property string title
    required property string subtitle
    required property string tag
    required property string iconName
    required property bool selected
    required property bool canUpdate

    // —— 由页面显式注入 ——
    property string iconBase: ""

    signal selectRequested()
    signal openRequested()
    signal launchRequested()
    signal updateRequested()
    signal manageRequested(real x, real y)

    height: 49
    implicitHeight: 49

    // 单击行 -> 打开实例详情（HMCL: modifyGameSettings）。
    onClicked: root.openRequested()

    // 选中态背景（HMCL secondary-container）。
    Rectangle {
        anchors.fill: parent
        z: -1
        visible: root.selected
        color: root.styleValue("cNavSelected", "transparent")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        RadioButton {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            checked: root.selected
            style: root.style
            onClicked: root.selectRequested()
        }

        Image {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            fillMode: Image.PreserveAspectFit
            smooth: false
            sourceSize.width: 32
            sourceSize.height: 32
            source: root.iconBase + (root.iconName.length > 0 ? root.iconName : "grass") + ".png"
        }

        TwoLineListItem {
            Layout.fillWidth: true
            title: root.title
            subtitle: root.subtitle
            tag: root.tag
            style: root.style
        }

        ToolbarButton {
            visible: root.canUpdate
            style: root.style
            iconKind: "UPDATE"
            onClicked: root.updateRequested()
        }

        ToolbarButton {
            style: root.style
            iconKind: "ROCKET_LAUNCH"
            onClicked: root.launchRequested()
        }

        ToolbarButton {
            id: menuButton
            style: root.style
            iconKind: "MENU"
            onClicked: {
                var p = menuButton.mapToItem(root, menuButton.width / 2, menuButton.height)
                root.manageRequested(p.x, p.y)
            }
        }
    }

    // 右键任意位置弹出上下文菜单（HMCL: SECONDARY 按钮）。左键不被此区域接收，
    // 会穿透到下方的行点击与各按钮。
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: function(mouse) {
            root.manageRequested(mouse.x, mouse.y)
        }
    }
}
