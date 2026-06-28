import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls"
import "../../components"

Item {
    id: root
    property var style
    property var profileModel
    signal installRequested()
    signal importRequested()
    signal globalSettingsRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: root.style.sidebarWidthValue
                Item { width: 1; height: 12 }
                ClassTitle { style: root.style; title: "游戏目录" }
                Repeater {
                    model: root.profileModel
                    delegate: AdvancedListItem {
                        required property string profileName
                        required property string profilePath
                        style: root.style
                        title: profileName
                        subtitle: profilePath
                        iconKind: "DRESSER"
                    }
                }
                AdvancedListItem { style: root.style; title: "新建游戏目录"; iconKind: "ADD_CIRCLE" }
            }
        }

        AdvancedListBox {
            Layout.fillWidth: true
            Layout.preferredHeight: 40 * 3 + 24
            style: root.style
            AdvancedListItem { style: root.style; title: "安装新游戏"; iconKind: "ADD_CIRCLE"; onClicked: root.installRequested() }
            AdvancedListItem { style: root.style; title: "导入整合包"; iconKind: "PACKAGE2"; onClicked: root.importRequested() }
            AdvancedListItem { style: root.style; title: "全局游戏设置"; iconKind: "SETTINGS"; onClicked: root.globalSettingsRequested() }
        }
    }
}
