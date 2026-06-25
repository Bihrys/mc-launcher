import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var style
    required property var backend

    property string currentTab: "game"
    property string downloadSource: "auto"
    property string selectedGameVersion: ""
    property string selectedGameReleaseTime: ""
    property string selectedLoaderKind: "vanilla"
    property bool installerPaneOpen: false
    property string versionFilter: "release"
    property string searchText: ""
    property var catalog: null
    property var allForgeInstallers: []
    property var allNeoForgeInstallers: []
    property bool downloadDialogOpen: false
    property bool downloadCancelDismissed: false
    property bool downloadFinishHandled: false
    property string loadedCatalogJson: ""

    property var downloadTaskStatus: ({
        "active": false,
        "cancelled": false,
        "percent": 0,
        "title": "空闲",
        "message": "还没有下载任务。",
        "totalFiles": 0,
        "finishedFiles": 0,
        "totalBytes": 0,
        "downloadedBytes": 0,
        "currentFile": "",
        "speed": 0,
        "status": "idle"
    })

    property var catalogTaskStatus: ({
        "active": false,
        "percent": 0,
        "title": "空闲",
        "message": "还没有版本列表刷新任务。",
        "catalogReady": false,
        "catalogJson": ""
    })

    ListModel { id: allVersionsModel }
    ListModel { id: visibleVersionModel }

    ListModel { id: fabricLoaderModel }
    ListModel { id: quiltLoaderModel }
    ListModel { id: forgeInstallerModel }
    ListModel { id: neoforgeInstallerModel }

    Component.onCompleted: {
        root.startRefreshCatalog()
    }

    Timer {
        id: catalogTaskPoller
        interval: 250
        repeat: true
        running: true
        onTriggered: root.pollDownloadCatalogTask()
    }

    Timer {
        id: downloadTaskPoller
        interval: 250
        repeat: true
        running: true
        onTriggered: root.pollDownloadTask()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "transparent"

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                HmclClassTitle {
                    width: parent.width
                    text: "游戏下载"
                }

                DownloadNavItem {
                    width: parent.width
                    style: root.style
                    iconSource: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/grass.png"
                    title: "游戏"
                    subtitle: "Minecraft / 加载器"
                    selected: root.currentTab === "game"
                    onClicked: root.currentTab = "game"
                }

                HmclClassTitle {
                    width: parent.width
                    text: "下载内容"
                }

                DownloadNavItem {
                    width: parent.width
                    style: root.style
                    iconKind: "PACKAGE2"
                    title: "整合包"
                    subtitle: "Modpack"
                    selected: root.currentTab === "modpack"
                    onClicked: root.currentTab = "modpack"
                }

                DownloadNavItem {
                    width: parent.width
                    style: root.style
                    iconKind: "EXTENSION"
                    title: "Mod"
                    subtitle: "CurseForge / Modrinth"
                    selected: root.currentTab === "mod"
                    onClicked: root.currentTab = "mod"
                }

                DownloadNavItem {
                    width: parent.width
                    style: root.style
                    iconKind: "TEXTURE"
                    title: "资源包"
                    subtitle: "Resource Pack"
                    selected: root.currentTab === "resourcepack"
                    onClicked: root.currentTab = "resourcepack"
                }

                DownloadNavItem {
                    width: parent.width
                    style: root.style
                    iconKind: "WB_SUNNY"
                    title: "光影包"
                    subtitle: "Shader"
                    selected: root.currentTab === "shader"
                    onClicked: root.currentTab = "shader"
                }

                DownloadNavItem {
                    width: parent.width
                    style: root.style
                    iconKind: "PUBLIC"
                    title: "世界"
                    subtitle: "World"
                    selected: root.currentTab === "world"
                    onClicked: root.currentTab = "world"
                }

                Item {
                    width: parent.width
                    height: 1
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.style.cBorder
                }

                Text {
                    width: parent.width
                    text: root.catalog
                          ? "最新正式版 " + root.catalog.latestRelease + "\n最新快照 " + root.catalog.latestSnapshot
                          : "正在等待版本列表"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            GameDownloadPane {
                anchors.fill: parent
                visible: root.currentTab === "game"
                opacity: visible ? 1 : 0
            }

            DownloadPlaceholderPane {
                anchors.fill: parent
                visible: root.currentTab !== "game"
                opacity: visible ? 1 : 0
                title: root.placeholderTitle(root.currentTab)
                message: "HMCL 这部分连接 CurseForge / Modrinth / 远程整合包仓库。当前先完成游戏和加载器下载主线，内容下载将在同一 DownloadService 框架下继续接入。"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 1000
        visible: root.downloadDialogOpen
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!root.downloadTaskStatus.active) {
                    root.downloadDialogOpen = false
                }
            }
        }

        DownloadDialogCard {
            anchors.centerIn: parent
            width: Math.min(root.width - 64, 520)
            height: Math.min(root.height - 64, 310)
            style: root.style
            status: root.downloadTaskStatus

            onCancelRequested: {
                root.downloadCancelDismissed = true
                root.downloadDialogOpen = false
                root.backend.cancelDownloadTask()
            }

            onCloseRequested: root.downloadDialogOpen = false
        }
    }

    function startRefreshCatalog() {
        allVersionsModel.clear()
        visibleVersionModel.clear()
        fabricLoaderModel.clear()
        quiltLoaderModel.clear()
        forgeInstallerModel.clear()
        neoforgeInstallerModel.clear()

        root.selectedGameVersion = ""
        root.selectedGameReleaseTime = ""
        root.loadedCatalogJson = ""
        root.catalog = null
        root.allForgeInstallers = []
        root.allNeoForgeInstallers = []

        root.catalogTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在获取版本列表",
            "message": "正在连接 Minecraft / Fabric / Quilt / Forge / NeoForge 版本源。",
            "catalogReady": false,
            "catalogJson": ""
        }

        root.backend.startRefreshDownloadCatalog(root.downloadSource)
        root.pollDownloadCatalogTask()
    }

    function pollDownloadCatalogTask() {
        var raw = root.backend.pollDownloadCatalogTask()

        if (!raw || raw.length === 0) {
            return
        }

        try {
            var status = JSON.parse(raw)
            root.catalogTaskStatus = status

            if (status.catalogReady
                    && status.catalogJson
                    && status.catalogJson.length > 0
                    && status.catalogJson !== root.loadedCatalogJson) {
                root.loadedCatalogJson = status.catalogJson
                root.parseCatalog(status.catalogJson)
            }
        } catch (e) {
            console.log("Failed to parse download catalog task status", e)
        }
    }

    function pollDownloadTask() {
        var raw = root.backend.pollDownloadTask()

        if (!raw || raw.length === 0) {
            return
        }

        try {
            root.downloadTaskStatus = JSON.parse(raw)

            if (root.downloadTaskStatus.active
                    && root.downloadTaskStatus.status !== "cancelling"
                    && root.downloadTaskStatus.status !== "cancelled"
                    && !root.downloadCancelDismissed) {
                root.downloadDialogOpen = true
            }

            if (root.downloadTaskStatus.status === "finished" && !root.downloadFinishHandled) {
                root.downloadFinishHandled = true
                root.backend.refreshInstalledVersions()
            }

            if (!root.downloadTaskStatus.active) {
                root.downloadCancelDismissed = false
            }
        } catch (e) {
            console.log("Failed to parse download task status", e)
        }
    }

    function parseCatalog(raw) {
        try {
            var data = JSON.parse(raw)
            root.catalog = data

            allVersionsModel.clear()
            fabricLoaderModel.clear()
            quiltLoaderModel.clear()
            forgeInstallerModel.clear()
            neoforgeInstallerModel.clear()

            var versions = data.gameVersions || []
            for (var i = 0; i < versions.length; i++) {
                var item = versions[i]
                var group = root.groupForVersion(item.id || "", item.versionType || "")
                allVersionsModel.append({
                    "versionId": item.id || "",
                    "versionType": item.versionType || "",
                    "releaseTime": item.releaseTime || "",
                    "group": group,
                    "iconSource": root.iconForVersionGroup(group),
                    "tagText": root.tagForVersionGroup(group)
                })
            }

            var fabric = data.fabricLoaders || []
            for (var f = 0; f < fabric.length; f++) {
                fabricLoaderModel.append({
                    "version": fabric[f].version || "",
                    "stable": !!fabric[f].stable
                })
            }

            var quilt = data.quiltLoaders || []
            for (var q = 0; q < quilt.length; q++) {
                quiltLoaderModel.append({
                    "version": quilt[q].version || "",
                    "stable": !!quilt[q].stable
                })
            }

            root.allForgeInstallers = data.forgeInstallers || []
            root.allNeoForgeInstallers = data.neoforgeInstallers || []

            root.rebuildVisibleVersions()

            if (visibleVersionModel.count > 0) {
                root.selectVersion(0)
            }

            root.installerPaneOpen = false
        } catch (e) {
            console.log("Failed to parse download catalog", e)
        }
    }

    function rebuildVisibleVersions() {
        visibleVersionModel.clear()

        var query = root.searchText.toLowerCase()

        for (var i = 0; i < allVersionsModel.count; i++) {
            var item = allVersionsModel.get(i)

            if (root.versionFilter !== "all" && item.group !== root.versionFilter) {
                continue
            }

            if (query.length > 0 && String(item.versionId).toLowerCase().indexOf(query) < 0) {
                continue
            }

            visibleVersionModel.append({
                "sourceIndex": i,
                "versionId": item.versionId,
                "versionType": item.versionType,
                "releaseTime": item.releaseTime,
                "group": item.group,
                "iconSource": item.iconSource,
                "tagText": item.tagText
            })
        }
    }

    function openInstallerForVersion(visibleIndex) {
        root.selectVersion(visibleIndex)
        root.installerPaneOpen = true
    }

    function closeInstallerPane() {
        root.installerPaneOpen = false
    }

    function selectVersion(visibleIndex) {
        if (visibleIndex < 0 || visibleIndex >= visibleVersionModel.count) {
            return
        }

        var item = visibleVersionModel.get(visibleIndex)
        root.selectedGameVersion = item.versionId
        root.selectedGameReleaseTime = item.releaseTime
        root.rebuildLoaderModels()
    }

    function rebuildLoaderModels() {
        forgeInstallerModel.clear()
        neoforgeInstallerModel.clear()

        for (var i = 0; i < root.allForgeInstallers.length; i++) {
            var forge = root.allForgeInstallers[i]
            if (forge.gameVersion === root.selectedGameVersion) {
                forgeInstallerModel.append({
                    "loaderVersion": forge.loaderVersion || "",
                    "gameVersion": forge.gameVersion || "",
                    "releaseTime": forge.releaseTime || ""
                })
            }
        }

        for (var n = 0; n < root.allNeoForgeInstallers.length; n++) {
            var neo = root.allNeoForgeInstallers[n]
            if (neo.gameVersion === root.selectedGameVersion) {
                neoforgeInstallerModel.append({
                    "loaderVersion": neo.loaderVersion || "",
                    "gameVersion": neo.gameVersion || "",
                    "releaseTime": neo.releaseTime || ""
                })
            }
        }
    }

    function installSelected() {
        if (root.selectedGameVersion.length === 0) {
            root.backend.output = "请选择 Minecraft 版本。"
            return
        }

        var loaderVersion = root.selectedLoaderVersion()

        if (root.selectedLoaderKind !== "vanilla" && loaderVersion.length === 0) {
            root.backend.output = "请选择加载器版本。"
            return
        }

        root.downloadFinishHandled = false
        root.downloadCancelDismissed = false
        root.downloadDialogOpen = true

        root.backend.installGameVersion(
            root.downloadSource,
            root.selectedGameVersion,
            root.selectedLoaderKind,
            loaderVersion
        )

        root.pollDownloadTask()
    }

    function selectedLoaderVersion() {
        switch (root.selectedLoaderKind) {
        case "fabric":
            return fabricCombo.currentText || ""
        case "quilt":
            return quiltCombo.currentText || ""
        case "forge":
            return forgeCombo.currentText || ""
        case "neoforge":
            return neoforgeCombo.currentText || ""
        default:
            return ""
        }
    }

    function groupForVersion(id, type) {
        if (root.isAprilFoolsVersion(id)) {
            return "april"
        }

        if (type === "release") {
            return "release"
        }

        if (type === "snapshot" || type === "pending" || type === "unobfuscated") {
            return "snapshot"
        }

        return "old"
    }

    function isAprilFoolsVersion(id) {
        return id === "20w14∞"
                || id === "3D Shareware v1.34"
                || id === "22w13oneBlockAtATime"
                || id === "23w13a_or_b"
                || id.indexOf("infinite") >= 0
    }

    function iconForVersionGroup(group) {
        switch (group) {
        case "release":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/grass.png"
        case "snapshot":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/command.png"
        case "april":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/april_fools.png"
        default:
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/craft_table.png"
        }
    }

    function tagForVersionGroup(group) {
        switch (group) {
        case "release":
            return "正式版"
        case "snapshot":
            return "快照版"
        case "april":
            return "愚人节"
        default:
            return "远古版本"
        }
    }

    function placeholderTitle(tab) {
        switch (tab) {
        case "modpack":
            return "整合包"
        case "mod":
            return "Mod"
        case "resourcepack":
            return "资源包"
        case "shader":
            return "光影包"
        case "world":
            return "世界"
        default:
            return "下载内容"
        }
    }

    component GameDownloadPane: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 4
                color: root.style.cSurfaceContainerHigh
                border.color: root.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "版本搜索"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 13
                    }

                    TextField {
                        id: searchField

                        Layout.fillWidth: true
                        placeholderText: "输入版本号，支持 1.20 / 1.21 / regex 前缀后续接入"
                        text: root.searchText
                        onTextChanged: {
                            root.searchText = text
                            root.rebuildVisibleVersions()
                        }
                    }

                    ComboBox {
                        id: versionFilterCombo
                        Layout.preferredWidth: 128
                        model: ["正式版", "快照版", "愚人节", "远古版本", "全部"]
                        currentIndex: 0

                        onCurrentIndexChanged: {
                            var values = ["release", "snapshot", "april", "old", "all"]
                            root.versionFilter = values[currentIndex]
                            root.rebuildVisibleVersions()
                        }
                    }

                    Text {
                        text: "下载源：设置页"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 11
                    }

                    HmclButton {
                        style: root.style
                        text: root.catalogTaskStatus.active ? "加载中" : "刷新"
                        primary: true
                        buttonEnabled: !root.catalogTaskStatus.active
                        onClicked: root.startRefreshCatalog()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.catalogTaskStatus.active ? 70 : 0
                visible: root.catalogTaskStatus.active
                radius: 4
                color: root.style.cSurfaceContainer
                border.color: root.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    BusyIndicator {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        running: true
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            width: parent.width
                            text: root.catalogTaskStatus.title || "正在获取版本列表"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.catalogTaskStatus.message || ""
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 4
                    color: root.style.cSurfaceContainerHigh
                    border.color: root.style.cBorder
                    border.width: 1
                    clip: true

                    ListView {
                        id: versionList

                        anchors.fill: parent
                        anchors.margins: 10
                        model: visibleVersionModel
                        spacing: 4
                        clip: true

                        delegate: Item {
                            id: versionDelegate

                            required property int index
                            required property int sourceIndex
                            required property string versionId
                            required property string versionType
                            required property string releaseTime
                            required property string group
                            required property string iconSource
                            required property string tagText

                            width: versionList.width
                            height: 56

                            RemoteVersionCell {
                                anchors.fill: parent
                                style: root.style
                                versionId: versionDelegate.versionId
                                subtitle: versionDelegate.releaseTime
                                tagText: versionDelegate.tagText
                                iconSource: versionDelegate.iconSource
                                selected: root.selectedGameVersion === versionDelegate.versionId
                                onClicked: root.openInstallerForVersion(versionDelegate.index)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: visibleVersionModel.count === 0 && !root.catalogTaskStatus.active
                        text: "没有匹配的版本"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    Layout.preferredWidth: root.installerPaneOpen ? 330 : 0
                    Layout.fillHeight: true
                    visible: root.installerPaneOpen
                    opacity: root.installerPaneOpen ? 1 : 0
                    radius: 4
                    color: root.style.cSurfaceContainerHigh
                    border.color: root.style.cBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: "安装"
                                color: root.style.cTextOnSurface
                                font.pixelSize: 18
                                font.bold: true
                            }

                            HmclButton {
                                Layout.preferredWidth: 92
                                style: root.style
                                text: "返回版本列表"
                                onClicked: root.closeInstallerPane()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedGameVersion.length > 0
                                  ? "Minecraft " + root.selectedGameVersion
                                  : "请选择 Minecraft 版本"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedGameReleaseTime.length > 0 ? root.selectedGameReleaseTime : "未选择版本"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.style.cBorder
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "加载器"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 8

                            LoaderChip {
                                style: root.style
                                text: "Vanilla"
                                selected: root.selectedLoaderKind === "vanilla"
                                onClicked: root.selectedLoaderKind = "vanilla"
                            }

                            LoaderChip {
                                style: root.style
                                text: "Fabric"
                                selected: root.selectedLoaderKind === "fabric"
                                onClicked: root.selectedLoaderKind = "fabric"
                            }

                            LoaderChip {
                                style: root.style
                                text: "Quilt"
                                selected: root.selectedLoaderKind === "quilt"
                                onClicked: root.selectedLoaderKind = "quilt"
                            }

                            LoaderChip {
                                style: root.style
                                text: "Forge"
                                selected: root.selectedLoaderKind === "forge"
                                onClicked: root.selectedLoaderKind = "forge"
                            }

                            LoaderChip {
                                style: root.style
                                text: "NeoForge"
                                selected: root.selectedLoaderKind === "neoforge"
                                onClicked: root.selectedLoaderKind = "neoforge"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "加载器版本"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 13
                            font.bold: true
                            visible: root.selectedLoaderKind !== "vanilla"
                        }

                        ComboBox {
                            id: fabricCombo
                            visible: root.selectedLoaderKind === "fabric"
                            Layout.fillWidth: true
                            model: fabricLoaderModel
                            textRole: "version"
                        }

                        ComboBox {
                            id: quiltCombo
                            visible: root.selectedLoaderKind === "quilt"
                            Layout.fillWidth: true
                            model: quiltLoaderModel
                            textRole: "version"
                        }

                        ComboBox {
                            id: forgeCombo
                            visible: root.selectedLoaderKind === "forge"
                            Layout.fillWidth: true
                            model: forgeInstallerModel
                            textRole: "loaderVersion"
                        }

                        ComboBox {
                            id: neoforgeCombo
                            visible: root.selectedLoaderKind === "neoforge"
                            Layout.fillWidth: true
                            model: neoforgeInstallerModel
                            textRole: "loaderVersion"
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedLoaderKind === "vanilla"
                                  ? "原版会下载 version json、client jar、libraries、natives 和 assets。"
                                  : "加载器会按所选 Minecraft 版本安装对应 profile 和依赖。"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        HmclButton {
                            Layout.fillWidth: true
                            style: root.style
                            text: root.downloadTaskStatus.active ? "查看下载任务" : "安装所选版本"
                            primary: true
                            onClicked: {
                                if (root.downloadTaskStatus.active) {
                                    root.downloadDialogOpen = true
                                } else {
                                    root.installSelected()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component DownloadPlaceholderPane: Rectangle {
        required property string title
        required property string message

        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 560)
            height: 220
            radius: 4
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 10

                Text {
                    width: parent.width
                    text: title
                    color: root.style.cTextOnSurface
                    font.pixelSize: 22
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: message
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component HmclClassTitle: Item {
        property string text: ""

        height: 28

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text
            color: root.style.cTextOnSurfaceVariant
            font.pixelSize: 11
            font.bold: true
        }
    }

    component DownloadNavItem: Item {
        id: item

        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconSource: ""
        property string iconKind: ""
        property bool selected: false

        signal clicked()

        height: 48

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: item.selected
                   ? Qt.rgba(item.style.cPrimary.r, item.style.cPrimary.g, item.style.cPrimary.b, 0.14)
                   : (mouse.containsMouse ? Qt.rgba(item.style.cTextOnSurface.r, item.style.cTextOnSurface.g, item.style.cTextOnSurface.b, 0.06) : "transparent")
        }

        Image {
            visible: item.iconSource.length > 0
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            source: item.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
        }

        HmclSvgIcon {
            visible: item.iconSource.length === 0
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            icon: item.iconKind
            iconSize: 22
            iconColor: item.selected ? item.style.cPrimary : item.style.cTextOnSurfaceVariant
            animationsEnabled: item.style.animationsEnabled
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: item.title
                color: item.selected ? item.style.cPrimary : item.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: item.selected
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: item.subtitle
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
        }
    }

    component RemoteVersionCell: Item {
        id: cell

        required property var style
        property string versionId: ""
        property string subtitle: ""
        property string tagText: ""
        property string iconSource: ""
        property bool selected: false

        signal clicked()

        height: 56

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: cell.selected
                   ? Qt.rgba(cell.style.cPrimary.r, cell.style.cPrimary.g, cell.style.cPrimary.b, 0.14)
                   : (mouse.containsMouse ? Qt.rgba(cell.style.cTextOnSurface.r, cell.style.cTextOnSurface.g, cell.style.cTextOnSurface.b, 0.06) : "transparent")
        }

        Image {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            source: cell.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 62
            anchors.right: arrow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: cell.versionId
                    color: cell.style.cTextOnSurface
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - tag.width - 12)
                }

                Rectangle {
                    id: tag
                    width: tagText.implicitWidth + 12
                    height: 20
                    radius: 2
                    color: Qt.rgba(cell.style.cPrimary.r, cell.style.cPrimary.g, cell.style.cPrimary.b, 0.14)

                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: cell.tagText
                        color: cell.style.cPrimary
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                width: parent.width
                text: cell.subtitle
                color: cell.style.cTextOnSurfaceVariant
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        HmclSvgIcon {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            icon: "ARROW_FORWARD"
            iconSize: 20
            iconColor: cell.style.cTextOnSurfaceVariant
            animationsEnabled: cell.style.animationsEnabled
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cell.clicked()
        }
    }

    component LoaderChip: Item {
        id: chip

        required property var style
        property string text: ""
        property bool selected: false

        signal clicked()

        width: label.implicitWidth + 24
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: chip.selected
                   ? Qt.rgba(chip.style.cPrimary.r, chip.style.cPrimary.g, chip.style.cPrimary.b, 0.16)
                   : (mouse.containsMouse ? Qt.rgba(chip.style.cTextOnSurface.r, chip.style.cTextOnSurface.g, chip.style.cTextOnSurface.b, 0.06) : chip.style.cSurfaceContainer)
            border.color: chip.selected ? chip.style.cPrimary : chip.style.cBorder
            border.width: 1
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? chip.style.cPrimary : chip.style.cTextOnSurface
            font.pixelSize: 12
            font.bold: chip.selected
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component HmclButton: Item {
        id: button

        required property var style
        property string text: ""
        property bool primary: false
        property bool buttonEnabled: true

        signal clicked()

        implicitHeight: 36
        height: 36
        opacity: button.buttonEnabled ? 1.0 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: button.primary
                   ? button.style.cPrimary
                   : (mouse.containsMouse ? button.style.cButtonHover : button.style.cButtonSurface)
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? button.style.cButtonSelectedText : button.style.cTextOnSurface
            font.pixelSize: 12
            font.bold: button.primary
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.buttonEnabled
            cursorShape: button.buttonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    component DownloadDialogCard: Rectangle {
        id: card

        required property var style
        property var status: ({})

        signal cancelRequested()
        signal closeRequested()

        radius: 4
        color: style.cSurfaceContainerHigh
        border.color: style.cBorder
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: card.status.title || "下载任务"
                color: card.style.cTextOnSurface
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: card.status.message || ""
                color: card.style.cTextOnSurfaceVariant
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.10)

                Rectangle {
                    height: parent.height
                    radius: 3
                    width: parent.width * Math.max(0, Math.min(100, card.status.percent || 0)) / 100
                    color: card.style.cPrimary
                }
            }

            Text {
                Layout.fillWidth: true
                text: Math.round(card.status.percent || 0) + "%  " + (card.status.currentFile || "")
                color: card.style.cTextOnSurfaceVariant
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                HmclButton {
                    Layout.preferredWidth: 90
                    style: card.style
                    text: card.status.active ? "取消" : "关闭"
                    primary: false
                    onClicked: {
                        if (card.status.active) {
                            card.cancelRequested()
                        } else {
                            card.closeRequested()
                        }
                    }
                }
            }
        }
    }
}
