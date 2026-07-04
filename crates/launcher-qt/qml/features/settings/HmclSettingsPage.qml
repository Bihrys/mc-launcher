import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    property string themeMode: "light"
    property string themeColor: "default"
    property string launcherVisibility: "hide"
    property string currentSection: "global"
    property string requestedSection: "global"
    property var settingsData: ({})

    property bool pageActive: false
    property bool pageAnimationReady: false
    property int navigationOffset: 30

    signal themeSelected(string mode)
    signal themeColorSelected(string color)
    signal launcherVisibilitySelected(string mode)

    Component.onCompleted: {
        if (root.requestedSection.length > 0) {
            root.currentSection = root.requestedSection
        }
        root.reloadSettings()
        root.pageAnimationReady = true
        if (root.pageActive) {
            root.playDecoratorEnter()
        }
    }

    onRequestedSectionChanged: {
        if (root.requestedSection.length > 0) {
            root.currentSection = root.requestedSection
        }
    }

    onPageActiveChanged: {
        if (!root.pageAnimationReady) {
            return
        }
        if (root.pageActive) {
            root.playDecoratorEnter()
        } else {
            root.playDecoratorExit()
        }
    }

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    function sectionComponentFor(section) {
        switch (section) {
        case "global":
            return globalSectionComponent
        case "java":
            return javaSectionComponent
        case "general":
            return generalSectionComponent
        case "appearance":
            return appearanceSectionComponent
        case "download":
            return downloadSectionComponent
        case "help":
            return helpSectionComponent
        case "feedback":
            return feedbackSectionComponent
        case "about":
            return aboutSectionComponent
        default:
            return globalSectionComponent
        }
    }

    function reloadSettings() {
        var raw = root.backend.refreshLauncherSettings()
        try {
            root.settingsData = JSON.parse(raw || "{}")
        } catch (e) {
            root.settingsData = {}
        }

        if (root.settingsData.themeMode !== undefined) {
            root.themeMode = String(root.settingsData.themeMode)
        }
        if (root.settingsData.themeColor !== undefined) {
            root.themeColor = String(root.settingsData.themeColor)
        }
        if (root.settingsData.launcherVisibility !== undefined) {
            root.launcherVisibility = String(root.settingsData.launcherVisibility)
        }
    }

    function setSetting(key, value) {
        var next = {}
        for (var k in root.settingsData) {
            next[k] = root.settingsData[k]
        }
        next[key] = value
        root.settingsData = next
        root.backend.updateLauncherSetting(key, String(value))
    }

    function settingText(key) {
        var value = root.settingsData[key]
        if (value === undefined || value === null) {
            return ""
        }
        return String(value)
    }

    function settingBool(key) {
        var value = root.settingsData[key]
        return value === true || value === "true"
    }

    function playDecoratorEnter() {
        decoratorEnter.stop()
        decoratorExit.stop()

        if (!root.styleValue("animationsEnabled", true)) {
            settingsLeftPane.x = 0
            settingsLeftPane.opacity = 1
            settingsScroll.x = 0
            settingsScroll.opacity = 1
            return
        }

        settingsLeftPane.x = -root.navigationOffset
        settingsLeftPane.opacity = 0
        settingsScroll.x = root.navigationOffset
        settingsScroll.opacity = 0
        decoratorEnter.restart()
    }

    function playDecoratorExit() {
        decoratorEnter.stop()
        decoratorExit.stop()

        if (!root.styleValue("animationsEnabled", true)) {
            settingsLeftPane.x = 0
            settingsLeftPane.opacity = 1
            settingsScroll.x = 0
            settingsScroll.opacity = 1
            return
        }

        settingsLeftPane.x = 0
        settingsLeftPane.opacity = 1
        settingsScroll.x = 0
        settingsScroll.opacity = 1
        decoratorExit.restart()
    }

    ParallelAnimation {
        id: decoratorEnter

        ParallelAnimation {
            NumberAnimation { target: settingsLeftPane; property: "x"; to: 0; duration: root.styleValue("motionMedium4", 240); easing.type: Easing.OutCubic }
            NumberAnimation { target: settingsLeftPane; property: "opacity"; to: 1; duration: root.styleValue("motionMedium4", 240); easing.type: Easing.OutCubic }
            NumberAnimation { target: settingsScroll; property: "x"; to: 0; duration: root.styleValue("motionMedium4", 240); easing.type: Easing.OutCubic }
            NumberAnimation { target: settingsScroll; property: "opacity"; to: 1; duration: root.styleValue("motionMedium4", 240); easing.type: Easing.OutCubic }
        }
    }

    ParallelAnimation {
        id: decoratorExit

        ParallelAnimation {
            NumberAnimation { target: settingsLeftPane; property: "x"; to: -root.navigationOffset; duration: root.styleValue("motionMedium4", 240) / 2; easing.type: Easing.InCubic }
            NumberAnimation { target: settingsLeftPane; property: "opacity"; to: 0; duration: root.styleValue("motionMedium4", 240) / 2; easing.type: Easing.InCubic }
            NumberAnimation { target: settingsScroll; property: "x"; to: root.navigationOffset; duration: root.styleValue("motionMedium4", 240) / 2; easing.type: Easing.InCubic }
            NumberAnimation { target: settingsScroll; property: "opacity"; to: 0; duration: root.styleValue("motionMedium4", 240) / 2; easing.type: Easing.InCubic }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: settingsLeftSlot
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            clip: true

            Item {
                id: settingsLeftPane
                width: settingsLeftSlot.width
                height: settingsLeftSlot.height

                Flickable {
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: drawerColumn.height + 20
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: drawerColumn
                        width: parent.width
                        y: 12
                        spacing: 0

                        NavItem { style: root.style; label: "全局游戏设置"; iconKind: "game"; section: "global"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }
                        NavItem { style: root.style; label: "Java 管理"; iconKind: "java"; section: "java"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }

                        DrawerCategory { style: root.style; label: "启动器" }

                        NavItem { style: root.style; label: "通用"; iconKind: "tune"; section: "general"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }
                        NavItem { style: root.style; label: "外观"; iconKind: "style"; section: "appearance"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }
                        NavItem { style: root.style; label: "下载"; iconKind: "download"; section: "download"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }

                        DrawerCategory { style: root.style; label: "帮助" }

                        NavItem { style: root.style; label: "帮助"; iconKind: "help"; section: "help"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }
                        NavItem { style: root.style; label: "反馈"; iconKind: "feedback"; section: "feedback"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }
                        NavItem { style: root.style; label: "关于"; iconKind: "info"; section: "about"; currentSection: root.currentSection; onClicked: function(section) { root.currentSection = section } }
                    }
                }
            }
        }

        Item {
            id: settingsCenterSlot
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScrollView {
                id: settingsScroll
                width: settingsCenterSlot.width
                height: settingsCenterSlot.height
                clip: true
                contentWidth: availableWidth

                Item {
                    width: settingsScroll.availableWidth
                    height: Math.max(settingsScroll.height, settingsPane.item ? settingsPane.item.implicitHeight + 20 : 1)

                    Loader {
                        id: settingsPane
                        x: 10
                        y: 10
                        width: Math.max(1, parent.width - 20)
                        height: item ? item.implicitHeight : 1
                        sourceComponent: root.sectionComponentFor(root.currentSection)

                        Behavior on opacity { NumberAnimation { duration: root.styleValue("motionMedium2", 160); easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Component {
        id: globalSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "全局游戏设置"; subtitle: "参考 HMCL 的 GameSettingsPage：高级设置默认收起，点击条目展开编辑。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "内存"
                subtitle: "设置 Minecraft 的 JVM 内存参数。"
                trailingText: root.settingText("minMemoryMb") + " MB / " + root.settingText("maxMemoryMb") + " MB"

                TextRow { style: root.style; label: "最小内存"; description: "对应 JVM -Xms，单位 MB。"; valueText: root.settingText("minMemoryMb"); suffix: "MB"; onAccepted: function(v) { root.setSetting("minMemoryMb", v) } }
                TextRow { style: root.style; label: "最大内存"; description: "对应 JVM -Xmx，单位 MB。"; valueText: root.settingText("maxMemoryMb"); suffix: "MB"; onAccepted: function(v) { root.setSetting("maxMemoryMb", v) } }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "窗口"
                subtitle: "游戏窗口大小和启动模式。"
                trailingText: root.settingBool("fullscreen") ? "全屏" : root.settingText("gameWidth") + " × " + root.settingText("gameHeight")

                TextRow { style: root.style; label: "游戏窗口宽度"; description: "Minecraft 启动窗口宽度。"; valueText: root.settingText("gameWidth"); suffix: "px"; onAccepted: function(v) { root.setSetting("gameWidth", v) } }
                TextRow { style: root.style; label: "游戏窗口高度"; description: "Minecraft 启动窗口高度。"; valueText: root.settingText("gameHeight"); suffix: "px"; onAccepted: function(v) { root.setSetting("gameHeight", v) } }
                SwitchRow { style: root.style; label: "全屏启动"; description: "启动 Minecraft 时传入 --fullscreen。"; checkedValue: root.settingBool("fullscreen"); onToggledValue: function(v) { root.setSetting("fullscreen", String(v)) } }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "Java"
                subtitle: "全局 Java 路径和 JVM 参数。实例页可覆盖这些设置。"
                trailingText: root.settingBool("javaAuto") ? "自动选择" : (root.settingText("javaPath").length > 0 ? root.settingText("javaPath") : "未指定")

                SwitchRow { style: root.style; label: "自动选择 Java"; description: "启动时根据游戏版本要求自动选择 Java。"; checkedValue: root.settingBool("javaAuto"); onToggledValue: function(v) { root.setSetting("javaAuto", String(v)) } }
                TextRow { style: root.style; label: "Java 路径"; description: "手动指定 Java 可执行文件。"; valueText: root.settingText("javaPath"); onAccepted: function(v) { root.setSetting("javaPath", v) } }
                TextRow { style: root.style; label: "Java 虚拟机参数"; description: "额外 JVM 参数，例如 -XX:+UseG1GC。"; valueText: root.settingText("jvmArgs"); onAccepted: function(v) { root.setSetting("jvmArgs", v) } }
                ActionRow { style: root.style; label: "检测本机 Java"; description: "调用当前项目 Java 检测后端。"; actionText: "检测"; onAction: root.backend.detectJava() }
                ActionRow { style: root.style; label: "进入 Java 管理"; description: "切换到左侧 Java 管理页。"; actionText: "打开"; onAction: root.currentSection = "java" }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "启动"
                subtitle: "游戏目录、启动器可见性和启动前后命令。"
                trailingText: launcherVisibilityDisplay(root.launcherVisibility)

                TextRow { style: root.style; label: "游戏目录"; description: "留空时使用当前 Profile 的默认游戏目录。"; valueText: root.settingText("gameDir"); onAccepted: function(v) { root.setSetting("gameDir", v) } }
                ChoiceRow {
                    style: root.style
                    label: "启动器可见性"
                    description: "游戏启动后的启动器窗口处理方式。"
                    currentValue: root.launcherVisibility
                    choices: [
                        {"text": "结束启动器", "value": "close"},
                        {"text": "隐藏启动器", "value": "hide"},
                        {"text": "保持可见", "value": "keep"}
                    ]
                    onChoice: function(v) {
                        root.launcherVisibility = v
                        root.setSetting("launcherVisibility", v)
                        root.launcherVisibilitySelected(v)
                    }
                }
                TextRow { style: root.style; label: "启动前命令"; description: "启动游戏前执行的命令。"; valueText: root.settingText("preLaunchCommand"); onAccepted: function(v) { root.setSetting("preLaunchCommand", v) } }
                TextRow { style: root.style; label: "游戏结束后命令"; description: "游戏退出后执行的命令。"; valueText: root.settingText("postExitCommand"); onAccepted: function(v) { root.setSetting("postExitCommand", v) } }
            }
        }
    }

    Component {
        id: javaSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "Java 管理"; subtitle: "全局 Java 发现、路径和下载入口。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "本机 Java"
                subtitle: "检测系统中已经安装的 Java 运行时。"
                trailingText: root.settingBool("javaAuto") ? "自动选择" : "手动指定"
                defaultExpanded: true

                SwitchRow { style: root.style; label: "自动选择 Java"; description: "根据 Minecraft 版本自动选择合适 Java。"; checkedValue: root.settingBool("javaAuto"); onToggledValue: function(v) { root.setSetting("javaAuto", String(v)) } }
                TextRow { style: root.style; label: "Java 路径"; description: "手动指定 java 可执行文件路径。"; valueText: root.settingText("javaPath"); onAccepted: function(v) { root.setSetting("javaPath", v) } }
                ActionRow { style: root.style; label: "检测本机 Java"; description: "结果显示在启动器输出区域。"; actionText: "检测"; onAction: root.backend.detectJava() }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "Java 下载"
                subtitle: "下载常用 Java 运行时。后续会迁移到独立 JavaVm。"
                trailingText: "Temurin"

                ActionRow { style: root.style; label: "下载 Java 8 JRE"; description: "适合旧版本 Minecraft。"; actionText: "下载"; onAction: root.backend.downloadJava("temurin", "8", "jre") }
                ActionRow { style: root.style; label: "下载 Java 17 JRE"; description: "适合 1.18+ 版本。"; actionText: "下载"; onAction: root.backend.downloadJava("temurin", "17", "jre") }
                ActionRow { style: root.style; label: "下载 Java 21 JRE"; description: "适合较新的 Minecraft 版本。"; actionText: "下载"; onAction: root.backend.downloadJava("temurin", "21", "jre") }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "JVM 参数"
                subtitle: "不建议普通用户随意修改。"
                trailingText: root.settingText("jvmArgs").length > 0 ? "已设置" : "默认"

                TextRow { style: root.style; label: "Java 虚拟机参数"; description: "额外 JVM 参数。"; valueText: root.settingText("jvmArgs"); onAccepted: function(v) { root.setSetting("jvmArgs", v) } }
            }
        }
    }

    Component {
        id: generalSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "通用"; subtitle: "启动器更新、语言、日志和杂项。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "更新"
                subtitle: "检查启动器更新和预览版通道。"
                trailingText: updateChannelDisplay(root.settingText("updateChannel"))

                ChoiceRow { style: root.style; label: "更新通道"; description: "稳定版或开发版。"; currentValue: root.settingText("updateChannel"); choices: [{"text": "稳定版", "value": "stable"}, {"text": "开发版", "value": "development"}]; onChoice: function(v) { root.setSetting("updateChannel", v) } }
                SwitchRow { style: root.style; label: "接收测试版更新"; description: "对应 HMCL 预览版更新开关。"; checkedValue: root.settingBool("acceptPreviewUpdate"); onToggledValue: function(v) { root.setSetting("acceptPreviewUpdate", String(v)) } }
                SwitchRow { style: root.style; label: "不自动显示更新对话框"; description: "启动时不自动弹出更新提示。"; checkedValue: root.settingBool("disableAutoShowUpdateDialog"); onToggledValue: function(v) { root.setSetting("disableAutoShowUpdateDialog", String(v)) } }
                ActionRow { style: root.style; label: "打开发布页"; description: "查看项目发布版本。"; actionText: "打开"; onAction: root.backend.openUrl("https://github.com/Bihrys/mc-launcher/releases") }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "语言"
                subtitle: "更改后重启生效。"
                trailingText: languageDisplay(root.settingText("language"))

                ChoiceRow { style: root.style; label: "语言"; description: "界面语言。"; currentValue: root.settingText("language"); choices: [{"text": "简体中文", "value": "zh_CN"}, {"text": "English", "value": "en"}]; onChoice: function(v) { root.setSetting("language", v) } }
                SwitchRow { style: root.style; label: "不自动切换游戏语言"; description: "对应 HMCL disableAutoGameOptions。"; checkedValue: root.settingBool("disableAutoGameOptions"); onToggledValue: function(v) { root.setSetting("disableAutoGameOptions", String(v)) } }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "杂项"
                subtitle: "主页游戏列表、离线账户和 Agent 行为。"
                trailingText: root.settingBool("enableGameList") ? "显示游戏列表" : "隐藏游戏列表"

                SwitchRow { style: root.style; label: "在主页内显示游戏列表"; description: "对应 HMCL 首页游戏列表。"; checkedValue: root.settingBool("enableGameList"); onToggledValue: function(v) { root.setSetting("enableGameList", String(v)) } }
                SwitchRow { style: root.style; label: "允许离线账户"; description: "是否允许创建和使用离线账户。"; checkedValue: root.settingBool("enableOfflineAccount"); onToggledValue: function(v) { root.setSetting("enableOfflineAccount", String(v)) } }
                SwitchRow { style: root.style; label: "允许启动器修改游戏"; description: "允许通过 Java Agent 改善外置登录等体验。"; checkedValue: root.settingBool("allowAutoAgent"); onToggledValue: function(v) { root.setSetting("allowAutoAgent", String(v)) } }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "日志与诊断"
                subtitle: "打开日志目录、导出诊断信息或重置配置。"
                trailingText: root.settingText("logFont").length > 0 ? root.settingText("logFont") : "monospace"

                TextRow { style: root.style; label: "日志字体"; description: "日志窗口和调试输出字体。"; valueText: root.settingText("logFont"); onAccepted: function(v) { root.setSetting("logFont", v) } }
                ActionRow { style: root.style; label: "打开日志目录"; description: "打开启动器日志目录。"; actionText: "打开"; onAction: root.backend.openLauncherSpecialFolder("logs") }
                ActionRow { style: root.style; label: "打开配置目录"; description: "打开设置文件和账户文件所在目录。"; actionText: "打开"; onAction: root.backend.openLauncherSpecialFolder("config") }
                ActionRow { style: root.style; label: "导出诊断信息"; description: "导出系统、设置和目录信息，便于排查问题。"; actionText: "导出"; onAction: root.backend.exportLauncherDiagnostics() }
                ActionRow { style: root.style; label: "重置启动器设置"; description: "恢复默认设置，不删除账户和实例。"; actionText: "重置"; onAction: { root.backend.resetLauncherSettings(); root.reloadSettings() } }
            }
        }
    }

    Component {
        id: appearanceSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "外观"; subtitle: "主题、字体、动画和标题栏。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "主题"
                subtitle: "切换浅色、深色或跟随系统设置。"
                trailingText: themeModeDisplay(root.themeMode)
                defaultExpanded: true

                ChoiceRow {
                    style: root.style
                    label: "主题模式"
                    description: "切换浅色、深色或跟随系统。"
                    currentValue: root.themeMode
                    choices: [{"text": "浅色模式", "value": "light"}, {"text": "深色模式", "value": "dark"}, {"text": "跟随系统", "value": "system"}]
                    onChoice: function(v) {
                        root.themeMode = v
                        root.setSetting("themeMode", v)
                        root.themeSelected(v)
                    }
                }
                ChoiceRow {
                    style: root.style
                    label: "主题色"
                    description: "切换启动器强调色。"
                    currentValue: root.themeColor
                    choices: [{"text": "默认", "value": "default"}, {"text": "紫色", "value": "purple"}, {"text": "蓝色", "value": "blue"}, {"text": "绿色", "value": "green"}]
                    onChoice: function(v) {
                        root.themeColor = v
                        root.setSetting("themeColor", v)
                        root.themeColorSelected(v)
                    }
                }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "界面"
                subtitle: "标题栏、动画、缩放和字体渲染。"
                trailingText: root.settingBool("turnOffAnimations") ? "动画关闭" : "动画开启"

                SwitchRow { style: root.style; label: "标题栏透明"; description: "对应 HMCL title_transparent。"; checkedValue: root.settingBool("titleTransparent"); onToggledValue: function(v) { root.setSetting("titleTransparent", String(v)) } }
                SwitchRow { style: root.style; label: "关闭动画"; description: "关闭页面切换和展开折叠动画。"; checkedValue: root.settingBool("turnOffAnimations"); onToggledValue: function(v) { root.setSetting("turnOffAnimations", String(v)) } }
                TextRow { style: root.style; label: "界面缩放"; description: "1.0 为默认缩放。"; valueText: root.settingText("uiScale"); onAccepted: function(v) { root.setSetting("uiScale", v) } }
                ChoiceRow { style: root.style; label: "字体抗锯齿"; description: "自动、开启或关闭。"; currentValue: root.settingText("fontAntiAliasing"); choices: [{"text": "自动", "value": "auto"}, {"text": "开启", "value": "on"}, {"text": "关闭", "value": "off"}]; onChoice: function(v) { root.setSetting("fontAntiAliasing", v) } }
            }
        }
    }

    Component {
        id: downloadSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "下载"; subtitle: "下载源、缓存目录、线程数和代理。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "下载来源"
                subtitle: "自动选择或指定游戏文件下载源。"
                trailingText: root.settingBool("autoChooseDownloadSource") ? "自动选择" : sourceDisplay(root.settingText("downloadSource"))
                defaultExpanded: true

                SwitchRow { style: root.style; label: "自动选择下载源"; description: "根据当前网络自动选择合适源。"; checkedValue: root.settingBool("autoChooseDownloadSource"); onToggledValue: function(v) { root.setSetting("autoChooseDownloadSource", String(v)) } }
                ChoiceRow { style: root.style; label: "版本列表来源"; description: "Minecraft 版本清单下载源。"; currentValue: root.settingText("versionListSource"); choices: [{"text": "自动/平衡", "value": "balanced"}, {"text": "官方", "value": "official"}, {"text": "BMCLAPI", "value": "bmcl"}]; onChoice: function(v) { root.setSetting("versionListSource", v) } }
                ChoiceRow { style: root.style; label: "下载源"; description: "游戏文件、资源文件、依赖库下载源。"; currentValue: root.settingText("downloadSource"); choices: [{"text": "自动/平衡", "value": "balanced"}, {"text": "官方", "value": "official"}, {"text": "BMCLAPI", "value": "bmcl"}]; onChoice: function(v) { root.setSetting("downloadSource", v) } }
                ChoiceRow { style: root.style; label: "游戏内容默认下载源"; description: "Mod、整合包等内容的默认站点。"; currentValue: root.settingText("defaultAddonSource"); choices: [{"text": "Modrinth", "value": "modrinth"}, {"text": "CurseForge", "value": "curseforge"}]; onChoice: function(v) { root.setSetting("defaultAddonSource", v) } }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "缓存与线程"
                subtitle: "集中缓存目录和并发下载线程数。"
                trailingText: root.settingBool("autoDownloadThreads") ? "自动线程" : root.settingText("downloadThreads") + " 线程"

                TextRow { style: root.style; label: "文件下载缓存目录"; description: "启动器将游戏资源和依赖库集中管理。"; valueText: root.settingText("commonDirectory"); onAccepted: function(v) { root.setSetting("commonDirType", v.length > 0 ? "custom" : "default"); root.setSetting("commonDirectory", v) } }
                SwitchRow { style: root.style; label: "自动选择线程数"; description: "线程数过高可能导致系统卡顿。"; checkedValue: root.settingBool("autoDownloadThreads"); onToggledValue: function(v) { root.setSetting("autoDownloadThreads", String(v)) } }
                TextRow { style: root.style; label: "线程数"; description: "建议范围 1-256。"; valueText: root.settingText("downloadThreads"); onAccepted: function(v) { root.setSetting("downloadThreads", v) } }
                ActionRow { style: root.style; label: "打开下载缓存目录"; description: "打开启动器下载缓存目录。"; actionText: "打开"; onAction: root.backend.openLauncherSpecialFolder("cache") }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "代理"
                subtitle: "系统代理、禁用代理、HTTP 或 SOCKS。"
                trailingText: proxyDisplay(root.settingText("proxyType"))

                ChoiceRow { style: root.style; label: "代理"; description: "使用系统代理 / 不使用代理 / HTTP / SOCKS。"; currentValue: root.settingText("proxyType"); choices: [{"text": "使用系统代理", "value": "default"}, {"text": "不使用代理", "value": "none"}, {"text": "HTTP", "value": "http"}, {"text": "SOCKS", "value": "socks"}]; onChoice: function(v) { root.setSetting("proxyType", v) } }
                TextRow { style: root.style; label: "IP 地址"; description: "代理服务器地址。"; valueText: root.settingText("proxyHost"); onAccepted: function(v) { root.setSetting("proxyHost", v) } }
                TextRow { style: root.style; label: "端口"; description: "代理服务器端口。"; valueText: root.settingText("proxyPort"); onAccepted: function(v) { root.setSetting("proxyPort", v) } }
                TextRow { style: root.style; label: "账户"; description: "代理身份验证账户。"; valueText: root.settingText("proxyUsername"); onAccepted: function(v) { root.setSetting("proxyUsername", v) } }
                TextRow { style: root.style; label: "密码"; description: "代理身份验证密码。"; password: true; valueText: root.settingText("proxyPassword"); onAccepted: function(v) { root.setSetting("proxyPassword", v) } }
            }
        }
    }

    Component {
        id: helpSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "帮助"; subtitle: "文档、排查和常用目录。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "文档"
                subtitle: "参考 HMCL 文档和 Minecraft Wiki。"
                trailingText: "外部链接"
                defaultExpanded: true

                LinkRow { style: root.style; label: "HMCL 帮助文档"; description: "查看 HMCL 文档和使用教程。"; url: "https://docs.hmcl.net/" }
                LinkRow { style: root.style; label: "Minecraft Wiki"; description: "查看 Minecraft 资料。"; url: "https://minecraft.wiki/" }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "排查"
                subtitle: "导出诊断信息、打开目录，便于后续定位问题。"
                trailingText: "诊断"

                ActionRow { style: root.style; label: "导出诊断信息"; description: "包含系统、配置目录和当前设置。"; actionText: "导出"; onAction: root.backend.exportLauncherDiagnostics() }
                ActionRow { style: root.style; label: "打开配置目录"; description: "打开配置文件目录。"; actionText: "打开"; onAction: root.backend.openLauncherSpecialFolder("config") }
                ActionRow { style: root.style; label: "打开数据目录"; description: "打开启动器数据目录。"; actionText: "打开"; onAction: root.backend.openLauncherSpecialFolder("data") }
                ActionRow { style: root.style; label: "打开 Minecraft 目录"; description: "打开默认 Minecraft 游戏目录。"; actionText: "打开"; onAction: root.backend.openLauncherSpecialFolder("minecraft") }
            }
        }
    }

    Component {
        id: feedbackSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "反馈"; subtitle: "提交 Issue 或查看项目仓库。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "反馈渠道"
                subtitle: "打开外部页面。"
                trailingText: "GitHub"
                defaultExpanded: true

                LinkRow { style: root.style; label: "GitHub Issues"; description: "提交 mc-launcher 的问题反馈。"; url: "https://github.com/Bihrys/mc-launcher/issues" }
                LinkRow { style: root.style; label: "项目仓库"; description: "查看源码、提交 Issue 或 Pull Request。"; url: "https://github.com/Bihrys/mc-launcher" }
                ActionRow { style: root.style; label: "导出诊断信息"; description: "附带给 Issue 更方便定位问题。"; actionText: "导出"; onAction: root.backend.exportLauncherDiagnostics() }
            }
        }
    }

    Component {
        id: aboutSectionComponent

        Column {
            width: parent ? parent.width : 0
            spacing: 10

            PageTitle { style: root.style; title: "关于"; subtitle: "启动器、依赖、致谢和许可证信息。" }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "mc-launcher"
                subtitle: "Rust + Qt/QML Minecraft 启动器。"
                trailingText: "0.1.0"
                defaultExpanded: true

                InfoRow { style: root.style; label: "名称"; description: "项目名称。"; valueText: "mc-launcher" }
                InfoRow { style: root.style; label: "版本"; description: "当前开发版本。"; valueText: "0.1.0" }
                LinkRow { style: root.style; label: "开源地址"; description: "https://github.com/Bihrys/mc-launcher"; url: "https://github.com/Bihrys/mc-launcher" }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "依赖组件"
                subtitle: "主要运行时和三方库。"
                trailingText: "Rust / Qt"

                ParagraphRow { style: root.style; label: "依赖"; description: "Rust / Qt 6 / Qt Quick / Qt Quick Controls / CXX-Qt / serde / serde_json / reqwest + rustls / uuid / sha1 / sha2 / base64 / flate2 / tar / image / authlib-injector" }
            }

            SettingsSublist {
                width: parent.width
                style: root.style
                title: "鸣谢与许可证"
                subtitle: "HMCL 及相关开源项目。"
                trailingText: "GPL 注意"

                ParagraphRow { style: root.style; label: "Hello Minecraft! Launcher"; description: "本项目参考了 Hello Minecraft! Launcher（HMCL）的界面布局、文件结构、任务系统和业务流程。若直接复制或派生 HMCL 代码与资源，发布时必须遵守相应 GPL 许可证。" }
                ParagraphRow { style: root.style; label: "开源致谢"; description: "感谢 HMCL 项目及其贡献者提供的开源实现参考。公开发布时请保留许可证、参考来源与致谢信息。" }
            }
        }
    }

    function launcherVisibilityDisplay(value) {
        if (value === "close") return "结束启动器"
        if (value === "keep") return "保持可见"
        return "隐藏启动器"
    }

    function themeModeDisplay(value) {
        if (value === "dark") return "深色模式"
        if (value === "system") return "跟随系统"
        return "浅色模式"
    }

    function updateChannelDisplay(value) {
        if (value === "development") return "开发版"
        return "稳定版"
    }

    function languageDisplay(value) {
        if (value === "en") return "English"
        return "简体中文"
    }

    function sourceDisplay(value) {
        if (value === "official") return "官方"
        if (value === "bmcl") return "BMCLAPI"
        return "自动/平衡"
    }

    function proxyDisplay(value) {
        if (value === "none") return "不使用代理"
        if (value === "http") return "HTTP"
        if (value === "socks") return "SOCKS"
        return "使用系统代理"
    }

    component PageTitle: Column {
        required property var style
        property string title: ""
        property string subtitle: ""

        width: parent ? parent.width : 600
        spacing: 4

        function styleValue(name, fallback) {
            if (style !== undefined && style !== null) {
                var value = style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Text { text: parent.title; color: parent.styleValue("cTextOnSurface", "#222222"); font.pixelSize: 22; font.bold: true }
        Text { width: parent.width; text: parent.subtitle; color: parent.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 12; wrapMode: Text.WordWrap }
        Item { width: 1; height: 4 }
    }

    component DrawerCategory: Item {
        id: drawerCategory
        required property var style
        property string label: ""
        width: parent ? parent.width : 200
        height: 34

        function styleValue(name, fallback) {
            if (drawerCategory.style !== undefined && drawerCategory.style !== null) {
                var value = drawerCategory.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 4
            Text { text: drawerCategory.label; color: drawerCategory.styleValue("cTextOnSurface", "#222222"); font.pixelSize: 12; height: 16; verticalAlignment: Text.AlignVCenter }
            Rectangle { width: parent.width; height: 1; color: drawerCategory.styleValue("cTextOnSurfaceVariant", "#777777"); opacity: 0.45 }
        }
    }

    component NavItem: Item {
        id: nav
        required property var style
        property string label: ""
        property string iconKind: ""
        property string section: ""
        property string currentSection: ""
        signal clicked(string section)

        width: parent ? parent.width : 200
        height: 52

        function styleValue(name, fallback) {
            if (nav.style !== undefined && nav.style !== null) {
                var value = nav.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Rectangle { anchors.fill: parent; color: nav.section === nav.currentSection ? nav.styleValue("cNavSelected", "#eeeeee") : "transparent" }
        Rectangle { anchors.fill: parent; color: nav.section !== nav.currentSection && navMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.045) : "transparent" }

        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nav.clicked(nav.section) }

        IconCanvas { anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; kind: nav.iconKind; drawColor: nav.styleValue("cTextOnSurface", "#222222") }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: nav.label
            color: nav.styleValue("cTextOnSurface", "#222222")
            font.pixelSize: 14
            font.bold: nav.section === nav.currentSection
            elide: Text.ElideRight
        }
    }

    component SettingsSublist: Column {
        id: sublist
        required property var style
        property string title: ""
        property string subtitle: ""
        property string trailingText: ""
        property bool defaultExpanded: false
        property bool expanded: defaultExpanded
        default property alias content: contentColumn.children

        width: parent ? parent.width : 600
        spacing: 0

        function styleValue(name, fallback) {
            if (sublist.style !== undefined && sublist.style !== null) {
                var value = sublist.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Rectangle {
            id: header
            width: parent.width
            height: sublist.subtitle.length > 0 ? 68 : 52
            color: headerMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.045) : sublist.styleValue("cSurface", "#ffffff")
            border.width: 0

            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: sublist.styleValue("cBorder", "#dddddd") }
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: sublist.styleValue("cBorder", "#dddddd") }

            MouseArea { id: headerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sublist.expanded = !sublist.expanded }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: trailing.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { width: parent.width; text: sublist.title; color: sublist.styleValue("cTextOnSurface", "#222222"); font.pixelSize: 14; elide: Text.ElideRight }
                Text { width: parent.width; visible: sublist.subtitle.length > 0; text: sublist.subtitle; color: sublist.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 12; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
            }

            Row {
                id: trailing
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text { width: Math.min(210, implicitWidth); text: sublist.trailingText; color: sublist.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 13; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "⌄"; rotation: sublist.expanded ? -180 : 0; color: sublist.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 18; width: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; anchors.verticalCenter: parent.verticalCenter; Behavior on rotation { NumberAnimation { duration: sublist.styleValue("motionLong2", 300); easing.type: Easing.InOutCubic } } }
            }
        }

        Item {
            id: contentClip
            width: parent.width
            height: sublist.expanded ? contentColumn.implicitHeight : 0
            clip: true
            visible: height > 0

            Behavior on height {
                NumberAnimation { duration: sublist.styleValue("motionLong2", 300); easing.type: Easing.InOutCubic }
            }

            Column {
                id: contentColumn
                width: parent.width
                spacing: 0
            }
        }
    }

    component BaseRow: Rectangle {
        id: row
        required property var style
        property string label: ""
        property string description: ""
        property int rowHeight: description.length > 0 ? 68 : 48
        width: parent ? parent.width : 600
        height: rowHeight
        color: row.styleValue("cSurface", "#ffffff")
        border.width: 0

        function styleValue(name, fallback) {
            if (row.style !== undefined && row.style !== null) {
                var value = row.style[name]
                if (value !== undefined && value !== null) return value
            }
            return fallback
        }

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: row.styleValue("cBorder", "#dddddd"); visible: row.y > 0 }

        Column {
            anchors.left: parent.left
            anchors.right: trailing.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 4
            Text { width: parent.width; text: row.label; color: row.styleValue("cTextOnSurface", "#222222"); font.pixelSize: 14; elide: Text.ElideRight }
            Text { width: parent.width; text: row.description; visible: row.description.length > 0; color: row.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 12; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
        }

        Item { id: trailing; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: Math.min(520, parent.width * 0.55); height: parent.height }
    }

    component InfoRow: BaseRow {
        id: infoRow
        property string valueText: ""
        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 260; horizontalAlignment: Text.AlignRight; text: infoRow.valueText; color: infoRow.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 13; elide: Text.ElideRight }
    }

    component ParagraphRow: BaseRow {
        id: paragraphRow
        rowHeight: Math.max(86, paragraph.implicitHeight + 36)
        Text { id: paragraph; anchors.right: parent.right; anchors.rightMargin: 16; anchors.left: parent.left; anchors.leftMargin: 220; anchors.verticalCenter: parent.verticalCenter; text: paragraphRow.description; color: paragraphRow.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 13; wrapMode: Text.WordWrap }
    }

    component TextRow: BaseRow {
        id: editRow
        property string valueText: ""
        property string suffix: ""
        property bool password: false
        signal accepted(string value)

        TextField {
            id: textInput
            anchors.right: parent.right
            anchors.rightMargin: editRow.suffix.length > 0 ? 86 : 16
            anchors.verticalCenter: parent.verticalCenter
            width: 230
            height: 32
            text: editRow.valueText
            echoMode: editRow.password ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            color: editRow.styleValue("cTextOnSurface", "#222222")
            placeholderTextColor: editRow.styleValue("cTextOnSurfaceVariant", "#666666")
            font.pixelSize: 13
            background: Rectangle {
                radius: 2
                color: "transparent"
                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: textInput.activeFocus ? editRow.styleValue("cButtonSelected", "#2f6fed") : editRow.styleValue("cTextOnSurfaceVariant", "#666666"); opacity: textInput.activeFocus ? 1.0 : 0.45 }
            }
            onAccepted: editRow.accepted(text)
            onEditingFinished: editRow.accepted(text)
        }

        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 62; text: editRow.suffix; visible: editRow.suffix.length > 0; color: editRow.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 13; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight }
    }

    component SwitchRow: BaseRow {
        id: switchRow
        property bool checkedValue: false
        signal toggledValue(bool value)
        Switch { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: switchRow.checkedValue; onToggled: switchRow.toggledValue(checked) }
    }

    component ChoiceRow: BaseRow {
        id: choiceRow
        property var choices: []
        property string currentValue: ""
        signal choice(string value)
        rowHeight: Math.max(68, choiceFlow.implicitHeight + 22)

        Flow {
            id: choiceFlow
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(520, parent.width * 0.55)
            spacing: 6

            Repeater {
                model: choiceRow.choices
                delegate: Rectangle {
                    width: Math.max(70, choiceText.implicitWidth + 24)
                    height: 28
                    radius: 14
                    color: modelData.value === choiceRow.currentValue ? choiceRow.styleValue("cButtonSelected", "#2f6fed") : choiceMouse.containsMouse ? choiceRow.styleValue("cButtonHover", "#eeeeee") : "transparent"
                    border.width: modelData.value === choiceRow.currentValue ? 0 : 1
                    border.color: choiceRow.styleValue("cBorder", "#dddddd")

                    Text { id: choiceText; anchors.centerIn: parent; text: modelData.text; color: modelData.value === choiceRow.currentValue ? choiceRow.styleValue("cButtonSelectedText", "#ffffff") : choiceRow.styleValue("cTextOnSurface", "#222222"); font.pixelSize: 13; font.bold: modelData.value === choiceRow.currentValue }
                    MouseArea { id: choiceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: choiceRow.choice(modelData.value) }
                }
            }
        }
    }

    component ActionRow: BaseRow {
        id: actionRow
        property string actionText: "执行"
        property bool actionEnabled: true
        signal action()

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(72, actionLabel.implicitWidth + 24)
            height: 30
            radius: 2
            opacity: actionRow.actionEnabled ? 1.0 : 0.45
            color: actionMouse.containsMouse && actionRow.actionEnabled ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
            Text { id: actionLabel; anchors.centerIn: parent; text: actionRow.actionText; color: actionRow.styleValue("cTextOnSurfaceVariant", "#666666"); font.pixelSize: 13 }
            MouseArea { id: actionMouse; anchors.fill: parent; enabled: actionRow.actionEnabled; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: actionRow.action() }
        }
    }

    component LinkRow: ActionRow {
        id: linkRow
        property string url: ""
        actionText: "打开"
        onAction: { if (url.length > 0) root.backend.openUrl(url) }
    }

    component IconCanvas: Canvas {
        id: iconCanvas
        property string kind: ""
        property color drawColor: "#222222"
        width: 32
        height: 32
        onKindChanged: requestPaint()
        onDrawColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.strokeStyle = drawColor
            ctx.fillStyle = drawColor
            ctx.lineWidth = 1.7
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.translate(6, 6)

            if (kind === "download") {
                ctx.beginPath(); ctx.moveTo(10, 2); ctx.lineTo(10, 12); ctx.moveTo(6, 8); ctx.lineTo(10, 12); ctx.lineTo(14, 8); ctx.moveTo(4, 16); ctx.lineTo(16, 16); ctx.stroke()
            } else if (kind === "help") {
                ctx.beginPath(); ctx.arc(10, 10, 8, 0, Math.PI * 2); ctx.stroke(); ctx.font = "bold 14px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText("?", 10, 10.5)
            } else if (kind === "info") {
                ctx.beginPath(); ctx.arc(10, 10, 8, 0, Math.PI * 2); ctx.stroke(); ctx.font = "bold 14px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText("i", 10, 10.5)
            } else if (kind === "feedback") {
                ctx.beginPath(); ctx.roundedRect(3, 4, 14, 11, 2, 2); ctx.stroke(); ctx.beginPath(); ctx.moveTo(7, 15); ctx.lineTo(6, 18); ctx.lineTo(10, 15); ctx.stroke()
            } else if (kind === "java") {
                ctx.beginPath(); ctx.moveTo(5, 14); ctx.quadraticCurveTo(10, 17, 15, 14); ctx.stroke(); ctx.beginPath(); ctx.moveTo(7, 4); ctx.quadraticCurveTo(13, 7, 8, 11); ctx.stroke(); ctx.beginPath(); ctx.moveTo(11, 3); ctx.quadraticCurveTo(17, 6, 12, 10); ctx.stroke()
            } else if (kind === "style") {
                ctx.beginPath(); ctx.arc(10, 10, 7, 0, Math.PI * 2); ctx.stroke(); ctx.beginPath(); ctx.arc(7, 8, 1.2, 0, Math.PI * 2); ctx.arc(11, 7, 1.2, 0, Math.PI * 2); ctx.arc(13, 11, 1.2, 0, Math.PI * 2); ctx.fill()
            } else if (kind === "tune") {
                ctx.beginPath(); ctx.moveTo(4, 6); ctx.lineTo(16, 6); ctx.moveTo(4, 10); ctx.lineTo(16, 10); ctx.moveTo(4, 14); ctx.lineTo(16, 14); ctx.stroke(); ctx.beginPath(); ctx.arc(8, 6, 2, 0, Math.PI * 2); ctx.arc(12, 10, 2, 0, Math.PI * 2); ctx.arc(7, 14, 2, 0, Math.PI * 2); ctx.fill()
            } else {
                ctx.beginPath(); ctx.roundedRect(4, 5, 12, 9, 2, 2); ctx.stroke(); ctx.beginPath(); ctx.moveTo(7, 16); ctx.lineTo(13, 16); ctx.stroke()
            }
            ctx.restore()
        }
    }
}
