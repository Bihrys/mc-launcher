import QtQuick
import "../../Hmcl/controls" as Hmcl

Column {
    id: root
    property var style
    property var backend
    property var settingsPage
    width: parent ? parent.width : 800
    spacing: 10

    HmclSettingTitle { style: root.style; title: "反馈" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclButtonLine { style: root.style; title: "提交 Issue"; buttonText: "打开"; onAction: root.backend.openUrl("https://github.com/HMCL-dev/HMCL/issues") }
        HmclButtonLine { style: root.style; title: "导出诊断信息"; buttonText: "导出"; onAction: root.backend.exportLauncherDiagnostics() }
    }
}
