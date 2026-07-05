import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl

Column {
    id: root

    property var style
    property var backend
    property var settingsPage
    property var appearanceOptions: ({"fonts": [], "builtinBackgrounds": [], "standardThemeColors": []})

    width: parent ? parent.width : 800
    spacing: 10

    Component.onCompleted: root.reloadAppearanceOptions()

    function reloadAppearanceOptions() {
        if (!root.backend || root.backend.refreshAppearanceOptions === undefined)
            return
        try {
            root.appearanceOptions = JSON.parse(root.backend.refreshAppearanceOptions() || "{}")
        } catch (e) {
            root.appearanceOptions = {"fonts": [], "builtinBackgrounds": [], "standardThemeColors": []}
        }
    }

    function st(key, fallback) { return settingsPage ? settingsPage.settingText(key, fallback) : String(fallback || "") }
    function sb(key, fallback) { return settingsPage ? settingsPage.settingBool(key, fallback) : !!fallback }
    function set(key, value) { if (settingsPage) settingsPage.setSetting(key, String(value)) }
    function setb(key, value) { if (settingsPage) settingsPage.setBool(key, value) }

    function themeModeValue() {
        var v = root.st("themeBrightnessMode", root.st("themeMode", "auto"))
        if (v === "system") return "auto"
        return v
    }

    function themeModeText(value) {
        if (value === "light") return "浅色模式"
        if (value === "dark") return "深色模式"
        return "跟随系统"
    }

    function colorTypeText(value) {
        if (value === "custom") return "自定义"
        if (value === "background") return "跟随背景图片"
        return "默认"
    }

    function backgroundText(value) {
        if (value === "builtin") return root.st("builtinBackgroundId", "2021-08-26")
        if (value === "custom") return root.st("customBackgroundImagePath", root.st("backgroundImage", "自定义"))
        if (value === "network") return root.st("networkBackgroundImageUrl", root.st("backgroundImageUrl", "网络"))
        if (value === "paint") return root.st("customBackgroundPaint", root.st("backgroundPaint", "纯色"))
        return "默认"
    }

    function builtinOptions() {
        var src = root.appearanceOptions.builtinBackgrounds || []
        var out = []
        for (var i = 0; i < src.length; ++i)
            out.push({"text": String(src[i].title || src[i].id), "value": String(src[i].id)})
        if (out.length === 0) {
            out.push({"text":"2021-08-26","value":"2021-08-26"})
            out.push({"text":"2016-02-25","value":"2016-02-25"})
            out.push({"text":"2015-06-22","value":"2015-06-22"})
        }
        return out
    }

    function fontOptions(includeDefault) {
        var out = includeDefault ? [{"text":"默认","value":""}] : []
        var src = root.appearanceOptions.fonts || []
        for (var i = 0; i < src.length; ++i)
            out.push({"text": String(src[i]), "value": String(src[i])})
        if (out.length <= (includeDefault ? 1 : 0)) {
            out.push({"text":"Noto Sans CJK SC","value":"Noto Sans CJK SC"})
            out.push({"text":"Sans Serif","value":"Sans Serif"})
            out.push({"text":"Monospace","value":"monospace"})
        }
        return out
    }

    HmclSettingTitle { style: root.style; title: "外观" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "主题模式"
            value: root.themeModeValue()
            options: [
                {"text":"跟随系统","value":"auto"},
                {"text":"浅色模式","value":"light"},
                {"text":"深色模式","value":"dark"}
            ]
            onSelected: function(v) {
                root.set("themeBrightnessMode", v)
                root.set("themeMode", v === "auto" ? "system" : v)
                if (settingsPage) settingsPage.themeSelected(v === "auto" ? "system" : v)
            }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "主题色"
            hasSubtitle: false
            trailingText: root.colorTypeText(root.st("themeColorType", "default"))

            HmclThemeColorChoiceList {
                width: parent.width
                style: root.style
                value: root.st("themeColorType", "default")
                colorValue: root.st("customThemeColor", root.st("themeColor", "#5C6BC0"))
                standardColors: root.appearanceOptions.standardThemeColors || []
                onSelected: function(v) {
                    root.set("themeColorType", v)
                    if (v === "default") {
                        root.set("themeColor", "default")
                        if (settingsPage) settingsPage.themeColorSelected("default")
                    } else if (v === "background") {
                        root.set("themeColor", "background")
                    } else if (v === "custom") {
                        var color = root.st("customThemeColor", root.st("themeColor", "#5C6BC0"))
                        if (color === "default" || color === "background" || color.length === 0)
                            color = "#5C6BC0"
                        root.set("themeColor", color)
                        if (settingsPage) settingsPage.themeColorSelected(color)
                    }
                }
                onColorSelected: function(v) {
                    root.set("themeColorType", "custom")
                    root.set("customThemeColor", v)
                    root.set("themeColor", v)
                    if (settingsPage) settingsPage.themeColorSelected(v)
                }
            }
        }

        HmclToggleLine {
            style: root.style
            title: "标题栏透明"
            checkedValue: root.sb("titleTransparent", false)
            onChangedValue: function(v) { root.setb("titleTransparent", v) }
        }

        HmclToggleLine {
            style: root.style
            title: "关闭动画"
            subtitle: "重启后生效"
            checkedValue: root.sb("animationDisabled", root.sb("turnOffAnimations", false))
            onChangedValue: function(v) { root.setb("animationDisabled", v); root.setb("turnOffAnimations", v) }
        }
    }

    HmclSettingTitle { style: root.style; title: "背景图片" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclChoiceList {
            width: parent.width
            style: root.style
            value: root.st("backgroundType", "default")
            options: [
                {"text":"默认","value":"default"},
                {"text":"经典","value":"builtin"},
                {"text":"自定义","value":"custom"},
                {"text":"网络","value":"network"},
                {"text":"纯色","value":"paint"}
            ]
            onSelected: function(v) { root.set("backgroundType", v) }
        }

        HmclSelectLine {
            style: root.style
            title: "经典背景"
            enabledRow: root.st("backgroundType", "default") === "builtin"
            value: root.st("builtinBackgroundId", "2021-08-26")
            options: root.builtinOptions()
            onSelected: function(v) {
                root.set("builtinBackgroundId", v)
                root.set("backgroundType", "builtin")
            }
        }

        HmclTextLine {
            style: root.style
            title: "自定义"
            valueText: root.st("customBackgroundImagePath", root.st("backgroundImage", ""))
            enabledRow: root.st("backgroundType", "default") === "custom"
            onAccepted: function(v) {
                root.set("customBackgroundImagePath", v)
                root.set("backgroundImage", v)
                root.set("backgroundType", "custom")
            }
        }

        HmclTextLine {
            style: root.style
            title: "网络"
            valueText: root.st("networkBackgroundImageUrl", root.st("backgroundImageUrl", ""))
            enabledRow: root.st("backgroundType", "default") === "network"
            onAccepted: function(v) {
                root.set("networkBackgroundImageUrl", v)
                root.set("backgroundImageUrl", v)
                root.set("backgroundType", "network")
            }
        }

        HmclTextLine {
            style: root.style
            title: "纯色"
            valueText: root.st("customBackgroundPaint", root.st("backgroundPaint", ""))
            placeholderText: "#FFFFFF"
            enabledRow: root.st("backgroundType", "default") === "paint"
            onAccepted: function(v) {
                root.set("customBackgroundPaint", v)
                root.set("backgroundPaint", v)
                root.set("backgroundType", "paint")
            }
        }

        HmclSliderLine {
            style: root.style
            title: "不透明度"
            fromValue: 0
            toValue: 100
            valueNumber: Number(root.st("backgroundOpacity", "1")) * 100
            suffix: "%"
            onMovedValue: function(v) {
                var snapped = Math.round(v / 5) * 5
                root.set("backgroundOpacity", String(snapped / 100))
            }
        }
    }

    HmclSettingTitle { style: root.style; title: "日志" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "日志字体"
            value: root.st("logFontFamily", root.st("logFont", "monospace"))
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
            fontFamily: root.st("logFontFamily", root.st("logFont", "monospace"))
            fontSize: Number(root.st("logFontSize", "12"))
        }
    }

    HmclSettingTitle { style: root.style; title: "字体" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "字体"
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
            title: "抗锯齿"
            subtitle: "重启后生效"
            value: root.st("fontAntiAliasing", "auto")
            options: [
                {"text":"自动","value":"auto"},
                {"text":"LCD","value":"lcd"},
                {"text":"灰度","value":"gray"}
            ]
            onSelected: function(v) { root.set("fontAntiAliasing", v) }
        }
    }
}
