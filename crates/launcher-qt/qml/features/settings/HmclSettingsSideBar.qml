import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl

Item {
    id: root

    required property var style
    property string currentSection: "global"

    signal sectionSelected(string section)

    Hmcl.AdvancedListBox {
        anchors.fill: parent
        style: root.style

        // 对应 HMCL LauncherSettingsPage.java：AdvancedListBox
        // FXUtils.setLimitWidth(sideBar, 200)
        Hmcl.AdvancedListItem {
            style: root.style
            title: "全局游戏设置"
            iconKind: "STADIA_CONTROLLER"
            selectedIconKind: "STADIA_CONTROLLER_FILL"
            selected: root.currentSection === "global"
            onClicked: root.sectionSelected("global")
        }

        Hmcl.AdvancedListItem {
            style: root.style
            title: "Java 管理"
            iconKind: "LOCAL_CAFE"
            selectedIconKind: "LOCAL_CAFE_FILL"
            selected: root.currentSection === "java"
            onClicked: root.sectionSelected("java")
        }

        Hmcl.ClassTitle {
            style: root.style
            title: "启动器"
        }

        Hmcl.AdvancedListItem {
            style: root.style
            title: "通用"
            iconKind: "TUNE"
            selected: root.currentSection === "general"
            onClicked: root.sectionSelected("general")
        }

        Hmcl.AdvancedListItem {
            style: root.style
            title: "外观"
            iconKind: "STYLE"
            selectedIconKind: "STYLE_FILL"
            selected: root.currentSection === "appearance"
            onClicked: root.sectionSelected("appearance")
        }

        Hmcl.AdvancedListItem {
            style: root.style
            title: "下载"
            iconKind: "DOWNLOAD"
            selected: root.currentSection === "download"
            onClicked: root.sectionSelected("download")
        }

        Hmcl.ClassTitle {
            style: root.style
            title: "帮助"
        }

        Hmcl.AdvancedListItem {
            style: root.style
            title: "帮助"
            iconKind: "HELP"
            selectedIconKind: "HELP_FILL"
            selected: root.currentSection === "help"
            onClicked: root.sectionSelected("help")
        }

        Hmcl.AdvancedListItem {
            style: root.style
            title: "反馈"
            iconKind: "FEEDBACK"
            selectedIconKind: "FEEDBACK_FILL"
            selected: root.currentSection === "feedback"
            onClicked: root.sectionSelected("feedback")
        }

        Hmcl.AdvancedListItem {
            style: root.style
            title: "关于"
            iconKind: "INFO"
            selectedIconKind: "INFO_FILL"
            selected: root.currentSection === "about"
            onClicked: root.sectionSelected("about")
        }
    }
}
