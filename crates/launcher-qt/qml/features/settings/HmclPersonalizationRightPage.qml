import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl

Column {
    id: root

    property var style
    property var backend
    property var settingsPage
    property var appearanceOptions: ({"fonts": [], "builtinBackgrounds": []})

    width: parent ? parent.width : 800
    spacing: 10

    Component.onCompleted: root.reloadAppearanceOptions()

    function reloadAppearanceOptions() {
        if (!root.backend || root.backend.refreshAppearanceOptions === undefined)
            return
        try {
            root.appearanceOptions = JSON.parse(root.backend.refreshAppearanceOptions() || "{}")
        } catch (e) {
            root.appearanceOptions = {"fonts": [], "builtinBackgrounds": []}
        }
    }

    function st(key, fallback) { return settingsPage ? settingsPage.settingText(key, fallback) : String(fallback || "") }
    function sb(key, fallback) { return settingsPage ? settingsPage.settingBool(key, fallback) : !!fallback }
    function set(key, value) { if (settingsPage) settingsPage.setSetting(key, String(value)) }
    function setb(key, value) { if (settingsPage) settingsPage.setBool(key, value) }

    function overrides() {
        var raw = settingsPage ? settingsPage.settingsData["themeAppearanceOverrides"] : ""
        if (raw instanceof Array) return raw
        if (raw === undefined || raw === null) return []
        var out = []
        var parts = String(raw).split(",")
        for (var i = 0; i < parts.length; ++i) {
            var item = parts[i].trim()
            if (item.length > 0) out.push(item)
        }
        return out
    }

    function hasOverride(key) {
        var list = root.overrides()
        for (var i = 0; i < list.length; ++i)
            if (list[i] === key) return true
        return false
    }

    function setOverride(key, enabled) {
        var list = root.overrides()
        var found = -1
        for (var i = 0; i < list.length; ++i) {
            if (list[i] === key) { found = i; break }
        }
        if (enabled && found < 0) list.push(key)
        if (!enabled && found >= 0) list.splice(found, 1)
        root.set("themeAppearanceOverrides", list.join(","))
    }

    function brightnessText(value) {
        if (value === "light") return "浅色"
        if (value === "dark") return "深色"
        return "跟随系统"
    }

    function colorTypeText(value) {
        if (value === "custom") return "自定义"
        if (value === "background") return "跟随背景"
        return "默认"
    }

    function colorStyleText(value) {
        if (value === "vibrant") return "鲜艳"
        if (value === "neutral") return "中性"
        return "跟随系统"
    }

    function backgroundText(value) {
        if (value === "theme_color") return "主题色"
        if (value === "builtin") return root.st("builtinBackgroundId", "classic")
        if (value === "custom") return root.st("customBackgroundImagePath", root.st("backgroundImage", "自定义图片"))
        if (value === "network") return root.st("networkBackgroundImageUrl", root.st("backgroundImageUrl", "网络图片"))
        if (value === "paint") return root.st("customBackgroundPaint", root.st("backgroundPaint", "纯色"))
        return "默认"
    }

    function fallbackBackgroundText(value) {
        if (value === "theme_color") return "主题色"
        if (value === "paint") return root.st("backgroundFallbackPaint", "纯色")
        return "内置背景"
    }

    function loadPolicyText(value) {
        if (value === "show_fallback") return "先显示后备背景"
        return "等待背景加载"
    }

    function fontAntiAliasingText(value) {
        if (value === "lcd") return "LCD"
        if (value === "gray") return "灰度"
        return "自动"
    }

    function builtinOptions() {
        var src = root.appearanceOptions.builtinBackgrounds || []
        var out = []
        for (var i = 0; i < src.length; ++i) {
            out.push({"text": String(src[i].title || src[i].id), "value": String(src[i].id)})
        }
        if (out.length === 0) out.push({"text":"经典","value":"classic"})
        return out
    }

    function fontOptions(includeAuto) {
        var out = includeAuto ? [{"text":"默认","value":""}] : []
        var src = root.appearanceOptions.fonts || []
        for (var i = 0; i < src.length; ++i)
            out.push({"text": String(src[i]), "value": String(src[i])})
        if (out.length <= (includeAuto ? 1 : 0)) {
            out.push({"text":"Noto Sans CJK SC","value":"Noto Sans CJK SC"})
            out.push({"text":"Sans Serif","value":"Sans Serif"})
            out.push({"text":"Monospace","value":"monospace"})
        }
        return out
    }

    HmclSettingTitle { style: root.style; title: "启动器主题" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclButtonLine {
            style: root.style
            title: "主题包"
            subtitle: root.st("selectedThemeTitle", "默认")
            buttonText: "管理"
            onAction: {
                if (root.backend && root.backend.openLauncherSpecialFolder)
                    root.backend.openLauncherSpecialFolder("themes")
            }
        }

        HmclButtonLine {
            style: root.style
            title: "导出主题包"
            subtitle: "将当前启动器外观导出为主题包。"
            buttonText: "导出"
            onAction: {
                if (root.backend && root.backend.exportLauncherThemePack)
                    root.backend.exportLauncherThemePack()
            }
        }
    }

    HmclSettingTitle { style: root.style; title: "外观" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "亮度"
            value: root.st("themeBrightnessMode", root.st("themeMode", "auto"))
            options: [{"text":"跟随系统","value":"auto"},{"text":"浅色","value":"light"},{"text":"深色","value":"dark"}]
            onSelected: function(v) {
                root.set("themeBrightnessMode", v)
                root.set("themeMode", v === "auto" ? "system" : v)
                root.setOverride("brightness", true)
                if (settingsPage) settingsPage.themeSelected(v === "auto" ? "system" : v)
            }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "主题色"
            hasSubtitle: true
            subtitle: root.colorTypeText(root.st("themeColorType", "default"))
            trailingText: root.colorTypeText(root.st("themeColorType", "default"))
            titleRight: [
                HmclAppearanceOverrideButton {
                    style: root.style
                    overridden: root.hasOverride("color")
                    onClicked: root.setOverride("color", !root.hasOverride("color"))
                }
            ]

            HmclChoiceList {
                width: parent.width
                style: root.style
                value: root.st("themeColorType", "default")
                options: [
                    {"text":"默认","value":"default"},
                    {"text":"自定义","subtitle":"使用自定义主题色。","value":"custom"},
                    {"text":"跟随背景","value":"background"}
                ]
                onSelected: function(v) {
                    root.set("themeColorType", v)
                    root.setOverride("color", true)
                    if (v === "default") {
                        root.set("themeColor", "default")
                        if (settingsPage) settingsPage.themeColorSelected("default")
                    }
                }
            }

            HmclSelectLine {
                style: root.style
                title: "自定义主题色"
                enabledRow: root.st("themeColorType", "default") === "custom"
                value: root.st("themeColor", "default")
                options: [{"text":"默认","value":"default"},{"text":"紫色","value":"purple"},{"text":"蓝色","value":"blue"},{"text":"绿色","value":"green"},{"text":"红色","value":"red"},{"text":"橙色","value":"orange"}]
                onSelected: function(v) {
                    root.set("themeColor", v)
                    root.set("customThemeColor", v)
                    root.setOverride("color", true)
                    if (settingsPage) settingsPage.themeColorSelected(v)
                }
            }
        }

        HmclSelectLine {
            style: root.style
            title: "主题色样式"
            subtitle: root.colorStyleText(root.st("themeColorStyle", "system"))
            value: root.st("themeColorStyle", "system")
            options: [{"text":"跟随系统","value":"system"},{"text":"鲜艳","value":"vibrant"},{"text":"中性","value":"neutral"}]
            onSelected: function(v) {
                root.set("themeColorStyle", v)
                root.setOverride("color_style", true)
            }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "启动器背景"
            hasSubtitle: true
            subtitle: root.backgroundText(root.st("backgroundType", "default"))
            trailingText: root.backgroundText(root.st("backgroundType", "default"))
            titleRight: [
                HmclAppearanceOverrideButton {
                    style: root.style
                    overridden: root.hasOverride("background")
                    onClicked: root.setOverride("background", !root.hasOverride("background"))
                }
            ]

            HmclChoiceList {
                width: parent.width
                style: root.style
                value: root.st("backgroundType", "default")
                options: [
                    {"text":"默认","value":"default"},
                    {"text":"主题色","value":"theme_color"},
                    {"text":"内置背景","value":"builtin"},
                    {"text":"自定义图片","value":"custom"},
                    {"text":"网络图片","value":"network"},
                    {"text":"纯色","value":"paint"}
                ]
                onSelected: function(v) {
                    root.set("backgroundType", v)
                    root.setOverride("background", true)
                }
            }

            HmclSelectLine {
                style: root.style
                title: "内置背景"
                enabledRow: root.st("backgroundType", "default") === "builtin"
                value: root.st("builtinBackgroundId", "classic")
                options: root.builtinOptions()
                onSelected: function(v) { root.set("builtinBackgroundId", v); root.set("backgroundType", "builtin"); root.setOverride("background", true) }
            }

            HmclTextLine {
                style: root.style
                title: "自定义图片路径"
                valueText: root.st("customBackgroundImagePath", root.st("backgroundImage", ""))
                enabledRow: root.st("backgroundType", "default") === "custom"
                onAccepted: function(v) { root.set("customBackgroundImagePath", v); root.set("backgroundImage", v); root.set("backgroundType", "custom"); root.setOverride("background", true) }
            }

            HmclTextLine {
                style: root.style
                title: "网络图片地址"
                valueText: root.st("networkBackgroundImageUrl", root.st("backgroundImageUrl", ""))
                enabledRow: root.st("backgroundType", "default") === "network"
                onAccepted: function(v) { root.set("networkBackgroundImageUrl", v); root.set("backgroundImageUrl", v); root.set("backgroundType", "network"); root.setOverride("background", true) }
            }

            HmclTextLine {
                style: root.style
                title: "纯色背景"
                valueText: root.st("customBackgroundPaint", root.st("backgroundPaint", ""))
                placeholderText: "#F8F6FF"
                enabledRow: root.st("backgroundType", "default") === "paint"
                onAccepted: function(v) { root.set("customBackgroundPaint", v); root.set("backgroundPaint", v); root.set("backgroundType", "paint"); root.setOverride("background", true) }
            }
        }

        HmclSliderLine {
            style: root.style
            title: "背景透明度"
            fromValue: 0
            toValue: 100
            valueNumber: Number(root.st("backgroundOpacity", "1")) * 100
            suffix: "%"
            onMovedValue: function(v) {
                var snapped = Math.round(v / 5) * 5
                root.set("backgroundOpacity", String(snapped / 100))
                root.setOverride("background_opacity", true)
            }
        }

        HmclToggleLine {
            style: root.style
            title: "标题栏透明"
            checkedValue: root.sb("titleTransparent", false)
            onChangedValue: function(v) {
                root.setb("titleTransparent", v)
                root.setOverride("title_bar_transparent", true)
            }
        }
    }

    HmclSettingTitle { style: root.style; title: "背景加载" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclToggleLine {
            style: root.style
            title: "缓存网络背景"
            checkedValue: root.st("networkBackgroundImageCachePolicy", "enabled") !== "disabled"
            onChangedValue: function(v) { root.set("networkBackgroundImageCachePolicy", v ? "enabled" : "disabled") }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "后备背景"
            hasSubtitle: true
            subtitle: root.fallbackBackgroundText(root.st("backgroundFallbackType", "builtin"))
            trailingText: root.fallbackBackgroundText(root.st("backgroundFallbackType", "builtin"))

            HmclChoiceList {
                width: parent.width
                style: root.style
                value: root.st("backgroundFallbackType", "builtin")
                options: [{"text":"内置背景","value":"builtin"},{"text":"主题色","value":"theme_color"},{"text":"纯色","value":"paint"}]
                onSelected: function(v) { root.set("backgroundFallbackType", v) }
            }

            HmclTextLine {
                style: root.style
                title: "后备纯色背景"
                valueText: root.st("backgroundFallbackPaint", "")
                enabledRow: root.st("backgroundFallbackType", "builtin") === "paint"
                placeholderText: "#F8F6FF"
                onAccepted: function(v) { root.set("backgroundFallbackPaint", v); root.set("backgroundFallbackType", "paint") }
            }
        }

        HmclSelectLine {
            style: root.style
            title: "背景加载策略"
            value: root.st("backgroundLoadPolicy", "wait_for_background")
            options: [{"text":"等待背景加载","value":"wait_for_background"},{"text":"先显示后备背景","value":"show_fallback"}]
            onSelected: function(v) { root.set("backgroundLoadPolicy", v) }
        }
    }

    HmclSettingTitle { style: root.style; title: "动画" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclToggleLine {
            style: root.style
            title: "关闭动画"
            subtitle: "重启后生效。"
            checkedValue: root.sb("animationDisabled", root.sb("turnOffAnimations", false))
            onChangedValue: function(v) { root.setb("animationDisabled", v); root.setb("turnOffAnimations", v) }
        }
    }

    HmclSettingTitle { style: root.style; title: "字体" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "全局字体"
            value: root.st("launcherFontFamily", root.st("globalFontFamily", ""))
            options: root.fontOptions(true)
            onSelected: function(v) { root.set("launcherFontFamily", v); root.set("globalFontFamily", v) }
        }
        HmclFontPreviewLine {
            style: root.style
            text: "Hello Minecraft! Launcher"
            fontFamily: root.st("launcherFontFamily", root.st("globalFontFamily", ""))
            fontSize: 13
        }

        HmclSelectLine {
            style: root.style
            title: "日志字体"
            value: root.st("logFontFamily", "monospace")
            options: root.fontOptions(false)
            onSelected: function(v) { root.set("logFontFamily", v); root.set("logFont", v) }
        }
        HmclTextLine {
            style: root.style
            title: "日志字号"
            valueText: root.st("logFontSize", "12")
            onAccepted: function(v) { root.set("logFontSize", v) }
        }
        HmclFontPreviewLine {
            style: root.style
            text: "[23:33:33] [Client Thread/INFO] [WaterPower]: Loaded mod WaterPower."
            fontFamily: root.st("logFontFamily", "monospace")
            fontSize: Number(root.st("logFontSize", "12"))
        }

        HmclSelectLine {
            style: root.style
            title: "字体抗锯齿"
            subtitle: "重启后生效。"
            value: root.st("fontAntiAliasing", "auto")
            options: [{"text":"自动","value":"auto"},{"text":"LCD","value":"lcd"},{"text":"灰度","value":"gray"}]
            onSelected: function(v) { root.set("fontAntiAliasing", v) }
        }
    }
}
