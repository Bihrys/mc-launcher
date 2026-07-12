import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls"

// Port of HMCL GameListPage's left region:
// game-directory list, "new game directory", then the fixed three-row drawer.
Item {
    id: root

    property var style
    property var profileModel

    signal profileSelected(string profileId)
    signal newDirectoryRequested()
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
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                width: root.width
                spacing: 0

                Repeater {
                    model: root.profileModel

                    delegate: AdvancedListItem {
                        required property string profileId
                        required property string profileName
                        required property string profilePath
                        required property bool profileSelected

                        width: root.width
                        style: root.style
                        title: profileName
                        subtitle: profilePath
                        iconKind: "DRESSER"
                        selected: profileSelected
                        onClicked: root.profileSelected(profileId)
                    }
                }

                AdvancedListItem {
                    width: root.width
                    style: root.style
                    title: "新建游戏目录"
                    iconKind: "ADD_CIRCLE"
                    onClicked: root.newDirectoryRequested()
                }
            }
        }

        // HMCL: 40 * 3 + 12 * 2 = 144 px.
        AdvancedListBox {
            Layout.fillWidth: true
            Layout.preferredHeight: 144
            style: root.style
            topPadding: 12
            bottomPadding: 12

            AdvancedListItem {
                style: root.style
                title: "安装新游戏"
                iconKind: "ADD_CIRCLE"
                onClicked: root.installRequested()
            }
            AdvancedListItem {
                style: root.style
                title: "导入整合包"
                iconKind: "PACKAGE2"
                onClicked: root.importRequested()
            }
            AdvancedListItem {
                style: root.style
                title: "全局游戏设置"
                iconKind: "SETTINGS"
                onClicked: root.globalSettingsRequested()
            }
        }
    }
}
