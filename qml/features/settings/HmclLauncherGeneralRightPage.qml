import QtQuick
import "../../Hmcl/controls" as Hmcl

Column {
    id: root
    property var style
    property var backend
    property var settingsPage
    width: parent ? parent.width : 800
    spacing: 10

    function st(key, fallback) { return settingsPage ? settingsPage.settingText(key, fallback) : String(fallback || "") }
    function sb(key, fallback) { return settingsPage ? settingsPage.settingBool(key, fallback) : !!fallback }
    function set(key, value) { if (settingsPage) settingsPage.setSetting(key, String(value)) }
    function setb(key, value) { if (settingsPage) settingsPage.setBool(key, value) }

    HmclSettingTitle { style: root.style; title: "更新" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclButtonLine { style: root.style; title: "启动器更新"; subtitle: "检查当前启动器版本和更新信息。"; buttonText: "检查"; onAction: root.backend.openUrl("https://github.com/HMCL-dev/HMCL/releases") }
        HmclToggleLine { style: root.style; title: "接收预览版更新"; checkedValue: root.sb("acceptPreviewUpdate", false); onChangedValue: function(v) { root.setb("acceptPreviewUpdate", v) } }
        HmclToggleLine { style: root.style; title: "不自动弹出更新提示"; checkedValue: root.sb("disableAutoShowUpdateDialog", false); onChangedValue: function(v) { root.setb("disableAutoShowUpdateDialog", v) } }
    }

    HmclSettingTitle { style: root.style; title: "语言" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclSelectLine { style: root.style; title: "语言"; subtitle: "重启后生效。"; value: root.st("language", "zh_CN"); options: [{"text":"简体中文","value":"zh_CN"},{"text":"English","value":"en"},{"text":"한국어","value":"ko"},{"text":"日本語","value":"ja"}]; onSelected: function(v) { root.set("language", v) } }
    }

    HmclSettingTitle { style: root.style; title: "杂项" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclToggleLine { style: root.style; title: "禁用愚人节彩蛋"; subtitle: "重启后生效。"; checkedValue: root.sb("disableAprilFools", false); onChangedValue: function(v) { root.setb("disableAprilFools", v) } }
        HmclButtonGroupLine { style: root.style; title: "启动器日志"; firstText: "显示日志"; secondText: "导出日志"; onFirst: root.backend.openLauncherSpecialFolder("logs"); onSecond: root.backend.exportLauncherDiagnostics() }
    }
}
