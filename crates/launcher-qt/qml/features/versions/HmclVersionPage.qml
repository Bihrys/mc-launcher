pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

Item {
    id: root

    required property var style
    required property var backend
    property string versionId: ""

    readonly property string iconBase: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/"
    property string currentTab: "settings"
    property var detail: ({})
    property var summary: ({})
    property var settingsData: ({})
    property bool actionMenuOpen: false
    property bool browseMenuOpen: false
    property string promptMode: ""
    property string promptTitle: ""
    property string promptText: ""
    property string promptValue: ""
    property bool promptCheck: false

    property var mods: []
    property string modSearchText: ""

    onCurrentTabChanged: {
        if (root.currentTab === "mods" && root.versionId.length > 0) {
            root.reloadMods()
        }
    }

    function reloadMods() {
        var raw = root.backend.refreshInstanceMods(root.versionId)
        try {
            var parsed = JSON.parse(raw)
            root.mods = parsed.mods || []
        } catch (e) {
            root.mods = []
        }
    }

    ListModel { id: folderModel }
    ListModel { id: loaderModel }

    Component.onCompleted: root.reloadDetail()

    onVersionIdChanged: {
        if (versionId.length > 0) {
            root.reloadDetail()
            if (root.currentTab === "mods") root.reloadMods()
        }
    }

    Connections {
        target: root.backend

        function onInstanceDetailJsonChanged() {
            root.applyDetailJson(root.backend.instanceDetailJson)
        }

        function onInstanceModsJsonChanged() {
            try {
                var parsed = JSON.parse(root.backend.instanceModsJson)
                root.mods = parsed.mods || []
            } catch (e) {
                root.mods = []
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: root.style.sidebarWidthValue
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        width: root.style.sidebarWidthValue
                        spacing: 0

                        Item { width: 1; height: 12 }

                        NavTab {
                            style: root.style
                            title: "游戏设置"
                            iconKind: "SETTINGS"
                            active: root.currentTab === "settings"
                            onClicked: root.currentTab = "settings"
                        }

                        NavTab {
                            style: root.style
                            title: "安装器"
                            iconKind: "DEPLOYED_CODE"
                            active: root.currentTab === "installers"
                            onClicked: root.currentTab = "installers"
                        }

                        NavTab {
                            style: root.style
                            title: "Mod"
                            iconKind: "EXTENSION"
                            active: root.currentTab === "mods"
                            onClicked: root.currentTab = "mods"
                        }

                        NavTab {
                            style: root.style
                            title: "资源包"
                            iconKind: "TEXTURE"
                            active: root.currentTab === "resourcepacks"
                            onClicked: root.currentTab = "resourcepacks"
                        }

                        NavTab {
                            style: root.style
                            title: "世界"
                            iconKind: "PUBLIC"
                            active: root.currentTab === "worlds"
                            onClicked: root.currentTab = "worlds"
                        }

                        NavTab {
                            style: root.style
                            title: "结构"
                            iconKind: "SCHEMA"
                            active: root.currentTab === "schematics"
                            onClicked: root.currentTab = "schematics"
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40 * 4 + 24

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 0

                        NavTab {
                            style: root.style
                            title: "游戏升级"
                            iconKind: "UPDATE"
                            active: false
                            visible: !!root.summary.isModpack
                            onClicked: root.currentTab = "installers"
                        }

                        NavTab {
                            style: root.style
                            title: "测试游戏"
                            iconKind: "ROCKET_LAUNCH"
                            active: false
                            onClicked: root.launchInstance()
                        }

                        NavTab {
                            style: root.style
                            title: "文件夹"
                            iconKind: "FOLDER_OPEN"
                            active: root.browseMenuOpen
                            onClicked: {
                                root.browseMenuOpen = !root.browseMenuOpen
                                root.actionMenuOpen = false
                            }
                        }

                        NavTab {
                            style: root.style
                            title: "管理"
                            iconKind: "MENU"
                            active: root.actionMenuOpen
                            onClicked: {
                                root.actionMenuOpen = !root.actionMenuOpen
                                root.browseMenuOpen = false
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: root.style.radiusValue
                color: root.style.cSurfaceContainerHigh
                border.width: 1
                border.color: root.style.cBorder
                clip: true

                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.tabIndex(root.currentTab)

                    SettingsTab {
                        style: root.style
                        backend: root.backend
                        rootPage: root
                    }

                    InstallersTab {
                        style: root.style
                        rootPage: root
                    }

                    ModsTab {
                        style: root.style
                        rootPage: root
                    }

                    FolderTab {
                        style: root.style
                        rootPage: root
                        folderKey: "resourcepacks"
                        titleText: "资源包"
                        subtitleText: "管理当前实例运行目录中的 resourcepacks 文件夹。"
                    }

                    FolderTab {
                        style: root.style
                        rootPage: root
                        folderKey: "saves"
                        titleText: "世界"
                        subtitleText: "管理当前实例运行目录中的 saves 文件夹。"
                    }

                    FolderTab {
                        style: root.style
                        rootPage: root
                        folderKey: "schematics"
                        titleText: "结构"
                        subtitleText: "管理当前实例运行目录中的 schematics 文件夹。"
                    }
                }
            }

            PopupPanel {
                id: browsePopup
                visible: root.browseMenuOpen
                style: root.style
                x: 12
                y: Math.max(12, parent.height - height - 94)
                width: 260
                title: "打开文件夹"
                model: folderModel
                actionRole: "open"
                onTriggered: function(key) {
                    root.backend.openInstanceFolder(root.versionId, key)
                    root.browseMenuOpen = false
                }
            }

            ManagementPanel {
                visible: root.actionMenuOpen
                style: root.style
                x: 12
                y: Math.max(12, parent.height - height - 54)
                width: 280
                onRenameRequested: root.openPrompt("rename")
                onDuplicateRequested: root.openPrompt("duplicate")
                onDeleteRequested: root.openPrompt("delete")
                onExportRequested: root.backend.output = "当前 Qt 版本还没有接整合包导出向导。"
                onScriptRequested: root.backend.generateInstanceLaunchCommand(root.versionId)
                onCleanRequested: root.backend.cleanInstance(root.versionId)
                onClearAssetsRequested: root.backend.clearInstanceAssets(root.versionId)
                onClearLibrariesRequested: root.backend.clearInstanceLibraries(root.versionId)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 1000
        visible: root.promptMode.length > 0
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePrompt()
        }

        Rectangle {
            width: Math.min(parent.width - 96, 430)
            height: root.promptMode === "delete" ? 190 : 250
            anchors.centerIn: parent
            radius: root.style.radiusValue
            color: root.style.cSurface
            border.width: 1
            border.color: root.style.cBorder

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: root.promptTitle
                    color: root.style.cTextOnSurface
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.promptText
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    visible: root.promptMode !== "delete"
                    radius: 3
                    color: root.style.cButtonSurface
                    border.width: 1
                    border.color: promptInput.activeFocus ? root.style.cButtonSelected : root.style.cBorder

                    TextField {
                        id: promptInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        text: root.promptValue
                        color: root.style.cTextOnSurface
                        selectByMouse: true
                        background: Item {}
                        onTextChanged: root.promptValue = text
                        Component.onCompleted: if (visible) forceActiveFocus()
                    }
                }

                CheckBox {
                    visible: root.promptMode === "duplicate"
                    text: "复制存档"
                    checked: root.promptCheck
                    onCheckedChanged: root.promptCheck = checked
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        style: root.style
                        text: "取消"
                        onClicked: root.closePrompt()
                    }

                    DialogButton {
                        style: root.style
                        text: root.promptMode === "delete" ? "删除" : "确定"
                        danger: root.promptMode === "delete"
                        primary: root.promptMode !== "delete"
                        onClicked: root.acceptPrompt()
                    }
                }
            }
        }
    }

    function reloadDetail() {
        if (!root.versionId || root.versionId.length === 0) {
            return
        }
        var raw = root.backend.refreshInstanceDetail(root.versionId)
        root.applyDetailJson(raw)
    }

    function applyDetailJson(raw) {
        if (!raw || raw.length === 0) {
            return
        }

        var payload = JSON.parse(raw)
        root.detail = payload
        root.summary = payload.summary || {}
        root.settingsData = payload.settings || {}

        folderModel.clear()
        var folders = payload.folders || []
        for (var i = 0; i < folders.length; i++) {
            folderModel.append({
                "folderKey": folders[i].key || "",
                "title": folders[i].title || "",
                "folderTitle": folders[i].title || "",
                "path": folders[i].path || "",
                "exists": !!folders[i].exists,
                "itemCount": folders[i].itemCount || 0
            })
        }

        loaderModel.clear()
        var loaders = payload.loaders || []
        for (var j = 0; j < loaders.length; j++) {
            loaderModel.append({
                "kind": loaders[j].kind || "",
                "version": loaders[j].version || ""
            })
        }
    }

    function tabIndex(tab) {
        if (tab === "settings") return 0
        if (tab === "installers") return 1
        if (tab === "mods") return 2
        if (tab === "resourcepacks") return 3
        if (tab === "worlds") return 4
        if (tab === "schematics") return 5
        return 0
    }

    function folderByKey(key) {
        for (var i = 0; i < folderModel.count; i++) {
            var folder = folderModel.get(i)
            if (folder.folderKey === key) {
                return folder
            }
        }
        return { "folderKey": key, "title": key, "path": "", "exists": false, "itemCount": 0 }
    }

    function launchInstance() {
        root.backend.selectInstance(root.versionId)
        root.backend.startLaunchSelectedVersion("keep")
    }

    function openPrompt(mode) {
        root.actionMenuOpen = false
        root.browseMenuOpen = false
        root.promptMode = mode
        root.promptCheck = false

        if (mode === "rename") {
            root.promptTitle = "重命名实例"
            root.promptText = "输入新的实例名称。名称会同时修改 versions 目录、版本 JSON 和启动器实例配置。"
            root.promptValue = root.versionId
        } else if (mode === "duplicate") {
            root.promptTitle = "复制实例"
            root.promptText = "输入新实例名称。会复制版本目录和实例设置。"
            root.promptValue = root.versionId + " - 副本"
        } else if (mode === "delete") {
            root.promptTitle = "删除实例"
            root.promptText = "确定要删除实例 “" + root.versionId + "” 吗？该操作会删除对应版本目录。"
            root.promptValue = ""
        }
    }

    function closePrompt() {
        root.promptMode = ""
        root.promptValue = ""
    }

    function acceptPrompt() {
        if (root.promptMode === "rename") {
            var result = root.backend.renameInstance(root.versionId, root.promptValue)
            root.versionId = root.promptValue
            root.reloadDetail()
        } else if (root.promptMode === "duplicate") {
            root.backend.duplicateInstance(root.versionId, root.promptValue, root.promptCheck ? "true" : "false")
        } else if (root.promptMode === "delete") {
            root.backend.deleteInstance(root.versionId)
        }
        root.closePrompt()
    }

    component NavTab: Item {
        id: item
        required property var style
        property string title: ""
        property string iconKind: "SETTINGS"
        property bool active: false
        signal clicked()

        width: parent ? parent.width : 200
        height: 40

        Rectangle {
            anchors.fill: parent
            color: item.active ? item.style.cNavSelected : "transparent"
        }

        HmclRipple {
            id: ripple
            anchors.fill: parent
            hovered: mouse.containsMouse
            hoverColor: item.style.cTextOnSurface
            hoverOpacity: 0.04
            rippleColor: item.style.cTextOnSurfaceVariant
            rippleOpacity: 0.10
            animationsEnabled: item.style.animationsEnabled
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(event) { ripple.press(event.x, event.y) }
            onClicked: item.clicked()
        }

        HmclSvgIcon {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            icon: item.iconKind
            iconSize: 20
            iconColor: item.style.cTextOnSurface
            animationsEnabled: item.style.animationsEnabled
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: item.title
            color: item.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: item.active
            elide: Text.ElideRight
        }
    }

    component PageHeader: Item {
        id: header
        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconSource: ""
        height: 84
        implicitHeight: 84

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 12

            HmclImageContainer {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                style: header.style
                source: header.iconSource
                imageSize: 42
                animationsEnabled: header.style.animationsEnabled
            }

            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    width: parent.width
                    text: header.title
                    color: header.style.cTextOnSurface
                    font.pixelSize: 20
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: header.subtitle
                    color: header.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
    }

    component SettingsTab: ScrollView {
        id: tab
        required property var style
        required property var backend
        required property var rootPage
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: tab.availableWidth
            spacing: 0

            PageHeader {
                Layout.fillWidth: true
                style: tab.style
                title: tab.rootPage.versionId
                subtitle: (tab.rootPage.summary.subtitle || "") + "    " + (tab.rootPage.summary.isIsolated ? "独立运行目录" : "共享运行目录")
                iconSource: tab.rootPage.iconBase + (tab.rootPage.summary.iconName || "grass") + ".png"
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: tab.style.cBorder; opacity: 0.55 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 12

                InfoGrid {
                    Layout.fillWidth: true
                    style: tab.style
                    rootPage: tab.rootPage
                }

                SettingsCard {
                    Layout.fillWidth: true
                    style: tab.style
                    title: "启动"

                    SettingField {
                        Layout.fillWidth: true
                        style: tab.style
                        label: "Java 路径"
                        textValue: tab.rootPage.settingsData.javaPath || ""
                        placeholderText: "继承全局 Java"
                        onEdited: function(value) { tab.rootPage.settingsData.javaPath = value }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        NumberField {
                            Layout.fillWidth: true
                            style: tab.style
                            label: "最小内存 MB"
                            valueText: String(tab.rootPage.settingsData.minMemoryMb || 512)
                            onEdited: function(value) { tab.rootPage.settingsData.minMemoryMb = parseInt(value) || 512 }
                        }

                        NumberField {
                            Layout.fillWidth: true
                            style: tab.style
                            label: "最大内存 MB"
                            valueText: String(tab.rootPage.settingsData.maxMemoryMb || 2048)
                            onEdited: function(value) { tab.rootPage.settingsData.maxMemoryMb = parseInt(value) || 2048 }
                        }
                    }

                    SettingField {
                        Layout.fillWidth: true
                        style: tab.style
                        label: "JVM 参数"
                        textValue: tab.rootPage.settingsData.jvmArgs || ""
                        placeholderText: "例如 -XX:+UseG1GC"
                        onEdited: function(value) { tab.rootPage.settingsData.jvmArgs = value }
                    }

                    SettingField {
                        Layout.fillWidth: true
                        style: tab.style
                        label: "游戏参数"
                        textValue: tab.rootPage.settingsData.gameArgs || ""
                        placeholderText: "附加 Minecraft 参数"
                        onEdited: function(value) { tab.rootPage.settingsData.gameArgs = value }
                    }
                }

                SettingsCard {
                    Layout.fillWidth: true
                    style: tab.style
                    title: "窗口"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        NumberField {
                            Layout.fillWidth: true
                            style: tab.style
                            label: "宽度"
                            valueText: String(tab.rootPage.settingsData.width || 854)
                            onEdited: function(value) { tab.rootPage.settingsData.width = parseInt(value) || 854 }
                        }

                        NumberField {
                            Layout.fillWidth: true
                            style: tab.style
                            label: "高度"
                            valueText: String(tab.rootPage.settingsData.height || 480)
                            onEdited: function(value) { tab.rootPage.settingsData.height = parseInt(value) || 480 }
                        }
                    }

                    CheckBox {
                        text: "全屏启动"
                        checked: !!tab.rootPage.settingsData.fullscreen
                        onCheckedChanged: tab.rootPage.settingsData.fullscreen = checked
                    }
                }

                SettingsCard {
                    Layout.fillWidth: true
                    style: tab.style
                    title: "运行目录"

                    CheckBox {
                        text: "使用实例独立运行目录"
                        checked: !!tab.rootPage.settingsData.isolated
                        onCheckedChanged: tab.rootPage.settingsData.isolated = checked
                    }

                    SettingField {
                        Layout.fillWidth: true
                        style: tab.style
                        label: "自定义运行目录"
                        textValue: tab.rootPage.settingsData.runDirectory || ""
                        placeholderText: "留空时按是否独立运行目录自动计算"
                        onEdited: function(value) { tab.rootPage.settingsData.runDirectory = value }
                    }

                    SettingField {
                        Layout.fillWidth: true
                        style: tab.style
                        label: "服务器地址"
                        textValue: tab.rootPage.settingsData.server || ""
                        placeholderText: "可选，启动后进入服务器"
                        onEdited: function(value) { tab.rootPage.settingsData.server = value }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }

                    HmclButton {
                        style: tab.style
                        text: "打开游戏文件夹"
                        onClicked: tab.backend.openInstanceFolder(tab.rootPage.versionId, "game")
                    }

                    HmclButton {
                        style: tab.style
                        text: "保存"
                        primary: true
                        onClicked: {
                            tab.backend.saveInstanceSettings(tab.rootPage.versionId, JSON.stringify(tab.rootPage.settingsData))
                            tab.rootPage.reloadDetail()
                        }
                    }
                }

                Item { Layout.preferredHeight: 12 }
            }
        }
    }

    component InfoGrid: Rectangle {
        id: info
        required property var style
        required property var rootPage
        radius: info.style.radiusValue
        color: info.style.cSurfaceContainer
        border.width: 1
        border.color: info.style.cBorder
        height: 116
        implicitHeight: 116

        GridLayout {
            anchors.fill: parent
            anchors.margins: 12
            columns: 2
            rowSpacing: 8
            columnSpacing: 24

            InfoLine { style: info.style; label: "游戏版本"; value: info.rootPage.summary.gameVersion || "unknown" }
            InfoLine { style: info.style; label: "实例类型"; value: info.rootPage.summary.versionType || "unknown" }
            InfoLine { style: info.style; label: "加载器"; value: info.rootPage.summary.loaderSummary || "原版" }
            InfoLine { style: info.style; label: "Java"; value: info.rootPage.summary.javaMajor ? "Java " + info.rootPage.summary.javaMajor : "继承/自动" }
            InfoLine { style: info.style; label: "版本目录"; value: info.rootPage.summary.path || "" }
            InfoLine { style: info.style; label: "运行目录"; value: info.rootPage.summary.runDirectory || "" }
        }
    }

    component InfoLine: Column {
        required property var style
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 2
        Text { text: parent.label; color: parent.style.cTextOnSurfaceVariant; font.pixelSize: 10 }
        Text { width: parent.width; text: parent.value; color: parent.style.cTextOnSurface; font.pixelSize: 12; elide: Text.ElideLeft }
    }

    component InstallersTab: ScrollView {
        id: tab
        required property var style
        required property var rootPage
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: tab.availableWidth
            spacing: 0

            PageHeader {
                Layout.fillWidth: true
                style: tab.style
                title: "安装器"
                subtitle: "显示当前实例 JSON 中解析到的加载器信息。"
                iconSource: tab.rootPage.iconBase + (tab.rootPage.summary.iconName || "grass") + ".png"
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: tab.style.cBorder; opacity: 0.55 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 12

                Repeater {
                    model: loaderModel
                    delegate: ListCard {
                        required property string kind
                        required property string version

                        Layout.fillWidth: true
                        style: tab.style
                        iconKind: "DEPLOYED_CODE"
                        title: kind
                        subtitle: version.length > 0 ? version : "版本未知"
                        actionText: "查看"
                        onAction: tab.rootPage.backend.output = kind + " " + version
                    }
                }

                ListCard {
                    Layout.fillWidth: true
                    visible: loaderModel.count === 0
                    style: tab.style
                    iconKind: "CHECK"
                    title: "原版"
                    subtitle: "未在版本 JSON 中检测到加载器。"
                    actionText: ""
                }

                SettingsCard {
                    Layout.fillWidth: true
                    style: tab.style
                    title: "版本文件"

                    InfoLine { Layout.fillWidth: true; style: tab.style; label: "version.json"; value: tab.rootPage.detail.versionJson || "" }
                    InfoLine { Layout.fillWidth: true; style: tab.style; label: "client.jar"; value: tab.rootPage.detail.clientJar || "" }
                    InfoLine { Layout.fillWidth: true; style: tab.style; label: "mainClass"; value: tab.rootPage.detail.mainClass || "" }
                    InfoLine { Layout.fillWidth: true; style: tab.style; label: "inheritsFrom"; value: tab.rootPage.detail.inheritsFrom || "" }
                }
            }
        }
    }

    component ModsTab: Item {
        id: tab
        required property var style
        required property var rootPage
        clip: true

        property var filteredMods: {
            var q = tab.rootPage.modSearchText.toLowerCase()
            if (!q) return tab.rootPage.mods
            return tab.rootPage.mods.filter(function(m) {
                return m.name.toLowerCase().indexOf(q) >= 0
                    || m.fileName.toLowerCase().indexOf(q) >= 0
            })
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            PageHeader {
                Layout.fillWidth: true
                style: tab.style
                title: "Mod"
                subtitle: tab.rootPage.mods.length > 0
                         ? "共 " + tab.rootPage.mods.length + " 个 mod"
                         : "管理当前实例的 mods 文件夹。"
                iconSource: tab.rootPage.iconBase + (tab.rootPage.summary.iconName || "grass") + ".png"
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: tab.style.cBorder; opacity: 0.55 }

            // Toolbar
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 10
                Layout.bottomMargin: 6
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 4
                    color: tab.style.cButtonSurface
                    border.width: 1
                    border.color: searchInput.activeFocus ? tab.style.cButtonSelected : tab.style.cBorder

                    TextField {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        placeholderText: "搜索 mod…"
                        color: tab.style.cTextOnSurface
                        placeholderTextColor: tab.style.cTextOnSurfaceVariant
                        selectByMouse: true
                        background: Item {}
                        onTextChanged: tab.rootPage.modSearchText = text
                    }
                }

                Rectangle {
                    width: 34; height: 34
                    radius: 4
                    color: refreshMouse.containsMouse ? tab.style.cButtonHover : tab.style.cButtonSurface
                    border.width: 1
                    border.color: tab.style.cBorder
                    HmclSvgIcon {
                        anchors.centerIn: parent
                        icon: "REFRESH"
                        iconSize: 18
                        iconColor: tab.style.cTextOnSurface
                        animationsEnabled: tab.style.animationsEnabled
                    }
                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.rootPage.reloadMods()
                    }
                }

                Rectangle {
                    width: 34; height: 34
                    radius: 4
                    color: folderMouse.containsMouse ? tab.style.cButtonHover : tab.style.cButtonSurface
                    border.width: 1
                    border.color: tab.style.cBorder
                    HmclSvgIcon {
                        anchors.centerIn: parent
                        icon: "FOLDER_OPEN"
                        iconSize: 18
                        iconColor: tab.style.cTextOnSurface
                        animationsEnabled: tab.style.animationsEnabled
                    }
                    MouseArea {
                        id: folderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.rootPage.backend.openInstanceFolder(tab.rootPage.versionId, "mods")
                    }
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: tab.rootPage.mods.length === 0

                Text {
                    anchors.centerIn: parent
                    text: "此实例还没有任何 mod。"
                    color: tab.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                    font.italic: true
                }
            }

            // Mod list
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: tab.rootPage.mods.length > 0
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ListView {
                    id: modListView
                    width: parent.width
                    height: contentHeight
                    model: tab.filteredMods
                    spacing: 4
                    topMargin: 4
                    bottomMargin: 12
                    leftMargin: 16
                    rightMargin: 16
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: modCell
                        required property var modelData
                        required property int index

                        width: modListView.width - 32
                        height: 64
                        radius: tab.style.radiusValue
                        color: modCellMouse.containsMouse
                               ? tab.style.cButtonHover
                               : (modCell.modelData.enabled ? tab.style.cSurfaceContainerHigh : tab.style.cSurfaceContainer)
                        border.width: 1
                        border.color: tab.style.cBorder
                        opacity: modCell.modelData.enabled ? 1.0 : 0.65

                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            // Loader badge
                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 4
                                color: {
                                    var l = modCell.modelData.loader
                                    if (l === "fabric") return "#4f6e2e"
                                    if (l === "quilt") return "#5b3d91"
                                    if (l === "forge") return "#8b4513"
                                    if (l === "neoforge") return "#d4631a"
                                    return tab.style.cButtonSurface
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        var l = modCell.modelData.loader
                                        if (l === "fabric") return "F"
                                        if (l === "quilt") return "Q"
                                        if (l === "forge") return "FG"
                                        if (l === "neoforge") return "NF"
                                        return "?"
                                    }
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            // Name + file info
                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: modCell.modelData.name
                                           + (modCell.modelData.version.length > 0 ? "  " + modCell.modelData.version : "")
                                    color: tab.style.cTextOnSurface
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modCell.modelData.fileName
                                    color: tab.style.cTextOnSurfaceVariant
                                    font.pixelSize: 11
                                    elide: Text.ElideLeft
                                }
                            }

                            // Enable/disable toggle
                            Rectangle {
                                width: 38; height: 22
                                radius: 11
                                color: modCell.modelData.enabled ? tab.style.cButtonSelected : tab.style.cBorder
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    width: 16; height: 16
                                    radius: 8
                                    color: "white"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: modCell.modelData.enabled ? 19 : 3
                                    Behavior on x { NumberAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var newEnabled = !modCell.modelData.enabled
                                        tab.rootPage.backend.setInstanceModEnabled(
                                            tab.rootPage.versionId,
                                            modCell.modelData.fileName,
                                            newEnabled ? "true" : "false"
                                        )
                                        tab.rootPage.reloadMods()
                                    }
                                }
                            }

                            // Delete button
                            Rectangle {
                                width: 28; height: 28
                                radius: 4
                                color: delMouse.containsMouse ? "#B3261E" : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                HmclSvgIcon {
                                    anchors.centerIn: parent
                                    icon: "DELETE_FOREVER"
                                    iconSize: 16
                                    iconColor: delMouse.containsMouse ? "white" : tab.style.cTextOnSurfaceVariant
                                    animationsEnabled: tab.style.animationsEnabled
                                }

                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        tab.rootPage.backend.deleteInstanceMod(
                                            tab.rootPage.versionId,
                                            modCell.modelData.fileName
                                        )
                                        tab.rootPage.reloadMods()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: modCellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
                }
            }
        }
    }

    component FolderTab: ScrollView {
        id: tab
        required property var style
        required property var rootPage
        property string folderKey: "mods"
        property string titleText: ""
        property string subtitleText: ""
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: tab.availableWidth
            spacing: 0

            PageHeader {
                Layout.fillWidth: true
                style: tab.style
                title: tab.titleText
                subtitle: tab.subtitleText
                iconSource: tab.rootPage.iconBase + (tab.rootPage.summary.iconName || "grass") + ".png"
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: tab.style.cBorder; opacity: 0.55 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 12

                ListCard {
                    Layout.fillWidth: true
                    style: tab.style
                    iconKind: tab.folderKey === "mods" ? "EXTENSION" : tab.folderKey === "resourcepacks" ? "TEXTURE" : "FOLDER_OPEN"
                    title: tab.rootPage.folderByKey(tab.folderKey).title
                    subtitle: tab.rootPage.folderByKey(tab.folderKey).path + " · " + tab.rootPage.folderByKey(tab.folderKey).itemCount + " 项"
                    actionText: "打开"
                    onAction: tab.rootPage.backend.openInstanceFolder(tab.rootPage.versionId, tab.folderKey)
                }

                Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
            }
        }
    }

    component SettingsCard: Rectangle {
        id: card
        required property var style
        property string title: ""
        default property alias content: contentColumn.data
        radius: card.style.radiusValue
        color: card.style.cSurfaceContainer
        border.width: 1
        border.color: card.style.cBorder
        implicitHeight: contentColumn.implicitHeight + 28

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: card.title
                color: card.style.cTextOnSurface
                font.pixelSize: 15
                font.bold: true
            }
        }
    }

    component SettingField: Item {
        id: field
        required property var style
        property string label: ""
        property string textValue: ""
        property string placeholderText: ""
        signal edited(string value)
        height: 62

        ColumnLayout {
            anchors.fill: parent
            spacing: 5
            Text { text: field.label; color: field.style.cTextOnSurfaceVariant; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 3
                color: field.style.cButtonSurface
                border.width: 1
                border.color: input.activeFocus ? field.style.cButtonSelected : field.style.cBorder
                TextField {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: field.textValue
                    placeholderText: field.placeholderText
                    color: field.style.cTextOnSurface
                    placeholderTextColor: field.style.cTextOnSurfaceVariant
                    selectByMouse: true
                    background: Item {}
                    onTextChanged: field.edited(text)
                }
            }
        }
    }

    component NumberField: Item {
        id: field
        required property var style
        property string label: ""
        property string valueText: ""
        signal edited(string value)
        height: 62

        ColumnLayout {
            anchors.fill: parent
            spacing: 5
            Text { text: field.label; color: field.style.cTextOnSurfaceVariant; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 3
                color: field.style.cButtonSurface
                border.width: 1
                border.color: input.activeFocus ? field.style.cButtonSelected : field.style.cBorder
                TextField {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: field.valueText
                    validator: IntValidator { bottom: 0; top: 65535 }
                    color: field.style.cTextOnSurface
                    selectByMouse: true
                    background: Item {}
                    onTextChanged: field.edited(text)
                }
            }
        }
    }

    component ListCard: Rectangle {
        id: card
        required property var style
        property string iconKind: "FOLDER_OPEN"
        property string title: ""
        property string subtitle: ""
        property string actionText: "打开"
        signal action()
        height: 64
        implicitHeight: 64
        radius: card.style.radiusValue
        color: mouse.containsMouse ? card.style.cNavHover : card.style.cSurfaceContainer
        border.width: 1
        border.color: card.style.cBorder

        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: card.action() }

        HmclSvgIcon { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; icon: card.iconKind; iconSize: 22; iconColor: card.style.cTextOnSurface; animationsEnabled: card.style.animationsEnabled }

        Column {
            anchors.left: parent.left; anchors.leftMargin: 52; anchors.right: actionLabel.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            Text { width: parent.width; text: card.title; color: card.style.cTextOnSurface; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
            Text { width: parent.width; text: card.subtitle; color: card.style.cTextOnSurfaceVariant; font.pixelSize: 11; elide: Text.ElideLeft }
        }

        Text {
            id: actionLabel
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: card.actionText.length > 0
            text: card.actionText
            color: card.style.cPrimary
            font.pixelSize: 12
            font.bold: true
        }
    }

    component HmclButton: Rectangle {
        id: button
        required property var style
        property string text: ""
        property bool primary: false
        signal clicked()
        width: Math.max(96, label.implicitWidth + 28)
        height: 36
        radius: 18
        color: primary ? (mouse.containsMouse ? style.cLaunchButtonHover : style.cLaunchButton) : (mouse.containsMouse ? style.cButtonHover : style.cButtonSurface)
        border.width: primary ? 0 : 1
        border.color: style.cBorder
        Text { id: label; anchors.centerIn: parent; text: button.text; color: button.primary ? button.style.cLaunchButtonText : button.style.cTextOnSurface; font.pixelSize: 13; font.bold: button.primary }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
    }

    component DialogButton: Rectangle {
        id: button
        required property var style
        property string text: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        width: Math.max(86, label.implicitWidth + 28)
        height: 36
        radius: 18
        color: danger ? (mouse.containsMouse ? "#C7362E" : "#B3261E") : primary ? (mouse.containsMouse ? style.cLaunchButtonHover : style.cLaunchButton) : (mouse.containsMouse ? style.cButtonHover : style.cButtonSurface)
        border.width: primary || danger ? 0 : 1
        border.color: style.cBorder
        Text { id: label; anchors.centerIn: parent; text: button.text; color: (button.primary || button.danger) ? button.style.cLaunchButtonText : button.style.cTextOnSurface; font.pixelSize: 13; font.bold: button.primary || button.danger }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
    }

    component PopupPanel: Rectangle {
        id: panel
        required property var style
        property string title: ""
        property var model
        property string actionRole: "open"
        signal triggered(string key)
        height: Math.min(360, 44 + (model ? model.count : 0) * 40)
        radius: panel.style.radiusValue
        color: panel.style.cSurface
        border.width: 1
        border.color: panel.style.cBorder
        z: 50

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.title
                    color: panel.style.cTextOnSurface
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
            Repeater {
                model: panel.model
                delegate: PopupItem {
                    required property string folderKey
                    required property string folderTitle
                    required property int itemCount

                    Layout.fillWidth: true
                    style: panel.style
                    title: folderTitle
                    subtitle: itemCount + " 项"
                    iconKind: folderKey === "mods" ? "EXTENSION" : folderKey === "resourcepacks" ? "TEXTURE" : folderKey === "saves" ? "PUBLIC" : "FOLDER_OPEN"
                    onClicked: panel.triggered(folderKey)
                }
            }
        }
    }

    component ManagementPanel: Rectangle {
        id: panel
        required property var style
        signal renameRequested()
        signal duplicateRequested()
        signal deleteRequested()
        signal exportRequested()
        signal scriptRequested()
        signal cleanRequested()
        signal clearAssetsRequested()
        signal clearLibrariesRequested()
        width: 280
        height: 40 * 10 + 8
        radius: panel.style.radiusValue
        color: panel.style.cSurface
        border.width: 1
        border.color: panel.style.cBorder
        z: 50

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 0
            PopupAction { style: panel.style; title: "测试游戏"; iconKind: "ROCKET_LAUNCH"; onClicked: root.launchInstance() }
            PopupAction { style: panel.style; title: "生成启动脚本"; iconKind: "SCRIPT"; onClicked: panel.scriptRequested() }
            SeparatorLine { style: panel.style }
            PopupAction { style: panel.style; title: "重命名"; iconKind: "EDIT"; onClicked: panel.renameRequested() }
            PopupAction { style: panel.style; title: "复制"; iconKind: "FOLDER_COPY"; onClicked: panel.duplicateRequested() }
            PopupAction { style: panel.style; title: "删除"; iconKind: "DELETE_FOREVER"; onClicked: panel.deleteRequested() }
            PopupAction { style: panel.style; title: "导出整合包"; iconKind: "OUTPUT"; onClicked: panel.exportRequested() }
            SeparatorLine { style: panel.style }
            PopupAction { style: panel.style; title: "重新下载资源索引"; iconKind: "REFRESH"; onClicked: panel.clearAssetsRequested() }
            PopupAction { style: panel.style; title: "删除库文件"; iconKind: "DELETE_FOREVER"; onClicked: panel.clearLibrariesRequested() }
            PopupAction { style: panel.style; title: "清理游戏目录"; iconKind: "CLEANING"; onClicked: panel.cleanRequested() }
        }
    }

    component PopupItem: Item {
        id: item
        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconKind: "FOLDER_OPEN"
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        height: 40
        HmclRipple { id: ripple; anchors.fill: parent; hovered: mouse.containsMouse; hoverColor: item.style.cTextOnSurface; hoverOpacity: 0.04; rippleColor: item.style.cTextOnSurfaceVariant; rippleOpacity: 0.10; animationsEnabled: item.style.animationsEnabled }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(event) {
                ripple.press(event.x, event.y)
            }
            onClicked: item.clicked()
        }
        HmclSvgIcon { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; icon: item.iconKind; iconSize: 18; iconColor: item.style.cTextOnSurface; animationsEnabled: item.style.animationsEnabled }
        Text { anchors.left: parent.left; anchors.leftMargin: 44; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: item.subtitle.length > 0 ? item.title + "    " + item.subtitle : item.title; color: item.style.cTextOnSurface; font.pixelSize: 12; elide: Text.ElideRight }
    }

    component PopupAction: Item {
        id: item
        required property var style
        property string title: ""
        property string iconKind: "FOLDER_OPEN"
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        HmclRipple { id: ripple; anchors.fill: parent; hovered: mouse.containsMouse; hoverColor: item.style.cTextOnSurface; hoverOpacity: 0.04; rippleColor: item.style.cTextOnSurfaceVariant; rippleOpacity: 0.10; animationsEnabled: item.style.animationsEnabled }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(event) {
                ripple.press(event.x, event.y)
            }
            onClicked: item.clicked()
        }
        HmclSvgIcon { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; icon: item.iconKind; iconSize: 18; iconColor: item.style.cTextOnSurface; animationsEnabled: item.style.animationsEnabled }
        Text { anchors.left: parent.left; anchors.leftMargin: 44; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: item.title; color: item.style.cTextOnSurface; font.pixelSize: 12; elide: Text.ElideRight }
    }

    component SeparatorLine: Rectangle {
        required property var style
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.preferredHeight: 1
        color: style.cBorder
        opacity: 0.7
    }
}
