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

    HmclSettingTitle { style: root.style; title: "启动器主题" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclSelectLine { style: root.style; title: "主题包"; value: root.st("themePack", "default"); options: [{"text":"默认","value":"default"},{"text":"自定义","value":"custom"}]; onSelected: function(v) { root.set("themePack", v) } }
        HmclButtonLine { style: root.style; title: "导出主题包"; buttonText: "导出"; onAction: root.backend.openLauncherSpecialFolder("config") }
    }

    HmclSettingTitle { style: root.style; title: "外观" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclSelectLine { style: root.style; title: "亮度"; value: root.st("themeMode", root.st("themeBrightness", "auto")); options: [{"text":"跟随系统","value":"system"},{"text":"浅色","value":"light"},{"text":"深色","value":"dark"}]; onSelected: function(v) { root.set("themeMode", v); if (settingsPage) settingsPage.themeSelected(v) } }
        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "主题色"
            hasSubtitle: true
            subtitle: colorDisplay(root.st("themeColor", "default"))
            trailingText: colorDisplay(root.st("themeColor", "default"))
            HmclSelectLine { style: root.style; title: "主题色"; value: root.st("themeColor", "default"); options: [{"text":"默认","value":"default"},{"text":"紫色","value":"purple"},{"text":"蓝色","value":"blue"},{"text":"绿色","value":"green"},{"text":"红色","value":"red"},{"text":"橙色","value":"orange"}]; onSelected: function(v) { root.set("themeColor", v); if (settingsPage) settingsPage.themeColorSelected(v) } }
            HmclSelectLine { style: root.style; title: "主题色样式"; value: root.st("themeColorStyle", "system"); options: [{"text":"跟随系统","value":"system"},{"text":"鲜艳","value":"vibrant"},{"text":"中性","value":"neutral"}]; onSelected: function(v) { root.set("themeColorStyle", v) } }
        }
        HmclToggleLine { style: root.style; title: "标题栏透明"; checkedValue: root.sb("titleTransparent", false); onChangedValue: function(v) { root.setb("titleTransparent", v) } }
    }

    HmclSettingTitle { style: root.style; title: "启动器背景" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "启动器背景"
            hasSubtitle: true
            subtitle: backgroundDisplay(root.st("backgroundType", "default"))
            trailingText: backgroundDisplay(root.st("backgroundType", "default"))
            HmclSelectLine { style: root.style; title: "背景类型"; value: root.st("backgroundType", "default"); options: [{"text":"默认","value":"default"},{"text":"经典","value":"classic"},{"text":"自定义图片","value":"custom"},{"text":"网络图片","value":"network"},{"text":"纯色","value":"paint"}]; onSelected: function(v) { root.set("backgroundType", v) } }
            HmclTextLine { style: root.style; title: "自定义图片路径"; valueText: root.st("backgroundImage", ""); enabledRow: root.st("backgroundType", "default") === "custom"; onAccepted: function(v) { root.set("backgroundImage", v) } }
            HmclTextLine { style: root.style; title: "网络图片地址"; valueText: root.st("backgroundImageUrl", ""); enabledRow: root.st("backgroundType", "default") === "network"; onAccepted: function(v) { root.set("backgroundImageUrl", v) } }
            HmclTextLine { style: root.style; title: "纯色背景"; valueText: root.st("backgroundPaint", ""); enabledRow: root.st("backgroundType", "default") === "paint"; onAccepted: function(v) { root.set("backgroundPaint", v) } }
            HmclSliderLine { style: root.style; title: "背景透明度"; fromValue: 0; toValue: 100; valueNumber: Number(root.st("backgroundOpacity", "1")) * 100; suffix: "%"; onMovedValue: function(v) { root.set("backgroundOpacity", String(Math.round(v) / 100)) } }
        }
        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "后备背景"
            hasSubtitle: true
            subtitle: backgroundDisplay(root.st("fallbackBackgroundType", "default"))
            trailingText: backgroundDisplay(root.st("fallbackBackgroundType", "default"))
            HmclSelectLine { style: root.style; title: "后备背景类型"; value: root.st("fallbackBackgroundType", "default"); options: [{"text":"默认","value":"default"},{"text":"经典","value":"classic"},{"text":"纯色","value":"paint"}]; onSelected: function(v) { root.set("fallbackBackgroundType", v) } }
            HmclSelectLine { style: root.style; title: "背景加载策略"; value: root.st("backgroundLoadPolicy", "async"); options: [{"text":"异步加载","value":"async"},{"text":"立即加载","value":"immediate"},{"text":"禁用网络背景","value":"disable_network"}]; onSelected: function(v) { root.set("backgroundLoadPolicy", v) } }
        }
    }

    HmclSettingTitle { style: root.style; title: "动画" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclToggleLine { style: root.style; title: "关闭动画"; subtitle: "重启后生效。"; checkedValue: root.sb("turnOffAnimations", false); onChangedValue: function(v) { root.setb("turnOffAnimations", v) } }
    }

    HmclSettingTitle { style: root.style; title: "字体" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclTextLine { style: root.style; title: "全局字体"; valueText: root.st("globalFontFamily", ""); onAccepted: function(v) { root.set("globalFontFamily", v) } }
        HmclTextLine { style: root.style; title: "日志字体"; valueText: root.st("logFontFamily", "monospace"); onAccepted: function(v) { root.set("logFontFamily", v) } }
        HmclTextLine { style: root.style; title: "日志字号"; valueText: root.st("logFontSize", "12"); onAccepted: function(v) { root.set("logFontSize", v) } }
        HmclSelectLine { style: root.style; title: "字体抗锯齿"; value: root.st("fontAntiAliasing", "auto"); options: [{"text":"自动","value":"auto"},{"text":"开启","value":"on"},{"text":"关闭","value":"off"}]; onSelected: function(v) { root.set("fontAntiAliasing", v) } }
    }

    function backgroundDisplay(value) {
        if (value === "classic") return "经典"
        if (value === "custom") return "自定义图片"
        if (value === "network") return "网络图片"
        if (value === "paint") return "纯色"
        return "默认"
    }

    function colorDisplay(value) {
        if (value === "purple") return "紫色"
        if (value === "blue") return "蓝色"
        if (value === "green") return "绿色"
        if (value === "red") return "红色"
        if (value === "orange") return "橙色"
        return "默认"
    }
}
