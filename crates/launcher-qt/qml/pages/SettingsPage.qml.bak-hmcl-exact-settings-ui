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
    property var settingsData: ({})

    signal themeSelected(string mode)
    signal launcherVisibilitySelected(string mode)

    Component.onCompleted: root.reloadSettings()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            radius: 4
            color: root.style.cSurfaceContainerHigh
            border.width: 0

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                Text {
                    width: parent.width
                    height: 38
                    text: "设置"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 18
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 6
                }

                NavCategory { style: root.style; label: "GAME" }

                SettingsNavButton { style: root.style; label: "全局游戏设置"; section: "global"; currentSection: root.currentSection; onClicked: root.currentSection = section }
                SettingsNavButton { style: root.style; label: "Java 管理"; section: "java"; currentSection: root.currentSection; onClicked: root.currentSection = section }

                NavCategory { style: root.style; label: "LAUNCHER" }

                SettingsNavButton { style: root.style; label: "通用"; section: "general"; currentSection: root.currentSection; onClicked: root.currentSection = section }
                SettingsNavButton { style: root.style; label: "外观"; section: "appearance"; currentSection: root.currentSection; onClicked: root.currentSection = section }
                SettingsNavButton { style: root.style; label: "下载"; section: "download"; currentSection: root.currentSection; onClicked: root.currentSection = section }

                NavCategory { style: root.style; label: "HELP" }

                SettingsNavButton { style: root.style; label: "帮助"; section: "help"; currentSection: root.currentSection; onClicked: root.currentSection = section }
                SettingsNavButton { style: root.style; label: "反馈"; section: "feedback"; currentSection: root.currentSection; onClicked: root.currentSection = section }
                SettingsNavButton { style: root.style; label: "关于"; section: "about"; currentSection: root.currentSection; onClicked: root.currentSection = section }
            }
        }

        ScrollView {
            id: settingsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            Column {
                width: settingsScroll.availableWidth
                spacing: 10

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "global"

                    PageHeader { style: root.style; titleText: "全局游戏设置"; subtitleText: "对应 HMCL 的全局游戏设置。这里的配置会进入默认启动参数。" }
                    SectionTitle { style: root.style; label: "游戏" }

                    TextEditRow { style: root.style; label: "最小内存"; description: "JVM -Xms，单位 MB。"; valueText: root.settingText("minMemoryMb"); suffix: "MB"; onAccepted: function(v) { root.setSetting("minMemoryMb", v) } }
                    TextEditRow { style: root.style; label: "最大内存"; description: "JVM -Xmx，单位 MB。"; valueText: root.settingText("maxMemoryMb"); suffix: "MB"; onAccepted: function(v) { root.setSetting("maxMemoryMb", v) } }
                    TextEditRow { style: root.style; label: "窗口宽度"; description: "Minecraft 启动窗口宽度。"; valueText: root.settingText("gameWidth"); suffix: "px"; onAccepted: function(v) { root.setSetting("gameWidth", v) } }
                    TextEditRow { style: root.style; label: "窗口高度"; description: "Minecraft 启动窗口高度。"; valueText: root.settingText("gameHeight"); suffix: "px"; onAccepted: function(v) { root.setSetting("gameHeight", v) } }
                    SwitchRow { style: root.style; label: "全屏启动"; description: "启动 Minecraft 时传入 --fullscreen。"; checkedValue: root.settingBool("fullscreen"); onToggledValue: function(v) { root.setSetting("fullscreen", String(v)) } }
                    TextEditRow { style: root.style; label: "指定 Java 路径"; description: "留空时自动选择。"; valueText: root.settingText("javaPath"); suffix: ""; onAccepted: function(v) { root.setSetting("javaPath", v) } }

                    ChoiceRow {
                        style: root.style
                        label: "启动器可见性"
                        description: "对应 HMCL 的 LauncherVisibility。"
                        choices: [
                            {"text": "启动后关闭", "value": "close"},
                            {"text": "启动后隐藏", "value": "hide"},
                            {"text": "保持可见", "value": "keep"},
                            {"text": "隐藏并重开", "value": "hide_and_reopen"}
                        ]
                        currentValue: root.launcherVisibility
                        onChoice: function(v) {
                            root.launcherVisibility = v
                            root.setSetting("launcherVisibility", v)
                            root.launcherVisibilitySelected(v)
                        }
                    }

                    TextEditRow { style: root.style; label: "游戏目录"; description: "实例独立工作目录。当前启动流程暂未完全接入。"; valueText: root.settingText("gameDir"); suffix: "待开发"; onAccepted: function(v) { root.setSetting("gameDir", v) } }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "java"

                    PageHeader { style: root.style; titleText: "Java 管理"; subtitleText: "对应 HMCL 的 Java 管理。当前项目已有 Java 检测和下载后端。" }
                    SectionTitle { style: root.style; label: "Java" }

                    SwitchRow { style: root.style; label: "自动选择 Java"; description: "启动时根据版本要求自动选择 Java。"; checkedValue: root.settingBool("javaAuto"); onToggledValue: function(v) { root.setSetting("javaAuto", String(v)) } }
                    TextEditRow { style: root.style; label: "Java 路径"; description: "手动指定 Java 可执行文件。"; valueText: root.settingText("javaPath"); suffix: ""; onAccepted: function(v) { root.setSetting("javaPath", v) } }
                    TextEditRow { style: root.style; label: "JVM 参数"; description: "额外 JVM 参数。当前保存配置，启动参数接入待开发。"; valueText: root.settingText("jvmArgs"); suffix: "待开发"; onAccepted: function(v) { root.setSetting("jvmArgs", v) } }
                    ActionRow { style: root.style; label: "检测本机 Java"; description: "调用当前项目的 Java 检测后端。"; actionText: "检测"; onAction: root.backend.detectJava() }
                    ActionRow { style: root.style; label: "下载 Java"; description: "下载页/Java 页已有下载入口，这里保留 HMCL 设置入口。"; actionText: "打开 Java 页面"; onAction: root.backend.detectJava() }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "general"

                    PageHeader { style: root.style; titleText: "通用"; subtitleText: "对应 HMCL 启动器设置里的更新、语言、杂项、日志、调试等。" }
                    SectionTitle { style: root.style; label: "语言" }

                    ChoiceRow {
                        style: root.style
                        label: "语言"
                        description: "当前界面先固定中文，后端保存配置。"
                        choices: [
                            {"text": "简体中文", "value": "zh_CN"},
                            {"text": "English", "value": "en"}
                        ]
                        currentValue: root.settingText("language")
                        onChoice: function(v) { root.setSetting("language", v) }
                    }

                    SectionTitle { style: root.style; label: "杂项" }
                    SwitchRow { style: root.style; label: "在主页内显示版本列表"; description: "对应 HMCL enable_game_list。"; checkedValue: root.settingBool("enableGameList"); onToggledValue: function(v) { root.setSetting("enableGameList", String(v)) } }
                    SwitchRow { style: root.style; label: "允许启动器修改游戏"; description: "对应 HMCL allow_auto_agent。外置登录已通过 authlib-injector 接入。"; checkedValue: root.settingBool("allowAutoAgent"); onToggledValue: function(v) { root.setSetting("allowAutoAgent", String(v)) } }
                    SwitchRow { style: root.style; label: "不自动切换游戏语言"; description: "对应 HMCL disable_auto_game_options。"; checkedValue: root.settingBool("disableAutoGameOptions"); onToggledValue: function(v) { root.setSetting("disableAutoGameOptions", String(v)) } }

                    SectionTitle { style: root.style; label: "日志与调试" }
                    TextEditRow { style: root.style; label: "日志字体"; description: "对应 HMCL log.font。"; valueText: root.settingText("logFont"); suffix: ""; onAccepted: function(v) { root.setSetting("logFont", v) } }
                    ActionRow { style: root.style; label: "导出启动器日志"; description: "对应 HMCL 导出日志。"; actionText: "待开发"; enabled: false }
                    ActionRow { style: root.style; label: "打开日志文件夹"; description: "对应 HMCL 打开日志文件夹。"; actionText: "待开发"; enabled: false }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "appearance"

                    PageHeader { style: root.style; titleText: "外观"; subtitleText: "对应 HMCL 的个性化/外观设置。" }
                    SectionTitle { style: root.style; label: "主题" }

                    ChoiceRow {
                        style: root.style
                        label: "主题模式"
                        description: "浅色、深色或跟随系统。"
                        choices: [
                            {"text": "浅色", "value": "light"},
                            {"text": "深色", "value": "dark"},
                            {"text": "跟随系统", "value": "system"}
                        ]
                        currentValue: root.themeMode
                        onChoice: function(v) {
                            root.themeMode = v
                            root.setSetting("themeMode", v)
                            root.themeSelected(v)
                        }
                    }

                    ChoiceRow {
                        style: root.style
                        label: "主题色"
                        description: "当前保存配置，完整 Monet 色板待开发。"
                        choices: [
                            {"text": "默认", "value": "default"},
                            {"text": "紫色", "value": "purple"},
                            {"text": "蓝色", "value": "blue"},
                            {"text": "绿色", "value": "green"}
                        ]
                        currentValue: root.settingText("themeColor")
                        onChoice: function(v) { root.setSetting("themeColor", v) }
                    }

                    SwitchRow { style: root.style; label: "标题栏透明"; description: "对应 HMCL title_transparent。"; checkedValue: root.settingBool("titleTransparent"); onToggledValue: function(v) { root.setSetting("titleTransparent", String(v)) } }
                    SwitchRow { style: root.style; label: "关闭动画"; description: "对应 HMCL turn_off_animations。"; checkedValue: root.settingBool("turnOffAnimations"); onToggledValue: function(v) { root.setSetting("turnOffAnimations", String(v)) } }

                    ChoiceRow {
                        style: root.style
                        label: "字体抗锯齿"
                        description: "对应 HMCL font.anti_aliasing。"
                        choices: [
                            {"text": "自动", "value": "auto"},
                            {"text": "灰度", "value": "gray"},
                            {"text": "子像素", "value": "lcd"}
                        ]
                        currentValue: root.settingText("fontAntiAliasing")
                        onChoice: function(v) { root.setSetting("fontAntiAliasing", v) }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "download"

                    PageHeader { style: root.style; titleText: "下载"; subtitleText: "对应 HMCL 下载设置：下载源、缓存、线程数、代理。" }
                    SectionTitle { style: root.style; label: "下载源" }

                    SwitchRow { style: root.style; label: "自动选择下载源"; description: "对应 HMCL autoChooseDownloadSource。"; checkedValue: root.settingBool("autoChooseDownloadSource"); onToggledValue: function(v) { root.setSetting("autoChooseDownloadSource", String(v)) } }

                    ChoiceRow {
                        style: root.style
                        label: "版本列表源"
                        description: "官方 / BMCLAPI / 自动。"
                        choices: [
                            {"text": "自动", "value": "auto"},
                            {"text": "官方", "value": "mojang"},
                            {"text": "BMCLAPI", "value": "bmclapi"}
                        ]
                        currentValue: root.settingText("versionListSource")
                        onChoice: function(v) { root.setSetting("versionListSource", v) }
                    }

                    ChoiceRow {
                        style: root.style
                        label: "下载源"
                        description: "游戏文件、资源文件、依赖库下载源。"
                        choices: [
                            {"text": "自动", "value": "auto"},
                            {"text": "官方", "value": "mojang"},
                            {"text": "BMCLAPI", "value": "bmclapi"}
                        ]
                        currentValue: root.settingText("downloadSource")
                        onChoice: function(v) { root.setSetting("downloadSource", v) }
                    }

                    ChoiceRow {
                        style: root.style
                        label: "游戏内容默认下载源"
                        description: "对应 HMCL defaultAddonSource。"
                        choices: [
                            {"text": "Modrinth", "value": "modrinth"},
                            {"text": "CurseForge", "value": "curseforge"}
                        ]
                        currentValue: root.settingText("defaultAddonSource")
                        onChoice: function(v) { root.setSetting("defaultAddonSource", v) }
                    }

                    SectionTitle { style: root.style; label: "缓存" }
                    TextEditRow { style: root.style; label: "文件下载缓存目录"; description: "对应 HMCL common directory。留空使用默认路径。"; valueText: root.settingText("commonDirectory"); suffix: ""; onAccepted: function(v) { root.setSetting("commonDirectory", v) } }
                    ActionRow { style: root.style; label: "清理缓存"; description: "删除下载缓存和临时文件。"; actionText: "待开发"; enabled: false }

                    SectionTitle { style: root.style; label: "线程数" }
                    SwitchRow { style: root.style; label: "自动选择线程数"; description: "对应 HMCL autoDownloadThreads。"; checkedValue: root.settingBool("autoDownloadThreads"); onToggledValue: function(v) { root.setSetting("autoDownloadThreads", String(v)) } }
                    TextEditRow { style: root.style; label: "线程数"; description: "HMCL 范围 1-256。当前保存配置，下载器接入待开发。"; valueText: root.settingText("downloadThreads"); suffix: ""; onAccepted: function(v) { root.setSetting("downloadThreads", v) } }

                    SectionTitle { style: root.style; label: "代理" }
                    ChoiceRow {
                        style: root.style
                        label: "代理"
                        description: "使用系统代理 / 不使用代理 / HTTP / SOCKS。"
                        choices: [
                            {"text": "系统代理", "value": "default"},
                            {"text": "不使用", "value": "none"},
                            {"text": "HTTP", "value": "http"},
                            {"text": "SOCKS", "value": "socks"}
                        ]
                        currentValue: root.settingText("proxyType")
                        onChoice: function(v) { root.setSetting("proxyType", v) }
                    }
                    TextEditRow { style: root.style; label: "代理主机"; description: "HTTP/SOCKS 主机。"; valueText: root.settingText("proxyHost"); suffix: ""; onAccepted: function(v) { root.setSetting("proxyHost", v) } }
                    TextEditRow { style: root.style; label: "代理端口"; description: "HTTP/SOCKS 端口。"; valueText: root.settingText("proxyPort"); suffix: ""; onAccepted: function(v) { root.setSetting("proxyPort", v) } }
                    TextEditRow { style: root.style; label: "代理账户"; description: "代理身份验证账户。"; valueText: root.settingText("proxyUsername"); suffix: ""; onAccepted: function(v) { root.setSetting("proxyUsername", v) } }
                    TextEditRow { style: root.style; label: "代理密码"; description: "代理身份验证密码。"; valueText: root.settingText("proxyPassword"); suffix: ""; password: true; onAccepted: function(v) { root.setSetting("proxyPassword", v) } }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "help"

                    PageHeader { style: root.style; titleText: "帮助"; subtitleText: "对应 HMCL 帮助页。" }
                    LinkRow { style: root.style; label: "HMCL 帮助文档"; description: "查看 HMCL 文档和使用教程。"; url: "https://docs.hmcl.net/" }
                    LinkRow { style: root.style; label: "Minecraft Wiki"; description: "查看 Minecraft 资料。"; url: "https://minecraft.wiki/" }
                    ActionRow { style: root.style; label: "启动问题排查"; description: "Java、游戏文件、外置登录、下载源等检查。"; actionText: "待开发"; enabled: false }
                    ActionRow { style: root.style; label: "导出游戏崩溃信息"; description: "用于反馈和求助。"; actionText: "待开发"; enabled: false }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "feedback"

                    PageHeader { style: root.style; titleText: "反馈"; subtitleText: "对应 HMCL 反馈页。" }
                    LinkRow { style: root.style; label: "GitHub Issues"; description: "提交 mc-launcher 的问题反馈。"; url: "https://github.com/Bihrys/mc-launcher/issues" }
                    LinkRow { style: root.style; label: "项目仓库"; description: "查看源码、提交 Issue 或 Pull Request。"; url: "https://github.com/Bihrys/mc-launcher" }
                    ActionRow { style: root.style; label: "导出诊断信息"; description: "包含启动器日志、游戏日志、系统信息。"; actionText: "待开发"; enabled: false }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.currentSection === "about"

                    PageHeader { style: root.style; titleText: "关于"; subtitleText: "mc-launcher" }

                    SectionTitle { style: root.style; label: "项目" }
                    InfoRow { style: root.style; label: "mc-launcher"; description: "Rust + Qt/QML Minecraft 启动器"; valueText: "0.1.0" }
                    LinkRow { style: root.style; label: "开源地址"; description: "https://github.com/Bihrys/mc-launcher"; url: "https://github.com/Bihrys/mc-launcher" }
                    LinkRow { style: root.style; label: "开发者"; description: "https://github.com/Bihrys"; url: "https://github.com/Bihrys" }

                    SectionTitle { style: root.style; label: "依赖组件" }
                    ParagraphBlock {
                        style: root.style
                        body: "Rust / Qt 6 / Qt Quick / Qt Quick Controls / CXX-Qt / launcher-core / launcher-qt / serde / serde_json / reqwest + rustls / uuid / sha1 / sha2 / base64 / flate2 / tar / image / authlib-injector"
                    }

                    SectionTitle { style: root.style; label: "鸣谢" }
                    ParagraphBlock {
                        style: root.style
                        body: "本项目参考了 Hello Minecraft! Launcher（HMCL）的界面布局、设置结构、启动流程、任务对话框、账户系统和外置登录逻辑。这里是 Qt/QML 等价实现，不是直接复制 JavaFX 控件。"
                    }

                    ParagraphBlock {
                        style: root.style
                        body: "感谢 HMCL 项目及其贡献者提供的开源实现参考。公开发布时请继续保留相应开源许可证、参考来源与致谢信息。"
                    }
                }
            }
        }
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

    component NavCategory: Text {
        required property var style
        property string label: ""

        width: parent ? parent.width : 180
        height: 24
        text: label
        color: style.cTextOnSurfaceVariant
        font.pixelSize: 11
        font.bold: true
        verticalAlignment: Text.AlignBottom
        leftPadding: 8
    }

    component SettingsNavButton: Rectangle {
        id: nav

        required property var style
        property string label: ""
        property string section: ""
        property string currentSection: ""

        signal clicked(string section)

        width: parent ? parent.width : 180
        height: 36
        radius: 4
        color: section === currentSection ? style.cNavSelected : mouse.containsMouse ? style.cNavHover : "transparent"

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked(nav.section)
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            text: nav.label
            color: nav.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: nav.section === nav.currentSection
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    component PageHeader: Item {
        required property var style
        property string titleText: ""
        property string subtitleText: ""

        width: parent ? parent.width : 600
        height: 58

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: titleText
            color: style.cTextOnSurface
            font.pixelSize: 24
            font.bold: true
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 34
            text: subtitleText
            color: style.cTextOnSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    component SectionTitle: Text {
        required property var style
        property string label: ""

        width: parent ? parent.width : 600
        height: 24
        text: label
        color: style.cTextOnSurfaceVariant
        font.pixelSize: 12
        font.bold: true
        verticalAlignment: Text.AlignBottom
    }

    component BaseRow: Rectangle {
        id: row

        required property var style
        property string label: ""
        property string description: ""
        property int rowHeight: 60

        width: parent ? parent.width : 600
        height: rowHeight
        radius: 4
        color: style.cSurfaceContainerHigh
        border.width: 0

        Column {
            anchors.left: parent.left
            anchors.right: trailing.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
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
                font.pixelSize: 11
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
        }

        Item {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(460, parent.width * 0.52)
            height: parent.height
        }
    }

    component InfoRow: BaseRow {
        property string valueText: ""

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            horizontalAlignment: Text.AlignRight
            text: valueText
            color: style.cTextOnSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    component TextEditRow: BaseRow {
        id: editRow

        property string valueText: ""
        property string suffix: ""
        property bool password: false

        signal accepted(string value)

        TextField {
            id: textInput
            anchors.right: parent.right
            anchors.rightMargin: editRow.suffix.length > 0 ? 82 : 14
            anchors.verticalCenter: parent.verticalCenter
            width: 210
            height: 34
            text: editRow.valueText
            echoMode: editRow.password ? TextInput.Password : TextInput.Normal
            selectByMouse: true
            color: editRow.style.cTextOnSurface
            placeholderTextColor: editRow.style.cTextOnSurfaceVariant
            background: Rectangle {
                radius: 3
                color: editRow.style.cButtonSurface
                border.width: 1
                border.color: textInput.activeFocus ? editRow.style.cButtonSelected : editRow.style.cBorder
            }
            onAccepted: editRow.accepted(text)
            onEditingFinished: editRow.accepted(text)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 62
            text: editRow.suffix
            visible: editRow.suffix.length > 0
            color: editRow.style.cTextOnSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    component SwitchRow: BaseRow {
        id: switchRow

        property bool checkedValue: false

        signal toggledValue(bool value)

        Switch {
            anchors.right: parent.right
            anchors.rightMargin: 14
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

        rowHeight: 72

        Flow {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(460, parent.width * 0.52)
            spacing: 6

            Repeater {
                model: choiceRow.choices

                delegate: Rectangle {
                    width: Math.max(68, labelText.implicitWidth + 24)
                    height: 30
                    radius: 15
                    color: modelData.value === choiceRow.currentValue
                           ? choiceRow.style.cButtonSelected
                           : optionMouse.containsMouse ? choiceRow.style.cButtonHover : choiceRow.style.cButtonSurface
                    border.width: modelData.value === choiceRow.currentValue ? 0 : 1
                    border.color: choiceRow.style.cBorder

                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        text: modelData.text
                        color: modelData.value === choiceRow.currentValue
                               ? choiceRow.style.cButtonSelectedText
                               : choiceRow.style.cTextOnSurface
                        font.pixelSize: 12
                        font.bold: modelData.value === choiceRow.currentValue
                    }

                    MouseArea {
                        id: optionMouse
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
        property bool enabled: true

        signal action()

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(78, actionLabel.implicitWidth + 24)
            height: 32
            radius: 16
            opacity: actionRow.enabled ? 1.0 : 0.45
            color: actionMouse.containsMouse && actionRow.enabled ? actionRow.style.cButtonHover : actionRow.style.cButtonSurface
            border.width: 1
            border.color: actionRow.style.cBorder

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: actionRow.actionText
                color: actionRow.style.cTextOnSurface
                font.pixelSize: 12
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                enabled: actionRow.enabled
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

    component ParagraphBlock: Rectangle {
        required property var style
        property string body: ""

        width: parent ? parent.width : 600
        height: Math.max(72, paragraphText.implicitHeight + 28)
        radius: 4
        color: style.cSurfaceContainerHigh
        border.width: 0

        Text {
            id: paragraphText
            anchors.fill: parent
            anchors.margins: 14
            text: parent.body
            color: parent.style.cTextOnSurfaceVariant
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
