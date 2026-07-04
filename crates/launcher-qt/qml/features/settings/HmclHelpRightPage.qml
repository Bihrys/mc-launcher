import QtQuick
import "../../Hmcl/controls" as Hmcl

Column {
    id: root
    property var style
    property var backend
    property var settingsPage
    width: parent ? parent.width : 800
    spacing: 10

    HmclSettingTitle { style: root.style; title: "帮助" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclButtonLine { style: root.style; title: "HMCL 帮助文档"; buttonText: "打开"; onAction: root.backend.openUrl("https://docs.hmcl.net/") }
        HmclButtonLine { style: root.style; title: "Minecraft Wiki"; buttonText: "打开"; onAction: root.backend.openUrl("https://minecraft.wiki/") }
        HmclButtonLine { style: root.style; title: "打开配置目录"; buttonText: "打开"; onAction: root.backend.openLauncherSpecialFolder("config") }
    }
}
