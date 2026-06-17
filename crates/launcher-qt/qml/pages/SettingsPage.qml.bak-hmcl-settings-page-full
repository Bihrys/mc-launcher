import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    property string themeMode: "light"
    property string launcherVisibility: "hide"
    property string currentSection: "global"

    signal themeSelected(string mode)
    signal launcherVisibilitySelected(string mode)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 190
            Layout.fillHeight: true
            radius: 4
            color: root.style.cSurfaceContainerHigh
            border.width: 0

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text {
                    width: parent.width
                    height: 32
                    text: "设置"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 18
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                SettingsNavButton {
                    style: root.style
                    title: "全局游戏设置"
                    page: "global"
                    currentPage: root.currentSection
                    onClicked: function(page) { root.currentSection = page }
                }

                SettingsNavButton {
                    style: root.style
                    title: "Java 管理"
                    page: "java"
                    currentPage: root.currentSection
                    onClicked: function(page) { root.currentSection = page }
                }

                SettingsNavButton {
                    style: root.style
                    title: "通用"
                    page: "general"
                    currentPage: root.currentSection
                    onClicked: function(page) { root.currentSection = page }
                }

                SettingsNavButton {
                    style: root.style
                    title: "下载"
                    page: "download"
                    currentPage: root.currentSection
                    onClicked: function(page) { root.currentSection = page }
                }

                SettingsNavButton {
                    style: root.style
                    title: "帮助"
                    page: "help"
                    currentPage: root.currentSection
                    onClicked: function(page) { root.currentSection = page }
                }

                SettingsNavButton {
                    style: root.style
                    title: "反馈"
                    page: "feedback"
                    currentPage: root.currentSection
                    onClicked: function(page) { root.currentSection = page }
                }

                SettingsNavButton {
                    style: root.style
                    title: "关于"
                    page: "about"
                    currentPage: root.currentSection
                    onClicked: function(page) { root.currentSection = page }
                }
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
                spacing: 14

                // 全局游戏设置
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentSection === "global"

                    PageHeader {
                        style: root.style
                        title: "全局游戏设置"
                        subtitle: "对应 HMCL 的“全局游戏设置”。没有启用实例特定游戏设置的实例共用这里的设置。"
                    }

                    SectionLabel { style: root.style; text: "游戏" }

                    LineItem {
                        style: root.style
                        title: "游戏 Java"
                        subtitle: "自动选择合适的 Java"
                        statusText: "已接入启动流程"
                    }

                    LineItem {
                        style: root.style
                        title: "最大内存"
                        subtitle: "设置 Minecraft JVM 最大内存。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "游戏窗口分辨率"
                        subtitle: "宽度、高度、全屏。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "运行路径"
                        subtitle: "对应 HMCL 的工作目录。建议模组实例独立目录。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "启动器可见性"
                        subtitle: "游戏启动后的启动器窗口处理方式。"
                        rowHeight: 92

                        Flow {
                            width: 430
                            spacing: 8

                            SelectOption {
                                style: root.style
                                text: "启动后关闭"
                                mode: "close"
                                selected: root.launcherVisibility === "close"
                                widthOverride: 102
                                onClicked: root.launcherVisibilitySelected(mode)
                            }

                            SelectOption {
                                style: root.style
                                text: "启动后隐藏"
                                mode: "hide"
                                selected: root.launcherVisibility === "hide"
                                widthOverride: 102
                                onClicked: root.launcherVisibilitySelected(mode)
                            }

                            SelectOption {
                                style: root.style
                                text: "保持可见"
                                mode: "keep"
                                selected: root.launcherVisibility === "keep"
                                widthOverride: 88
                                onClicked: root.launcherVisibilitySelected(mode)
                            }

                            SelectOption {
                                style: root.style
                                text: "隐藏并重开"
                                mode: "hide_and_reopen"
                                selected: root.launcherVisibility === "hide_and_reopen"
                                widthOverride: 104
                                onClicked: root.launcherVisibilitySelected(mode)
                            }
                        }
                    }

                    SectionLabel { style: root.style; text: "管理" }

                    LineItem {
                        style: root.style
                        title: "复制全局游戏设置"
                        subtitle: "复制到实例特定游戏设置。"
                        statusText: "待开发"
                    }
                }

                // Java 管理
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentSection === "java"

                    PageHeader {
                        style: root.style
                        title: "Java 管理"
                        subtitle: "对应 HMCL 的 Java 管理。当前项目已经有独立 Java 页面，这里先把 HMCL 设置入口统一进设置页。"
                    }

                    SectionLabel { style: root.style; text: "Java" }

                    LineItem {
                        style: root.style
                        title: "自动检测 Java"
                        subtitle: "扫描系统 Java 运行时，用于启动时自动选择。"
                        statusText: "已接入"
                    }

                    LineItem {
                        style: root.style
                        title: "指定 Java 路径"
                        subtitle: "手动选择 Java 可执行文件。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "下载 Java"
                        subtitle: "按 Minecraft 版本安装合适的 Java。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "Java 参数"
                        subtitle: "全局 JVM 参数、GC 参数和额外启动参数。"
                        statusText: "待开发"
                    }
                }

                // 通用
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentSection === "general"

                    PageHeader {
                        style: root.style
                        title: "通用"
                        subtitle: "对应 HMCL 的启动器设置：外观、语言、杂项、日志、调试。"
                    }

                    SectionLabel { style: root.style; text: "外观" }

                    LineItem {
                        style: root.style
                        title: "主题模式"
                        subtitle: "浅色、深色或跟随系统。"
                        rowHeight: 82

                        Row {
                            spacing: 8

                            SelectOption {
                                style: root.style
                                text: "浅色"
                                mode: "light"
                                selected: root.themeMode === "light"
                                onClicked: root.themeSelected(mode)
                            }

                            SelectOption {
                                style: root.style
                                text: "深色"
                                mode: "dark"
                                selected: root.themeMode === "dark"
                                onClicked: root.themeSelected(mode)
                            }

                            SelectOption {
                                style: root.style
                                text: "跟随系统"
                                mode: "system"
                                selected: root.themeMode === "system"
                                widthOverride: 92
                                onClicked: root.themeSelected(mode)
                            }
                        }
                    }

                    LineItem {
                        style: root.style
                        title: "主题色"
                        subtitle: "对应 HMCL 的主题色。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "标题栏透明"
                        subtitle: "对应 HMCL 的标题栏透明。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "关闭动画"
                        subtitle: "对应 HMCL 的关闭动画选项。"
                        statusText: "待开发"
                    }

                    SectionLabel { style: root.style; text: "语言" }

                    LineItem {
                        style: root.style
                        title: "语言"
                        subtitle: "当前界面语言。"
                        statusText: "简体中文"
                    }

                    LineItem {
                        style: root.style
                        title: "不自动切换游戏语言"
                        subtitle: "对应 HMCL 的 disableAutoGameOptions。"
                        statusText: "待开发"
                    }

                    SectionLabel { style: root.style; text: "杂项" }

                    LineItem {
                        style: root.style
                        title: "在主页内显示版本列表"
                        subtitle: "对应 HMCL 的主页版本列表。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "允许启动器修改游戏"
                        subtitle: "允许通过 Java Agent 改善游戏体验；外置登录已使用 authlib-injector。"
                        statusText: "部分已接入"
                    }

                    SectionLabel { style: root.style; text: "日志与调试" }

                    LineItem {
                        style: root.style
                        title: "导出启动器日志"
                        subtitle: "导出当前启动器日志文件。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "打开日志文件夹"
                        subtitle: "打开启动器日志目录。"
                        statusText: "待开发"
                    }
                }

                // 下载
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentSection === "download"

                    PageHeader {
                        style: root.style
                        title: "下载"
                        subtitle: "对应 HMCL 的下载设置：下载源、缓存目录、线程数、代理。"
                    }

                    SectionLabel { style: root.style; text: "下载源" }

                    LineItem {
                        style: root.style
                        title: "自动选择下载源"
                        subtitle: "根据网络情况自动选择下载源。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "版本列表源"
                        subtitle: "官方 / BMCLAPI / 自动。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "下载源"
                        subtitle: "游戏文件、资源文件、依赖库下载源。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "游戏内容默认下载源"
                        subtitle: "Modrinth / CurseForge。"
                        statusText: "待开发"
                    }

                    SectionLabel { style: root.style; text: "缓存" }

                    LineItem {
                        style: root.style
                        title: "文件下载缓存目录"
                        subtitle: "当前项目使用 ~/.local/share/mc-launcher/minecraft 作为主要数据目录。"
                        statusText: "部分已接入"
                    }

                    LineItem {
                        style: root.style
                        title: "清理缓存"
                        subtitle: "清理下载缓存和临时文件。"
                        statusText: "待开发"
                    }

                    SectionLabel { style: root.style; text: "线程数" }

                    LineItem {
                        style: root.style
                        title: "自动选择线程数"
                        subtitle: "线程数过高可能导致系统卡顿。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "线程数"
                        subtitle: "HMCL 可设置 1-256。"
                        statusText: "待开发"
                    }

                    SectionLabel { style: root.style; text: "代理" }

                    LineItem {
                        style: root.style
                        title: "代理"
                        subtitle: "使用系统代理 / 不使用代理 / HTTP / SOCKS。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "身份验证"
                        subtitle: "代理用户名和密码。"
                        statusText: "待开发"
                    }
                }

                // 帮助
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentSection === "help"

                    PageHeader {
                        style: root.style
                        title: "帮助"
                        subtitle: "对应 HMCL 的帮助入口。"
                    }

                    SectionLabel { style: root.style; text: "帮助" }

                    LinkItem {
                        style: root.style
                        title: "Hello Minecraft! Launcher 帮助文档"
                        subtitle: "可查阅资料包、模组包制作教程等内容。"
                        url: "https://docs.hmcl.net/"
                    }

                    LineItem {
                        style: root.style
                        title: "启动问题排查"
                        subtitle: "Java、游戏文件、外置登录、下载源等问题检查。"
                        statusText: "待开发"
                    }

                    LineItem {
                        style: root.style
                        title: "导出游戏崩溃信息"
                        subtitle: "用于反馈和求助。"
                        statusText: "待开发"
                    }
                }

                // 反馈
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentSection === "feedback"

                    PageHeader {
                        style: root.style
                        title: "反馈"
                        subtitle: "对应 HMCL 的反馈入口。"
                    }

                    SectionLabel { style: root.style; text: "提交反馈" }

                    LinkItem {
                        style: root.style
                        title: "GitHub Issues"
                        subtitle: "提交 mc-launcher 的问题反馈。"
                        url: "https://github.com/Bihrys/mc-launcher/issues"
                    }

                    LinkItem {
                        style: root.style
                        title: "项目仓库"
                        subtitle: "查看源码、提交 Issue 或 Pull Request。"
                        url: "https://github.com/Bihrys/mc-launcher"
                    }

                    LineItem {
                        style: root.style
                        title: "导出诊断信息"
                        subtitle: "包含启动器日志、游戏日志、系统信息。"
                        statusText: "待开发"
                    }
                }

                // 关于
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentSection === "about"

                    PageHeader {
                        style: root.style
                        title: "关于"
                        subtitle: "mc-launcher"
                    }

                    SectionLabel { style: root.style; text: "项目" }

                    LineItem {
                        style: root.style
                        title: "mc-launcher"
                        subtitle: "Rust + Qt/QML Minecraft 启动器"
                        statusText: "0.1.0"
                    }

                    LinkItem {
                        style: root.style
                        title: "开源地址"
                        subtitle: "https://github.com/Bihrys/mc-launcher"
                        url: "https://github.com/Bihrys/mc-launcher"
                    }

                    LinkItem {
                        style: root.style
                        title: "开发者"
                        subtitle: "https://github.com/Bihrys"
                        url: "https://github.com/Bihrys"
                    }

                    SectionLabel { style: root.style; text: "依赖组件" }

                    InfoBlock {
                        style: root.style
                        text: "Rust / Qt 6 / Qt Quick / Qt Quick Controls / CXX-Qt / launcher-core / launcher-qt / serde / serde_json / reqwest + rustls / uuid / sha1 / sha2 / base64 / flate2 / tar / image / authlib-injector"
                    }

                    SectionLabel { style: root.style; text: "鸣谢" }

                    InfoBlock {
                        style: root.style
                        text: "本项目参考了 Hello Minecraft! Launcher（HMCL）的界面布局、启动流程、任务对话框、账户与外置登录逻辑。这里是 Qt/QML 等价实现，不是直接复制 JavaFX 控件。"
                    }

                    InfoBlock {
                        style: root.style
                        text: "感谢 HMCL 项目及其贡献者提供的开源实现参考。若公开发布，请继续保留相应开源许可证与致谢信息。"
                    }
                }
            }
        }
    }

    component SettingsNavButton: Rectangle {
        id: nav

        required property var style
        property string title: ""
        property string page: ""
        property string currentPage: ""

        signal clicked(string page)

        width: parent ? parent.width : 170
        height: 38
        radius: 4
        color: page === currentPage
               ? style.cNavSelected
               : mouse.containsMouse ? style.cNavHover : "transparent"

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked(nav.page)
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 24
            text: nav.title
            color: nav.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: nav.page === nav.currentPage
            elide: Text.ElideRight
        }
    }

    component PageHeader: Item {
        required property var style
        property string title: ""
        property string subtitle: ""

        width: parent ? parent.width : 600
        height: 58

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: title
            color: style.cTextOnSurface
            font.pixelSize: 24
            font.bold: true
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 34
            text: subtitle
            color: style.cTextOnSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    component SectionLabel: Text {
        required property var style
        property string text: ""

        width: parent ? parent.width : 600
        height: 24
        text: SectionLabel.text
        color: style.cTextOnSurfaceVariant
        font.pixelSize: 12
        font.bold: true
        verticalAlignment: Text.AlignBottom
    }

    component LineItem: Rectangle {
        id: line

        required property var style
        property string title: ""
        property string subtitle: ""
        property string statusText: ""
        property int rowHeight: 64
        default property alias content: trailingSlot.data

        width: parent ? parent.width : 600
        height: rowHeight
        radius: 4
        color: style.cSurfaceContainerHigh
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Text {
                    width: parent.width
                    text: line.title
                    color: line.style.cTextOnSurface
                    font.pixelSize: 14
                    font.bold: false
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: line.subtitle
                    visible: line.subtitle.length > 0
                    color: line.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Item {
                id: trailingSlot
                Layout.preferredWidth: line.statusText.length > 0 ? 112 : 440
                Layout.fillHeight: true

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: line.statusText.length > 0
                    text: line.statusText
                    color: line.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
    }

    component LinkItem: LineItem {
        id: linkLine

        property string url: ""

        statusText: "打开"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (linkLine.url.length > 0) {
                    Qt.openUrlExternally(linkLine.url)
                }
            }
        }
    }

    component InfoBlock: Rectangle {
        required property var style
        property string text: ""

        width: parent ? parent.width : 600
        height: Math.max(72, infoText.implicitHeight + 28)
        radius: 4
        color: style.cSurfaceContainerHigh
        border.width: 0

        Text {
            id: infoText
            anchors.fill: parent
            anchors.margins: 14
            text: parent.text
            color: style.cTextOnSurfaceVariant
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    component SelectOption: Rectangle {
        id: option

        required property var style
        property string text: ""
        property string mode: ""
        property bool selected: false
        property int widthOverride: 0

        signal clicked(string mode)

        width: widthOverride > 0 ? widthOverride : 62
        height: 30
        radius: 15

        color: selected
               ? style.cButtonSelected
               : optionMouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: selected ? 0 : 1
        border.color: style.cBorder

        Text {
            anchors.centerIn: parent
            text: option.text
            color: option.selected ? option.style.cButtonSelectedText : option.style.cTextOnSurface
            font.pixelSize: 12
            font.bold: option.selected
        }

        MouseArea {
            id: optionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: option.clicked(option.mode)
        }
    }
}
