import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl
import "../../Hmcl/animation" as HmclAnim

Item {
    id: root

    required property var style
    required property var backend

    property string currentSection: "global"
    property string requestedSection: "global"
    property var settingsData: ({})
    property string themeMode: "light"
    property string themeColor: "default"
    property string launcherVisibility: "hide"
    property bool pageActive: false

    signal themeSelected(string mode)
    signal themeColorSelected(string color)
    signal launcherVisibilitySelected(string mode)

    Component.onCompleted: {
        if (root.requestedSection.length > 0)
            root.currentSection = root.requestedSection
        root.reloadSettings()
    }

    onRequestedSectionChanged: {
        if (root.requestedSection.length > 0)
            root.currentSection = root.requestedSection
    }

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    function reloadSettings() {
        var raw = root.backend.refreshLauncherSettings()
        try {
            root.settingsData = JSON.parse(raw || "{}")
        } catch (e) {
            root.settingsData = {}
        }
        root.themeMode = root.settingText("themeMode", "light")
        root.themeColor = root.settingText("themeColor", "default")
        root.launcherVisibility = root.settingText("launcherVisibility", "hide")
    }

    function setSetting(key, value) {
        var next = {}
        for (var k in root.settingsData)
            next[k] = root.settingsData[k]
        next[key] = value
        root.settingsData = next
        root.backend.updateLauncherSetting(key, String(value))
    }

    function settingText(key, fallback) {
        var value = root.settingsData[key]
        if (value === undefined || value === null || String(value).length === 0)
            return fallback === undefined ? "" : String(fallback)
        return String(value)
    }

    function settingBool(key, fallback) {
        var value = root.settingsData[key]
        if (value === undefined || value === null)
            return fallback === undefined ? false : fallback
        return value === true || value === "true"
    }

    function setBool(key, value) {
        root.setSetting(key, value ? "true" : "false")
    }

    function setThemeMode(value) {
        root.themeMode = value
        root.setSetting("themeMode", value)
        root.themeSelected(value)
    }

    function setThemeColor(value) {
        root.themeColor = value
        root.setSetting("themeColor", value)
        root.themeColorSelected(value)
    }

    function sectionComponentFor(section) {
        switch (section) {
        case "global": return globalSectionComponent
        case "java": return javaSectionComponent
        case "general": return generalSectionComponent
        case "appearance": return appearanceSectionComponent
        case "download": return downloadSectionComponent
        case "help": return helpSectionComponent
        case "feedback": return feedbackSectionComponent
        case "about": return aboutSectionComponent
        default: return generalSectionComponent
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Hmcl.AdvancedListBox {
            id: sideBar
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            style: root.style

            Hmcl.AdvancedListItem { style: root.style; title: "全局游戏设置"; iconKind: "STADIA_CONTROLLER"; selectedIconKind: "STADIA_CONTROLLER_FILL"; selected: root.currentSection === "global"; onClicked: root.currentSection = "global" }
            Hmcl.AdvancedListItem { style: root.style; title: "Java 管理"; iconKind: "LOCAL_CAFE"; selectedIconKind: "LOCAL_CAFE_FILL"; selected: root.currentSection === "java"; onClicked: root.currentSection = "java" }
            Hmcl.ClassTitle { style: root.style; title: "启动器" }
            Hmcl.AdvancedListItem { style: root.style; title: "通用"; iconKind: "TUNE"; selected: root.currentSection === "general"; onClicked: root.currentSection = "general" }
            Hmcl.AdvancedListItem { style: root.style; title: "外观"; iconKind: "STYLE"; selectedIconKind: "STYLE_FILL"; selected: root.currentSection === "appearance"; onClicked: root.currentSection = "appearance" }
            Hmcl.AdvancedListItem { style: root.style; title: "下载"; iconKind: "DOWNLOAD"; selected: root.currentSection === "download"; onClicked: root.currentSection = "download" }
            Hmcl.ClassTitle { style: root.style; title: "帮助" }
            Hmcl.AdvancedListItem { style: root.style; title: "帮助"; iconKind: "HELP"; selectedIconKind: "HELP_FILL"; selected: root.currentSection === "help"; onClicked: root.currentSection = "help" }
            Hmcl.AdvancedListItem { style: root.style; title: "反馈"; iconKind: "FEEDBACK"; selectedIconKind: "FEEDBACK_FILL"; selected: root.currentSection === "feedback"; onClicked: root.currentSection = "feedback" }
            Hmcl.AdvancedListItem { style: root.style; title: "关于"; iconKind: "INFO"; selectedIconKind: "INFO_FILL"; selected: root.currentSection === "about"; onClicked: root.currentSection = "about" }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScrollView {
                id: scroll
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth

                Item {
                    width: scroll.availableWidth
                    height: Math.max(scroll.height, contentLoader.item ? contentLoader.item.implicitHeight + 20 : 1)

                    Loader {
                        id: contentLoader
                        x: 10
                        y: 10
                        width: Math.max(1, parent.width - 20)
                        sourceComponent: root.sectionComponentFor(root.currentSection)
                    }
                }
            }
        }
    }

    Component {
        id: globalSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10
            SectionTitle { style: root.style; title: "全局游戏设置" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                InfoRow { style: root.style; title: "游戏设置"; subtitle: "HMCL 的全局游戏设置由 GameSettingsPage 负责。当前 Qt 端后续只按 GameSettingsPage.java 迁移，不再自行添加新的设置项。" }
                ButtonRow { style: root.style; title: "打开默认 Minecraft 目录"; buttonText: "打开"; onAction: root.backend.openLauncherSpecialFolder("minecraft") }
            }
        }
    }

    Component {
        id: javaSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10
            SectionTitle { style: root.style; title: "Java 管理" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                ButtonRow { style: root.style; title: "检测 Java"; subtitle: "对应 HMCL JavaManagementPage 的本地 Java 检测入口。"; buttonText: "检测"; onAction: root.backend.detectJava() }
                ButtonRow { style: root.style; title: "下载 Java 8"; buttonText: "下载"; onAction: root.backend.downloadJava("temurin", "8", "jre") }
                ButtonRow { style: root.style; title: "下载 Java 17"; buttonText: "下载"; onAction: root.backend.downloadJava("temurin", "17", "jre") }
                ButtonRow { style: root.style; title: "下载 Java 21"; buttonText: "下载"; onAction: root.backend.downloadJava("temurin", "21", "jre") }
            }
        }
    }

    Component {
        id: generalSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10

            SectionTitle { style: root.style; title: "更新" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                SelectRow { style: root.style; title: "更新通道"; subtitle: "当前状态：本地开发版。"; value: root.settingText("updateChannel", "stable"); options: [{"text":"稳定版","value":"stable"},{"text":"开发版","value":"development"}]; onSelected: function(v) { root.setSetting("updateChannel", v) } }
                ToggleRow { style: root.style; title: "接收预览版更新"; subtitle: "对应 HMCL acceptPreviewUpdate。"; checkedValue: root.settingBool("acceptPreviewUpdate", false); onChangedValue: function(v) { root.setBool("acceptPreviewUpdate", v) } }
                ToggleRow { style: root.style; title: "不自动弹出更新提示"; subtitle: "对应 HMCL disableAutoShowUpdateDialog。"; checkedValue: root.settingBool("disableAutoShowUpdateDialog", false); onChangedValue: function(v) { root.setBool("disableAutoShowUpdateDialog", v) } }
            }

            SectionTitle { style: root.style; title: "语言" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                SelectRow { style: root.style; title: "语言"; subtitle: "重启后生效。"; value: root.settingText("language", "zh_CN"); options: [{"text":"简体中文","value":"zh_CN"},{"text":"English","value":"en"}]; onSelected: function(v) { root.setSetting("language", v) } }
            }

            SectionTitle { style: root.style; title: "杂项" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                ButtonGroupRow { style: root.style; title: "调试"; subtitle: "对应 HMCL SettingsPage 的启动器日志入口。"; firstText: "显示日志"; secondText: "导出日志"; onFirst: root.backend.openLauncherSpecialFolder("logs"); onSecond: root.backend.exportLauncherDiagnostics() }
            }
        }
    }

    Component {
        id: appearanceSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10

            SectionTitle { style: root.style; title: "外观" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                SelectRow { style: root.style; title: "亮度"; value: root.themeMode; options: [{"text":"跟随系统","value":"system"},{"text":"浅色","value":"light"},{"text":"深色","value":"dark"}]; onSelected: function(v) { root.setThemeMode(v) } }
                SelectRow { style: root.style; title: "主题"; value: root.themeColor; options: [{"text":"默认","value":"default"},{"text":"紫色","value":"purple"},{"text":"蓝色","value":"blue"},{"text":"绿色","value":"green"},{"text":"红色","value":"red"},{"text":"橙色","value":"orange"}]; onSelected: function(v) { root.setThemeColor(v) } }
                ToggleRow { style: root.style; title: "标题栏透明"; checkedValue: root.settingBool("titleTransparent", false); onChangedValue: function(v) { root.setBool("titleTransparent", v) } }
                ToggleRow { style: root.style; title: "关闭动画"; subtitle: "重启后生效。"; checkedValue: root.settingBool("turnOffAnimations", false); onChangedValue: function(v) { root.setBool("turnOffAnimations", v) } }
            }

            SectionTitle { style: root.style; title: "启动器背景" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                Hmcl.ComponentSublist {
                    width: parent.width
                    style: root.style
                    title: "启动器背景"
                    subtitle: "点击展开，结构对应 HMCL PersonalizationPage.backgroundSublist。"
                    trailingText: backgroundDisplay(root.settingText("backgroundType", "default"))
                    expanded: false
                    SelectRow { style: root.style; title: "背景类型"; value: root.settingText("backgroundType", "default"); options: [{"text":"默认","value":"default"},{"text":"经典","value":"classic"},{"text":"自定义图片","value":"custom"},{"text":"网络图片","value":"network"},{"text":"纯色","value":"paint"}]; onSelected: function(v) { root.setSetting("backgroundType", v) } }
                    TextRow { style: root.style; title: "自定义图片路径"; valueText: root.settingText("backgroundImage", ""); onAccepted: function(v) { root.setSetting("backgroundImage", v) } }
                    TextRow { style: root.style; title: "网络图片地址"; valueText: root.settingText("backgroundImageUrl", ""); onAccepted: function(v) { root.setSetting("backgroundImageUrl", v) } }
                    TextRow { style: root.style; title: "纯色背景"; subtitle: "十六进制颜色，例如 #101010。"; valueText: root.settingText("backgroundPaint", ""); onAccepted: function(v) { root.setSetting("backgroundPaint", v) } }
                    SliderRow { style: root.style; title: "背景透明度"; fromValue: 0; toValue: 100; valueNumber: Number(root.settingText("backgroundOpacity", "1")) * 100; suffix: "%"; onMovedValue: function(v) { root.setSetting("backgroundOpacity", String(Math.round(v) / 100)) } }
                }
            }

            SectionTitle { style: root.style; title: "日志" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                TextRow { style: root.style; title: "日志字体"; valueText: root.settingText("logFontFamily", "monospace"); onAccepted: function(v) { root.setSetting("logFontFamily", v) } }
                TextRow { style: root.style; title: "日志字号"; valueText: root.settingText("logFontSize", "12"); onAccepted: function(v) { root.setSetting("logFontSize", v) } }
                InfoRow { style: root.style; title: "预览"; subtitle: "[23:33:33] [Client Thread/INFO] [WaterPower]: Loaded mod WaterPower." }
            }

            SectionTitle { style: root.style; title: "字体" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                SelectRow { style: root.style; title: "字体抗锯齿"; value: root.settingText("fontAntiAliasing", "auto"); options: [{"text":"自动","value":"auto"},{"text":"开启","value":"on"},{"text":"关闭","value":"off"}]; onSelected: function(v) { root.setSetting("fontAntiAliasing", v) } }
            }
        }
    }

    Component {
        id: downloadSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10

            SectionTitle { style: root.style; title: "下载源" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                SelectRow { style: root.style; title: "版本列表来源"; value: root.settingText("versionListSource", "balanced"); options: downloadSourceOptions(); onSelected: function(v) { root.setSetting("versionListSource", v) } }
                SelectRow { style: root.style; title: "下载源"; value: root.settingText("downloadSource", "balanced"); options: downloadSourceOptions(); onSelected: function(v) { root.setSetting("downloadSource", v) } }
                SelectRow { style: root.style; title: "游戏内容下载源"; value: root.settingText("defaultAddonSource", "modrinth"); options: [{"text":"Modrinth","value":"modrinth"},{"text":"CurseForge","value":"curseforge"}]; onSelected: function(v) { root.setSetting("defaultAddonSource", v) } }
            }

            SectionTitle { style: root.style; title: "下载" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                Hmcl.ComponentSublist {
                    width: parent.width
                    style: root.style
                    title: "文件下载缓存目录"
                    subtitle: "点击展开，结构对应 HMCL DownloadSettingsPage.fileCommonLocationSublist。"
                    trailingText: commonDirectoryDisplay(root.settingText("commonDirType", "default"), root.settingText("commonDirectory", ""))
                    SelectRow { style: root.style; title: "缓存目录"; value: root.settingText("commonDirType", "default"); options: [{"text":"默认","value":"default"},{"text":"自定义","value":"custom"}]; onSelected: function(v) { root.setSetting("commonDirType", v) } }
                    TextRow { style: root.style; title: "自定义目录"; valueText: root.settingText("commonDirectory", ""); onAccepted: function(v) { root.setSetting("commonDirectory", v) } }
                    ButtonGroupRow { style: root.style; title: "缓存操作"; firstText: "打开目录"; secondText: "清理缓存"; onFirst: root.backend.openLauncherSpecialFolder("cache"); onSecond: root.backend.clearLauncherCache() }
                }
                ToggleRow { style: root.style; title: "自动选择下载线程数"; checkedValue: root.settingBool("autoDownloadThreads", true); onChangedValue: function(v) { root.setBool("autoDownloadThreads", v) } }
                SliderRow { style: root.style; title: "下载线程数"; fromValue: 1; toValue: 256; valueNumber: Number(root.settingText("downloadThreads", "64")); suffix: ""; enabledRow: !root.settingBool("autoDownloadThreads", true); onMovedValue: function(v) { root.setSetting("downloadThreads", String(Math.round(v))) } }
            }

            SectionTitle { style: root.style; title: "代理" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                SelectRow { style: root.style; title: "代理"; value: root.settingText("proxyType", "default"); options: [{"text":"使用系统代理","value":"default"},{"text":"不使用代理","value":"none"},{"text":"HTTP","value":"http"},{"text":"SOCKS","value":"socks"}]; onSelected: function(v) { root.setSetting("proxyType", v) } }
                TextRow { style: root.style; title: "IP 地址"; valueText: root.settingText("proxyHost", ""); enabledRow: isCustomProxy(); onAccepted: function(v) { root.setSetting("proxyHost", v) } }
                TextRow { style: root.style; title: "端口"; valueText: root.settingText("proxyPort", "0"); enabledRow: isCustomProxy(); onAccepted: function(v) { root.setSetting("proxyPort", v) } }
                ToggleRow { style: root.style; title: "代理认证"; checkedValue: root.settingBool("hasProxyAuth", false); enabledRow: isCustomProxy(); onChangedValue: function(v) { root.setBool("hasProxyAuth", v) } }
                TextRow { style: root.style; title: "账户"; valueText: root.settingText("proxyUsername", ""); enabledRow: isCustomProxy() && root.settingBool("hasProxyAuth", false); onAccepted: function(v) { root.setSetting("proxyUsername", v) } }
                TextRow { style: root.style; title: "密码"; valueText: root.settingText("proxyPassword", ""); password: true; enabledRow: isCustomProxy() && root.settingBool("hasProxyAuth", false); onAccepted: function(v) { root.setSetting("proxyPassword", v) } }
            }
        }
    }

    Component {
        id: helpSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10
            SectionTitle { style: root.style; title: "帮助" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                ButtonRow { style: root.style; title: "HMCL 文档"; subtitle: "对应 HelpPage 的外部帮助入口。"; buttonText: "打开"; onAction: root.backend.openUrl("https://docs.hmcl.net/") }
                ButtonRow { style: root.style; title: "Minecraft Wiki"; buttonText: "打开"; onAction: root.backend.openUrl("https://minecraft.wiki/") }
            }
        }
    }

    Component {
        id: feedbackSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10
            SectionTitle { style: root.style; title: "反馈" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                ButtonRow { style: root.style; title: "GitHub Issues"; buttonText: "打开"; onAction: root.backend.openUrl("https://github.com/Bihrys/mc-launcher/issues") }
                ButtonRow { style: root.style; title: "导出诊断信息"; buttonText: "导出"; onAction: root.backend.exportLauncherDiagnostics() }
            }
        }
    }

    Component {
        id: aboutSectionComponent
        Column {
            width: parent ? parent.width : 800
            spacing: 10
            SectionTitle { style: root.style; title: "关于" }
            Hmcl.ComponentList {
                width: parent.width
                style: root.style
                InfoRow { style: root.style; title: "名称"; subtitle: "mc-launcher" }
                InfoRow { style: root.style; title: "参考项目"; subtitle: "Hello Minecraft! Launcher。后续移植只按 HMCL 源码映射，不再自由发挥。" }
                ButtonRow { style: root.style; title: "项目仓库"; buttonText: "打开"; onAction: root.backend.openUrl("https://github.com/Bihrys/mc-launcher") }
            }
        }
    }

    function downloadSourceOptions() {
        return [{"text":"自动/平衡","value":"balanced"},{"text":"官方","value":"official"},{"text":"BMCLAPI","value":"bmcl"}]
    }

    function isCustomProxy() {
        var type = root.settingText("proxyType", "default")
        return type === "http" || type === "socks"
    }

    function backgroundDisplay(value) {
        if (value === "classic") return "经典"
        if (value === "custom") return "自定义"
        if (value === "network") return "网络图片"
        if (value === "paint") return "纯色"
        return "默认"
    }

    function commonDirectoryDisplay(kind, path) {
        if (kind === "custom" && path.length > 0)
            return path
        if (kind === "custom")
            return "自定义"
        return "默认"
    }

    component DrawerCategory: Item {
        id: category
        property var style
        property string text: ""
        width: parent ? parent.width : 200
        height: 32

        function styleValue(name, fallback) {
            if (category.style !== undefined && category.style !== null) {
                var value = category.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 8
            spacing: 0

            Text {
                width: parent.width
                text: category.text.toUpperCase()
                color: category.styleValue("cTextOnSurface", "#1B1B21")
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: category.styleValue("cTextOnSurfaceVariant", "#454651")
                opacity: 0.75
            }
        }
    }

    component SectionTitle: Item {
        id: sectionTitle
        property var style
        property string title: ""
        width: parent ? parent.width : 800
        height: 28

        function styleValue(name, fallback) {
            if (sectionTitle.style !== undefined && sectionTitle.style !== null) {
                var value = sectionTitle.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: sectionTitle.title
            color: sectionTitle.styleValue("cTextOnSurface", "#1B1B21")
            font.pixelSize: 13
        }
    }

    component BaseLine: Rectangle {
        id: line
        property var style
        property string title: ""
        property string subtitle: ""
        property bool enabledRow: true
        property int baseHeight: subtitle.length > 0 ? 64 : 48
        width: parent ? parent.width : 800
        height: baseHeight
        color: line.styleValue("cSurface", "#FFFBFE")
        opacity: enabledRow ? 1.0 : 0.42

        function styleValue(name, fallback) {
            if (line.style !== undefined && line.style !== null) {
                var value = line.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: line.styleValue("cBorder", "#D9D7E2") }

        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: trailingSlot.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { Layout.fillWidth: true; text: line.title; color: line.styleValue("cTextOnSurface", "#1B1B21"); font.pixelSize: 13; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; visible: line.subtitle.length > 0; text: line.subtitle; color: line.styleValue("cTextOnSurfaceVariant", "#454651"); font.pixelSize: 12; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
        }

        Item { id: trailingSlot; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: Math.min(420, parent.width * 0.52); height: parent.height }
    }

    component InfoRow: BaseLine {
        id: info
        property string valueText: ""
        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: Math.min(420, parent.width * 0.52); horizontalAlignment: Text.AlignRight; text: info.valueText.length > 0 ? info.valueText : info.subtitle; color: info.styleValue("cTextOnSurfaceVariant", "#454651"); font.pixelSize: 12; elide: Text.ElideRight }
    }

    component ButtonRow: BaseLine {
        id: row
        property string buttonText: "执行"
        signal action()
        BorderButton { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; style: row.style; text: row.buttonText; enabledButton: row.enabledRow; onClicked: row.action() }
    }

    component ButtonGroupRow: BaseLine {
        id: row
        property string firstText: "执行"
        property string secondText: "执行"
        signal first()
        signal second()
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            BorderButton { style: row.style; text: row.firstText; onClicked: row.first() }
            BorderButton { style: row.style; text: row.secondText; onClicked: row.second() }
        }
    }

    component ToggleRow: BaseLine {
        id: row
        property bool checkedValue: false
        signal changedValue(bool value)
        Switch { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; enabled: row.enabledRow; checked: row.checkedValue; onToggled: row.changedValue(checked) }
    }

    component SelectRow: BaseLine {
        id: row
        property var options: []
        property string value: ""
        signal selected(string value)

        ComboBox {
            id: combo
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(260, parent.width * 0.48)
            height: 32
            enabled: row.enabledRow
            model: row.options
            textRole: "text"
            valueRole: "value"
            currentIndex: {
                for (var i = 0; i < row.options.length; ++i) {
                    if (String(row.options[i].value) === row.value)
                        return i
                }
                return row.options.length > 0 ? 0 : -1
            }
            onActivated: function(index) {
                if (index >= 0 && index < row.options.length)
                    row.selected(String(row.options[index].value))
            }
        }
    }

    component TextRow: BaseLine {
        id: row
        property string valueText: ""
        property bool password: false
        signal accepted(string value)

        TextField {
            id: input
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(300, parent.width * 0.48)
            height: 32
            enabled: row.enabledRow
            text: row.valueText
            echoMode: row.password ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            color: row.styleValue("cTextOnSurface", "#1B1B21")
            font.pixelSize: 13
            background: Rectangle {
                color: "transparent"
                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: input.activeFocus ? row.styleValue("cButtonSelected", "#4352A5") : row.styleValue("cTextOnSurfaceVariant", "#454651"); opacity: input.activeFocus ? 1 : 0.55 }
            }
            onAccepted: row.accepted(text)
            onEditingFinished: row.accepted(text)
        }
    }

    component SliderRow: BaseLine {
        id: row
        property real fromValue: 0
        property real toValue: 100
        property real valueNumber: 0
        property string suffix: ""
        signal movedValue(real value)
        baseHeight: 58

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(360, parent.width * 0.50)
            spacing: 10
            Slider { id: slider; Layout.fillWidth: true; enabled: row.enabledRow; from: row.fromValue; to: row.toValue; value: row.valueNumber; onMoved: row.movedValue(value) }
            Text { Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight; text: String(Math.round(slider.value)) + row.suffix; color: row.styleValue("cTextOnSurfaceVariant", "#454651"); font.pixelSize: 12 }
        }
    }

    component BorderButton: Rectangle {
        id: button
        property var style
        property string text: "执行"
        property bool enabledButton: true
        signal clicked()
        width: Math.max(78, label.implicitWidth + 28)
        height: 30
        radius: 2
        border.width: 1
        border.color: styleValue("cBorder", "#D9D7E2")
        color: mouse.containsMouse && enabledButton ? styleValue("cButtonHover", "#F0F0F8") : "transparent"
        opacity: enabledButton ? 1.0 : 0.45

        function styleValue(name, fallback) {
            if (button.style !== undefined && button.style !== null) {
                var value = button.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Text { id: label; anchors.centerIn: parent; text: button.text; color: button.styleValue("cTextOnSurface", "#1B1B21"); font.pixelSize: 13 }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: button.enabledButton; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: button.clicked() }
    }
}
