import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    property string themeMode: "light"
    property string launcherVisibility: "hide"
    property string currentSection: "global"
    property string requestedSection: "global"
    property var settingsData: ({})
    property var loadedSections: ({ "global": true })

    // HMCL DecoratorAnimatedPage / ContainerAnimations.NAVIGATION 等价状态。
    property bool pageActive: false
    property bool pageAnimationReady: false
    property int navigationOffset: 30

    signal themeSelected(string mode)
    signal launcherVisibilitySelected(string mode)
    signal backRequested()

    Component.onCompleted: {
        if (root.requestedSection.length > 0) {
            root.currentSection = root.requestedSection
        }
        root.reloadSettings()
        root.ensureSectionLoaded(root.currentSection)
        root.pageAnimationReady = true

        if (root.pageActive) {
            root.playDecoratorEnter()
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

    onCurrentSectionChanged: {
        root.ensureSectionLoaded(root.currentSection)
    }

    onRequestedSectionChanged: {
        if (root.requestedSection.length > 0) {
            root.currentSection = root.requestedSection
            root.ensureSectionLoaded(root.currentSection)
        }
    }

    function playDecoratorEnter() {
        decoratorEnter.stop()
        decoratorExit.stop()

        if (!root.style.animationsEnabled) {
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

        if (!root.style.animationsEnabled) {
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

        SequentialAnimation {
            PauseAnimation {
                duration: root.style.motionShort4 / 2
            }

            ParallelAnimation {
                NumberAnimation {
                    target: settingsLeftPane
                    property: "x"
                    from: -root.navigationOffset
                    to: 0
                    duration: root.style.motionShort4 / 2
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: settingsLeftPane
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: root.style.motionShort4 / 2
                    easing.type: Easing.OutCubic
                }
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: root.style.motionShort4 / 2
            }

            ParallelAnimation {
                NumberAnimation {
                    target: settingsScroll
                    property: "x"
                    from: root.navigationOffset
                    to: 0
                    duration: root.style.motionShort4 / 2
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: settingsScroll
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: root.style.motionShort4 / 2
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    ParallelAnimation {
        id: decoratorExit

        ParallelAnimation {
            NumberAnimation {
                target: settingsLeftPane
                property: "x"
                from: 0
                to: -root.navigationOffset
                duration: root.style.motionShort4 / 2
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: settingsLeftPane
                property: "opacity"
                from: 1
                to: 0
                duration: root.style.motionShort4 / 2
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: settingsScroll
                property: "x"
                from: 0
                to: root.navigationOffset
                duration: root.style.motionShort4 / 2
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: settingsScroll
                property: "opacity"
                from: 1
                to: 0
                duration: root.style.motionShort4 / 2
                easing.type: Easing.InCubic
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // HMCL 设置页是独立页面；这里增加左上返回箭头。
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "transparent"

            Item {
                id: backButton

                width: 44
                height: 44
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: backMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                }

                Canvas {
                    anchors.centerIn: parent
                    width: 22
                    height: 22

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = root.style.cTextOnSurface
                        ctx.lineWidth = 1.8
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"

                        ctx.beginPath()
                        ctx.moveTo(13.5, 5)
                        ctx.lineTo(7.5, 11)
                        ctx.lineTo(13.5, 17)
                        ctx.stroke()
                    }
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 58
                anchors.verticalCenter: parent.verticalCenter
                text: "设置"
                color: root.style.cTextOnSurface
                font.pixelSize: 22
                font.bold: true
            }
        }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        // HMCL AdvancedListBox: limit width 200, transparent, content padding top 12.
        Rectangle {
            id: settingsLeftPane

            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "transparent"

            Flickable {
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: drawerColumn.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: drawerColumn

                    width: parent.width
                    y: 12
                    spacing: 0

                    NavItem {
                        style: root.style
                        label: "全局游戏设置"
                        iconKind: "game"
                        section: "global"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }

                    NavItem {
                        style: root.style
                        label: "Java 管理"
                        iconKind: "java"
                        section: "java"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }

                    DrawerCategory {
                        style: root.style
                        label: "启动器"
                    }

                    NavItem {
                        style: root.style
                        label: "通用"
                        iconKind: "tune"
                        section: "general"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }

                    NavItem {
                        style: root.style
                        label: "外观"
                        iconKind: "style"
                        section: "appearance"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }

                    NavItem {
                        style: root.style
                        label: "下载"
                        iconKind: "download"
                        section: "download"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }

                    DrawerCategory {
                        style: root.style
                        label: "帮助"
                    }

                    NavItem {
                        style: root.style
                        label: "帮助"
                        iconKind: "help"
                        section: "help"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }

                    NavItem {
                        style: root.style
                        label: "反馈"
                        iconKind: "feedback"
                        section: "feedback"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }

                    NavItem {
                        style: root.style
                        label: "关于"
                        iconKind: "info"
                        section: "about"
                        currentSection: root.currentSection
                        onClicked: root.currentSection = section
                    }
                }
            }
        }

        // HMCL transitionPane center.
        ScrollView {
            id: settingsScroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            Column {
                width: settingsScroll.availableWidth
                spacing: 10
                padding: 10

                                // 全局游戏设置
                Loader {
                    id: globalSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("global")
                    visible: root.currentSection === "global"
                    asynchronous: true
                    sourceComponent: globalSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                                // Java 管理
                Loader {
                    id: javaSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("java")
                    visible: root.currentSection === "java"
                    asynchronous: true
                    sourceComponent: javaSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                                // 通用
                Loader {
                    id: generalSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("general")
                    visible: root.currentSection === "general"
                    asynchronous: true
                    sourceComponent: generalSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                                // 外观
                Loader {
                    id: appearanceSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("appearance")
                    visible: root.currentSection === "appearance"
                    asynchronous: true
                    sourceComponent: appearanceSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                                // 下载
                Loader {
                    id: downloadSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("download")
                    visible: root.currentSection === "download"
                    asynchronous: true
                    sourceComponent: downloadSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                                // 帮助
                Loader {
                    id: helpSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("help")
                    visible: root.currentSection === "help"
                    asynchronous: true
                    sourceComponent: helpSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                                // 反馈
                Loader {
                    id: feedbackSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("feedback")
                    visible: root.currentSection === "feedback"
                    asynchronous: true
                    sourceComponent: feedbackSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                                // 关于
                Loader {
                    id: aboutSectionLoader
                    width: parent.width - 20
                    active: root.sectionLoaded("about")
                    visible: root.currentSection === "about"
                    asynchronous: true
                    sourceComponent: aboutSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }
            }
        }
    }
    }



    Component {
        id: globalSectionComponent

// 全局游戏设置
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "游戏" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        TextRow {
                            style: root.style
                            label: "最小内存"
                            description: "JVM -Xms，单位 MB。"
                            valueText: root.settingText("minMemoryMb")
                            suffix: "MB"
                            onAccepted: function(v) { root.setSetting("minMemoryMb", v) }
                        }

                        TextRow {
                            style: root.style
                            label: "最大内存"
                            description: "JVM -Xmx，单位 MB。"
                            valueText: root.settingText("maxMemoryMb")
                            suffix: "MB"
                            onAccepted: function(v) { root.setSetting("maxMemoryMb", v) }
                        }

                        TextRow {
                            style: root.style
                            label: "游戏窗口宽度"
                            description: "Minecraft 启动窗口宽度。"
                            valueText: root.settingText("gameWidth")
                            suffix: "px"
                            onAccepted: function(v) { root.setSetting("gameWidth", v) }
                        }

                        TextRow {
                            style: root.style
                            label: "游戏窗口高度"
                            description: "Minecraft 启动窗口高度。"
                            valueText: root.settingText("gameHeight")
                            suffix: "px"
                            onAccepted: function(v) { root.setSetting("gameHeight", v) }
                        }

                        SwitchRow {
                            style: root.style
                            label: "全屏启动"
                            description: "启动 Minecraft 时传入 --fullscreen。"
                            checkedValue: root.settingBool("fullscreen")
                            onToggledValue: function(v) { root.setSetting("fullscreen", String(v)) }
                        }

                        TextRow {
                            style: root.style
                            label: "Java 路径"
                            description: "留空时自动选择。"
                            valueText: root.settingText("javaPath")
                            suffix: ""
                            onAccepted: function(v) { root.setSetting("javaPath", v) }
                        }

                        ChoiceRow {
                            style: root.style
                            label: "启动器可见性"
                            description: "游戏启动后的启动器窗口处理方式。"
                            currentValue: root.launcherVisibility
                            choices: [
                                {"text": "游戏启动后结束启动器", "value": "close"},
                                {"text": "游戏启动后隐藏启动器", "value": "hide"},
                                {"text": "保持启动器可见", "value": "keep"},
                                {"text": "隐藏启动器并在游戏结束后重新打开", "value": "hide_and_reopen"}
                            ]
                            onChoice: function(v) {
                                root.launcherVisibility = v
                                root.setSetting("launcherVisibility", v)
                                root.launcherVisibilitySelected(v)
                            }
                        }

                        TextRow {
                            style: root.style
                            label: "游戏目录"
                            description: "实例独立工作目录。"
                            valueText: root.settingText("gameDir")
                            suffix: "待开发"
                            onAccepted: function(v) { root.setSetting("gameDir", v) }
                        }
                    }
                }
    }

    Component {
        id: javaSectionComponent

// Java 管理
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "Java" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        SwitchRow {
                            style: root.style
                            label: "自动选择 Java"
                            description: "启动时根据游戏版本要求自动选择 Java。"
                            checkedValue: root.settingBool("javaAuto")
                            onToggledValue: function(v) { root.setSetting("javaAuto", String(v)) }
                        }

                        TextRow {
                            style: root.style
                            label: "Java 路径"
                            description: "手动指定 Java 可执行文件。"
                            valueText: root.settingText("javaPath")
                            suffix: ""
                            onAccepted: function(v) { root.setSetting("javaPath", v) }
                        }

                        TextRow {
                            style: root.style
                            label: "Java 虚拟机参数"
                            description: "额外 JVM 参数。"
                            valueText: root.settingText("jvmArgs")
                            suffix: "待开发"
                            onAccepted: function(v) { root.setSetting("jvmArgs", v) }
                        }

                        ActionRow {
                            style: root.style
                            label: "检测本机 Java"
                            description: "调用当前项目 Java 检测后端。"
                            actionText: "检测"
                            onAction: root.backend.detectJava()
                        }

                        ActionRow {
                            style: root.style
                            label: "下载 Java"
                            description: "Java 下载入口。"
                            actionText: "待开发"
                            actionEnabled: false
                        }
                    }
                }
    }

    Component {
        id: generalSectionComponent

// 通用
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "更新" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        ChoiceRow {
                            style: root.style
                            label: "更新通道"
                            description: "检查启动器更新。"
                            currentValue: root.settingText("updateChannel")
                            choices: [
                                {"text": "稳定版", "value": "stable"},
                                {"text": "开发版", "value": "development"}
                            ]
                            onChoice: function(v) { root.setSetting("updateChannel", v) }
                            devNote: "待开发"
                        }

                        SwitchRow {
                            style: root.style
                            label: "接收测试版更新"
                            description: "对应 HMCL 的预览版更新。"
                            checkedValue: root.settingBool("acceptPreviewUpdate")
                            onToggledValue: function(v) { root.setSetting("acceptPreviewUpdate", String(v)) }
                            devNote: "待开发"
                        }

                        SwitchRow {
                            style: root.style
                            label: "不自动显示更新对话框"
                            description: "对应 HMCL 的自动更新提示。"
                            checkedValue: root.settingBool("disableAutoShowUpdateDialog")
                            onToggledValue: function(v) { root.setSetting("disableAutoShowUpdateDialog", String(v)) }
                            devNote: "待开发"
                        }
                    }

                    SettingsTitle { style: root.style; label: "语言" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        ChoiceRow {
                            style: root.style
                            label: "语言"
                            description: "更改后重启生效。"
                            currentValue: root.settingText("language")
                            choices: [
                                {"text": "简体中文", "value": "zh_CN"},
                                {"text": "English", "value": "en"}
                            ]
                            onChoice: function(v) { root.setSetting("language", v) }
                            devNote: "待开发"
                        }

                        SwitchRow {
                            style: root.style
                            label: "不自动切换游戏语言"
                            description: "对应 HMCL disableAutoGameOptions。"
                            checkedValue: root.settingBool("disableAutoGameOptions")
                            onToggledValue: function(v) { root.setSetting("disableAutoGameOptions", String(v)) }
                        }
                    }

                    SettingsTitle { style: root.style; label: "杂项" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        SwitchRow {
                            style: root.style
                            label: "在主页内显示游戏列表"
                            description: "对应 HMCL 首页游戏列表。"
                            checkedValue: root.settingBool("enableGameList")
                            onToggledValue: function(v) { root.setSetting("enableGameList", String(v)) }
                            devNote: "待开发"
                        }

                        SwitchRow {
                            style: root.style
                            label: "允许启动器修改游戏"
                            description: "允许通过 Java Agent 改善游戏体验；外置登录已接入 authlib-injector。"
                            checkedValue: root.settingBool("allowAutoAgent")
                            onToggledValue: function(v) { root.setSetting("allowAutoAgent", String(v)) }
                        }
                    }

                    SettingsTitle { style: root.style; label: "日志" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        TextRow {
                            style: root.style
                            label: "日志字体"
                            description: "对应 HMCL 日志字体。"
                            valueText: root.settingText("logFont")
                            suffix: ""
                            onAccepted: function(v) { root.setSetting("logFont", v) }
                            devNote: "待开发"
                        }

                        ActionRow {
                            style: root.style
                            label: "导出启动器日志"
                            description: "导出当前启动器日志。"
                            actionText: "待开发"
                            actionEnabled: false
                        }

                        ActionRow {
                            style: root.style
                            label: "打开日志目录"
                            description: "打开启动器日志文件夹。"
                            actionText: "待开发"
                            actionEnabled: false
                        }
                    }
                }
    }

    Component {
        id: appearanceSectionComponent

// 外观
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "外观" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        ChoiceRow {
                            style: root.style
                            label: "主题模式"
                            description: "切换浅色、深色或跟随系统。"
                            currentValue: root.themeMode
                            choices: [
                                {"text": "浅色模式", "value": "light"},
                                {"text": "深色模式", "value": "dark"},
                                {"text": "跟随系统设置", "value": "system"}
                            ]
                            onChoice: function(v) {
                                root.themeMode = v
                                root.setSetting("themeMode", v)
                                root.themeSelected(v)
                            }
                        }

                        ChoiceRow {
                            style: root.style
                            label: "主题色"
                            description: "对应 HMCL 主题色。"
                            currentValue: root.settingText("themeColor")
                            choices: [
                                {"text": "默认", "value": "default"},
                                {"text": "紫色", "value": "purple"},
                                {"text": "蓝色", "value": "blue"},
                                {"text": "绿色", "value": "green"}
                            ]
                            onChoice: function(v) { root.setSetting("themeColor", v) }
                            devNote: "待开发"
                        }

                        SwitchRow {
                            style: root.style
                            label: "标题栏透明"
                            description: "对应 HMCL title_transparent。"
                            checkedValue: root.settingBool("titleTransparent")
                            onToggledValue: function(v) { root.setSetting("titleTransparent", String(v)) }
                            devNote: "待开发"
                        }

                        SwitchRow {
                            style: root.style
                            label: "关闭动画"
                            description: "对应 HMCL turn_off_animations。"
                            checkedValue: root.settingBool("turnOffAnimations")
                            onToggledValue: function(v) { root.setSetting("turnOffAnimations", String(v)) }
                            devNote: "待开发"
                        }

                        ChoiceRow {
                            style: root.style
                            label: "反锯齿"
                            description: "对应 HMCL 字体反锯齿。"
                            currentValue: root.settingText("fontAntiAliasing")
                            choices: [
                                {"text": "自动", "value": "auto"},
                                {"text": "灰阶", "value": "gray"},
                                {"text": "子像素", "value": "lcd"}
                            ]
                            onChoice: function(v) { root.setSetting("fontAntiAliasing", v) }
                            devNote: "待开发"
                        }
                    }
                }
    }

    Component {
        id: downloadSectionComponent

// 下载
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "下载来源" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        SwitchRow {
                            style: root.style
                            label: "自动选择下载源"
                            description: "自动选择合适的下载源。"
                            checkedValue: root.settingBool("autoChooseDownloadSource")
                            onToggledValue: function(v) { root.setSetting("autoChooseDownloadSource", String(v)) }
                        }

                        ChoiceRow {
                            style: root.style
                            label: "版本列表来源"
                            description: "版本清单下载来源。"
                            currentValue: root.settingText("versionListSource")
                            choices: [
                                {"text": "平衡", "value": "balanced"},
                                {"text": "官方优先", "value": "official"},
                                {"text": "镜像优先", "value": "mirror"}
                            ]
                            onChoice: function(v) { root.setSetting("versionListSource", v) }
                        }

                        ChoiceRow {
                            style: root.style
                            label: "下载源"
                            description: "游戏文件、资源文件、依赖库下载源。"
                            currentValue: root.settingText("downloadSource")
                            choices: [
                                {"text": "官方", "value": "mojang"},
                                {"text": "BMCLAPI", "value": "bmclapi"}
                            ]
                            onChoice: function(v) { root.setSetting("downloadSource", v) }
                        }

                        ChoiceRow {
                            style: root.style
                            label: "游戏内容默认下载源"
                            description: "Modrinth 或 CurseForge。"
                            currentValue: root.settingText("defaultAddonSource")
                            choices: [
                                {"text": "Modrinth", "value": "modrinth"},
                                {"text": "CurseForge", "value": "curseforge"}
                            ]
                            onChoice: function(v) { root.setSetting("defaultAddonSource", v) }
                        }
                    }

                    SettingsTitle { style: root.style; label: "下载" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        TextRow {
                            style: root.style
                            label: "文件下载缓存目录"
                            description: "启动器将游戏资源和依赖库集中管理。"
                            valueText: root.settingText("commonDirectory")
                            suffix: ""
                            onAccepted: function(v) {
                                root.setSetting("commonDirType", v.length > 0 ? "custom" : "default")
                                root.setSetting("commonDirectory", v)
                            }
                        }

                        SwitchRow {
                            style: root.style
                            label: "自动选择线程数"
                            description: "线程数过高可能导致系统卡顿。"
                            checkedValue: root.settingBool("autoDownloadThreads")
                            onToggledValue: function(v) { root.setSetting("autoDownloadThreads", String(v)) }
                        }

                        TextRow {
                            style: root.style
                            label: "线程数"
                            description: "HMCL 范围 1-256。"
                            valueText: root.settingText("downloadThreads")
                            suffix: ""
                            onAccepted: function(v) { root.setSetting("downloadThreads", v) }
                        }
                    }

                    SettingsTitle { style: root.style; label: "代理" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        ChoiceRow {
                            style: root.style
                            label: "代理"
                            description: "使用系统代理 / 不使用代理 / HTTP / SOCKS。"
                            currentValue: root.settingText("proxyType")
                            choices: [
                                {"text": "使用系统代理", "value": "default"},
                                {"text": "不使用代理", "value": "none"},
                                {"text": "HTTP", "value": "http"},
                                {"text": "SOCKS", "value": "socks"}
                            ]
                            onChoice: function(v) { root.setSetting("proxyType", v) }
                            devNote: "待开发"
                        }

                        TextRow { style: root.style; label: "IP 地址"; description: "代理服务器地址。"; valueText: root.settingText("proxyHost"); suffix: "待开发"; onAccepted: function(v) { root.setSetting("proxyHost", v) } }
                        TextRow { style: root.style; label: "端口"; description: "代理服务器端口。"; valueText: root.settingText("proxyPort"); suffix: "待开发"; onAccepted: function(v) { root.setSetting("proxyPort", v) } }
                        TextRow { style: root.style; label: "账户"; description: "代理身份验证账户。"; valueText: root.settingText("proxyUsername"); suffix: "待开发"; onAccepted: function(v) { root.setSetting("proxyUsername", v) } }
                        TextRow { style: root.style; label: "密码"; description: "代理身份验证密码。"; valueText: root.settingText("proxyPassword"); password: true; suffix: "待开发"; onAccepted: function(v) { root.setSetting("proxyPassword", v) } }
                    }
                }
    }

    Component {
        id: helpSectionComponent

// 帮助
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "帮助" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        LinkRow { style: root.style; label: "HMCL 帮助文档"; description: "查看 HMCL 文档和使用教程。"; url: "https://docs.hmcl.net/" }
                        LinkRow { style: root.style; label: "Minecraft Wiki"; description: "查看 Minecraft 资料。"; url: "https://minecraft.wiki/" }
                        ActionRow { style: root.style; label: "启动问题排查"; description: "Java、游戏文件、外置登录、下载源等检查。"; actionText: "待开发"; actionEnabled: false }
                        ActionRow { style: root.style; label: "导出游戏崩溃信息"; description: "用于反馈和求助。"; actionText: "待开发"; actionEnabled: false }
                    }
                }
    }

    Component {
        id: feedbackSectionComponent

// 反馈
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "反馈" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        LinkRow { style: root.style; label: "GitHub Issues"; description: "提交 mc-launcher 的问题反馈。"; url: "https://github.com/Bihrys/mc-launcher/issues" }
                        LinkRow { style: root.style; label: "项目仓库"; description: "查看源码、提交 Issue 或 Pull Request。"; url: "https://github.com/Bihrys/mc-launcher" }
                        ActionRow { style: root.style; label: "导出诊断信息"; description: "包含启动器日志、游戏日志、系统信息。"; actionText: "待开发"; actionEnabled: false }
                    }
                }
    }

    Component {
        id: aboutSectionComponent

// 关于
                Column {
                    width: parent ? parent.width : 0
                    spacing: 10

                    SettingsTitle { style: root.style; label: "关于" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        InfoRow { style: root.style; label: "mc-launcher"; description: "Rust + Qt/QML Minecraft 启动器"; valueText: "0.1.0" }
                        LinkRow { style: root.style; label: "开源地址"; description: "https://github.com/Bihrys/mc-launcher"; url: "https://github.com/Bihrys/mc-launcher" }
                        LinkRow { style: root.style; label: "开发者"; description: "https://github.com/Bihrys"; url: "https://github.com/Bihrys" }
                    }

                    SettingsTitle { style: root.style; label: "依赖组件" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        ParagraphRow {
                            style: root.style
                            label: "依赖"
                            description: "Rust / Qt 6 / Qt Quick / Qt Quick Controls / CXX-Qt / launcher-core / launcher-qt / serde / serde_json / reqwest + rustls / uuid / sha1 / sha2 / base64 / flate2 / tar / image / authlib-injector"
                        }
                    }

                    SettingsTitle { style: root.style; label: "鸣谢" }

                    OptionList {
                        width: parent.width
                        style: root.style

                        ParagraphRow {
                            style: root.style
                            label: "Hello Minecraft! Launcher"
                            description: "本项目参考了 Hello Minecraft! Launcher（HMCL）的界面布局、设置结构、启动流程、任务对话框、账户系统和外置登录逻辑。这里是 Qt/QML 等价实现，不是直接复制 JavaFX 控件。"
                        }

                        ParagraphRow {
                            style: root.style
                            label: "开源致谢"
                            description: "感谢 HMCL 项目及其贡献者提供的开源实现参考。公开发布时请保留相应许可证、参考来源与致谢信息。"
                        }
                    }
                }
    }

    function ensureSectionLoaded(section) {
        if (!section || section.length === 0) {
            return
        }

        if (root.loadedSections[section] === true) {
            return
        }

        var next = {}
        for (var key in root.loadedSections) {
            next[key] = root.loadedSections[key]
        }
        next[section] = true

        // QML var 对象要整体重新赋值，绑定才会刷新。
        root.loadedSections = next
    }

    function sectionLoaded(section) {
        return root.loadedSections[section] === true
    }

    function reloadSettings() {
        var raw = root.backend.refreshLauncherSettings()
        try {
            root.settingsData = JSON.parse(raw || "{}")
        } catch (e) {
            root.settingsData = {}
        }

        if (root.settingsData.themeMode) {
            root.themeMode = root.settingsData.themeMode
        }

        if (root.settingsData.launcherVisibility) {
            root.launcherVisibility = root.settingsData.launcherVisibility
        }
    }

    function setSetting(key, value) {
        root.settingsData[key] = value
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

    component DrawerCategory: Item {
        id: drawerCategory

        required property var style
        property string label: ""

        width: parent ? parent.width : 200
        height: 34

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            spacing: 4

            Text {
                text: drawerCategory.label
                color: drawerCategory.style.cTextOnSurface
                font.pixelSize: 12
                height: 16
                verticalAlignment: Text.AlignVCenter
                leftPadding: 0
            }

            Rectangle {
                width: parent.width
                height: 1
                color: drawerCategory.style.cTextOnSurfaceVariant
                opacity: 0.45
            }
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

        Rectangle {
            anchors.fill: parent
            color: nav.section === nav.currentSection
                   ? nav.style.cNavSelected
                   : "transparent"
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked(nav.section)
        }

        Rectangle {
            anchors.fill: parent
            color: nav.section !== nav.currentSection && navMouse.containsMouse
                   ? Qt.rgba(0, 0, 0, 0.045)
                   : "transparent"
        }

        Item {
            id: iconBox
            width: 32
            height: 32
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: iconCanvas
                anchors.centerIn: parent
                width: 20
                height: 20

                property color drawColor: nav.style.cTextOnSurface
                property string kind: nav.iconKind

                onDrawColorChanged: requestPaint()
                onKindChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = drawColor
                    ctx.fillStyle = drawColor
                    ctx.lineWidth = 1.7
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    if (kind === "download") {
                        ctx.beginPath()
                        ctx.moveTo(10, 3)
                        ctx.lineTo(10, 12)
                        ctx.moveTo(6, 8)
                        ctx.lineTo(10, 12)
                        ctx.lineTo(14, 8)
                        ctx.moveTo(4, 16)
                        ctx.lineTo(16, 16)
                        ctx.stroke()
                    } else if (kind === "help") {
                        ctx.beginPath()
                        ctx.arc(10, 10, 8, 0, Math.PI * 2)
                        ctx.stroke()
                        ctx.font = "bold 14px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillText("?", 10, 10.5)
                    } else if (kind === "info") {
                        ctx.beginPath()
                        ctx.arc(10, 10, 8, 0, Math.PI * 2)
                        ctx.stroke()
                        ctx.font = "bold 14px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillText("i", 10, 10.5)
                    } else if (kind === "feedback") {
                        ctx.beginPath()
                        ctx.roundedRect(3, 4, 14, 11, 2, 2)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(7, 15)
                        ctx.lineTo(6, 18)
                        ctx.lineTo(10, 15)
                        ctx.stroke()
                    } else if (kind === "java") {
                        ctx.beginPath()
                        ctx.moveTo(5, 14)
                        ctx.quadraticCurveTo(10, 17, 15, 14)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(7, 4)
                        ctx.quadraticCurveTo(13, 7, 8, 11)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(11, 3)
                        ctx.quadraticCurveTo(17, 6, 12, 10)
                        ctx.stroke()
                    } else if (kind === "style") {
                        ctx.beginPath()
                        ctx.arc(10, 10, 7, 0, Math.PI * 2)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(7, 8, 1.2, 0, Math.PI * 2)
                        ctx.arc(11, 7, 1.2, 0, Math.PI * 2)
                        ctx.arc(13, 11, 1.2, 0, Math.PI * 2)
                        ctx.fill()
                    } else if (kind === "tune") {
                        ctx.beginPath()
                        ctx.moveTo(4, 6)
                        ctx.lineTo(16, 6)
                        ctx.moveTo(4, 10)
                        ctx.lineTo(16, 10)
                        ctx.moveTo(4, 14)
                        ctx.lineTo(16, 14)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(8, 6, 2, 0, Math.PI * 2)
                        ctx.arc(12, 10, 2, 0, Math.PI * 2)
                        ctx.arc(7, 14, 2, 0, Math.PI * 2)
                        ctx.fill()
                    } else {
                        ctx.beginPath()
                        ctx.roundedRect(4, 5, 12, 9, 2, 2)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(7, 16)
                        ctx.lineTo(13, 16)
                        ctx.stroke()
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16 + 32 + 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: nav.label
            color: nav.style.cTextOnSurface
            font.pixelSize: 14
            font.bold: nav.section === nav.currentSection
            elide: Text.ElideRight
        }
    }

    component SettingsTitle: Item {
        id: settingsTitle

        required property var style
        property string label: ""

        width: parent ? parent.width : 600
        height: 28

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: settingsTitle.label
            color: settingsTitle.style.cTextOnSurface
            font.pixelSize: 14
        }
    }

    component OptionList: Column {
        id: list

        required property var style
        default property alias content: list.children

        spacing: 0

        layer.enabled: true
        layer.effect: null
    }

    component BaseRow: Rectangle {
        id: row

        required property var style
        property string label: ""
        property string description: ""
        property string devNote: ""
        property bool firstRow: false
        property bool lastRow: false
        property int rowHeight: description.length > 0 ? 68 : 48

        width: parent ? parent.width : 600
        height: rowHeight
        color: row.style.cSurface
        radius: 0
        border.width: 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: row.style.cBorder
            visible: row.y > 0
        }

        Column {
            anchors.left: parent.left
            anchors.right: trailing.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 4

            Text {
                width: parent.width
                text: row.label
                color: row.style.cTextOnSurface
                font.pixelSize: 14
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: row.description
                visible: row.description.length > 0
                color: row.style.cTextOnSurfaceVariant
                font.pixelSize: 12
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
        }

        Item {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(500, parent.width * 0.55)
            height: parent.height
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            visible: row.devNote.length > 0
            text: row.devNote
            color: row.style.cTextOnSurfaceVariant
            opacity: 0.75
            font.pixelSize: 11
        }
    }

    component InfoRow: BaseRow {
        id: infoRow

        property string valueText: ""

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 220
            horizontalAlignment: Text.AlignRight
            text: infoRow.valueText
            color: infoRow.style.cTextOnSurfaceVariant
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    component ParagraphRow: BaseRow {
        id: paragraphRow

        rowHeight: Math.max(78, paragraph.implicitHeight + 36)

        Text {
            id: paragraph
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 220
            anchors.verticalCenter: parent.verticalCenter
            text: paragraphRow.description
            color: paragraphRow.style.cTextOnSurfaceVariant
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
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
            color: editRow.style.cTextOnSurface
            placeholderTextColor: editRow.style.cTextOnSurfaceVariant
            font.pixelSize: 13
            background: Rectangle {
                radius: 2
                color: "transparent"
                border.width: 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: textInput.activeFocus ? editRow.style.cButtonSelected : editRow.style.cTextOnSurfaceVariant
                    opacity: textInput.activeFocus ? 1.0 : 0.45
                }
            }
            onAccepted: editRow.accepted(text)
            onEditingFinished: editRow.accepted(text)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 62
            text: editRow.suffix
            visible: editRow.suffix.length > 0
            color: editRow.style.cTextOnSurfaceVariant
            font.pixelSize: 13
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    component SwitchRow: BaseRow {
        id: switchRow

        property bool checkedValue: false

        signal toggledValue(bool value)

        Switch {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            checked: switchRow.checkedValue
            onToggled: switchRow.toggledValue(checked)
        }
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
                    color: modelData.value === choiceRow.currentValue
                           ? choiceRow.style.cButtonSelected
                           : mouse.containsMouse ? choiceRow.style.cButtonHover : "transparent"
                    border.width: modelData.value === choiceRow.currentValue ? 0 : 1
                    border.color: choiceRow.style.cBorder

                    Text {
                        id: choiceText
                        anchors.centerIn: parent
                        text: modelData.text
                        color: modelData.value === choiceRow.currentValue
                               ? choiceRow.style.cButtonSelectedText
                               : choiceRow.style.cTextOnSurface
                        font.pixelSize: 13
                        font.bold: modelData.value === choiceRow.currentValue
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choiceRow.choice(modelData.value)
                    }
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
            color: actionMouse.containsMouse && actionRow.actionEnabled ? Qt.rgba(0,0,0,0.06) : "transparent"

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: actionRow.actionText
                color: actionRow.style.cTextOnSurfaceVariant
                font.pixelSize: 13
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                enabled: actionRow.actionEnabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: actionRow.action()
            }
        }
    }

    component LinkRow: ActionRow {
        id: linkRow

        property string url: ""

        actionText: "打开"
        onAction: {
            if (url.length > 0) {
                Qt.openUrlExternally(url)
            }
        }
    }
}
