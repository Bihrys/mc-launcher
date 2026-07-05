import QtQuick
import "../../Hmcl/controls" as Hmcl

Column {
    id: root
    property var style
    property var backend
    property var settingsPage
    width: parent ? parent.width : 800
    spacing: 10

    HmclSettingTitle { style: root.style; title: "关于" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclInfoLine { style: root.style; title: "启动器"; valueText: "mc-launcher" }
        HmclInfoLine { style: root.style; title: "版本"; valueText: "0.1.0" }
        HmclInfoLine { style: root.style; title: "架构"; valueText: "Rust + Qt/QML" }
        HmclButtonLine { style: root.style; title: "项目仓库"; buttonText: "打开"; onAction: root.backend.openUrl("https://github.com/HMCL-dev/HMCL") }
    }
}
