import QtQuick
import "../../Hmcl/controls"

// 实例右键菜单（对齐 HMCL GameListCell 的 PopupMenu）。
// 顺序：测试启动 / 生成启动脚本 | 管理 | 重命名 / 复制 / 删除 / 导出 | 游戏文件夹
PopupMenu {
    id: root

    property var style
    property string instanceId: ""

    signal testLaunchRequested()
    signal scriptRequested()
    signal manageRequested()
    signal renameRequested()
    signal duplicateRequested()
    signal deleteRequested()
    signal exportRequested()
    signal selectRequested()
    signal folderRequested()

    Column {
        anchors.left: parent.left
        anchors.right: parent.right

        IconedMenuItem { style: root.style; title: "测试启动"; iconKind: "ROCKET_LAUNCH"; onClicked: root.testLaunchRequested() }
        IconedMenuItem { style: root.style; title: "生成启动脚本"; iconKind: "SCRIPT"; onClicked: root.scriptRequested() }

        MenuSeparator { style: root.style }

        IconedMenuItem { style: root.style; title: "管理"; iconKind: "SETTINGS"; onClicked: root.manageRequested() }

        MenuSeparator { style: root.style }

        IconedMenuItem { style: root.style; title: "重命名"; iconKind: "EDIT"; onClicked: root.renameRequested() }
        IconedMenuItem { style: root.style; title: "复制"; iconKind: "FOLDER_COPY"; onClicked: root.duplicateRequested() }
        IconedMenuItem { style: root.style; title: "删除"; iconKind: "DELETE"; onClicked: root.deleteRequested() }
        IconedMenuItem { style: root.style; title: "导出"; iconKind: "OUTPUT"; onClicked: root.exportRequested() }

        MenuSeparator { style: root.style }

        IconedMenuItem { style: root.style; title: "游戏文件夹"; iconKind: "FOLDER_OPEN"; onClicked: root.folderRequested() }
    }

    component MenuSeparator: Item {
        required property var style
        width: parent ? parent.width : 188
        height: 9

        function styleValue(name, fallback) {
            if (style !== undefined && style !== null) {
                var v = style[name]
                if (v !== undefined && v !== null) return v
            }
            return fallback
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: parent.styleValue("cBorder", "#dddddd")
        }
    }
}
