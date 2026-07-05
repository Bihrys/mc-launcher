import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    property string downloadSource: "bmcl"
    property string selectedGameVersion: ""
    property string selectedLoaderKind: "vanilla"
    property string versionGroup: "release"
    property var catalog: null
    property var activeVersionModel: releaseVersionModel
    property bool downloadDialogOpen: false
    property bool downloadCancelDismissed: false
    property bool downloadFinishHandled: false

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

    property string loadedCatalogJson: ""

    ListModel { id: releaseVersionModel }
    ListModel { id: snapshotVersionModel }
    ListModel { id: aprilFoolsVersionModel }
    ListModel { id: oldBetaVersionModel }
    ListModel { id: oldAlphaVersionModel }

    ListModel { id: fabricLoaderModel }
    ListModel { id: quiltLoaderModel }
    ListModel { id: forgeInstallerModel }
    ListModel { id: neoforgeInstallerModel }

    Timer {
        id: downloadTaskPoller
        interval: 250
        repeat: true
        running: true
        onTriggered: root.pollDownloadTask()
    }

    Timer {
        id: catalogTaskPoller
        interval: 300
        repeat: true
        running: true
        onTriggered: root.pollDownloadCatalogTask()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        anchors.bottomMargin: 96
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "下载"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 24
                    font.bold: true
                }

                Text {
                    text: "选择版本和加载器；下载任务会以 HMCL 风格弹窗显示。"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                }
            }

            ChoiceButton {
                style: root.style
                text: "官方源"
                selected: root.downloadSource === "official"
                onClicked: root.downloadSource = "official"
            }

            ChoiceButton {
                style: root.style
                text: "BMCLAPI"
                selected: root.downloadSource === "bmcl"
                onClicked: root.downloadSource = "bmcl"
            }

            ActionButton {
                style: root.style
                text: root.catalogTaskStatus.active ? "加载中" : "刷新列表"
                primary: true
                onClicked: root.startRefreshCatalog()
            }

            BusyIndicator {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                running: root.catalogTaskStatus.active
                visible: root.catalogTaskStatus.active
            }
        }

        CatalogTaskPanel {
            Layout.fillWidth: true
            Layout.maximumWidth: 1060
            Layout.preferredHeight: root.catalogTaskStatus.active ? 92 : 0
            visible: root.catalogTaskStatus.active
            style: root.style
            status: root.catalogTaskStatus
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 1060
            Layout.minimumHeight: 520
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 230
                    Layout.fillHeight: true
                    radius: root.style.radiusValue
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "版本分类"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: root.catalog
                                  ? "正式版 " + root.catalog.latestRelease + " / 快照 " + root.catalog.latestSnapshot
                                  : "点击刷新列表"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        CategoryItem {
                            style: root.style
                            title: "正式版"
                            subtitle: "稳定发布版本"
                            count: releaseVersionModel.count
                            selected: root.versionGroup === "release"
                            onClicked: root.setVersionGroup("release")
                        }

                        CategoryItem {
                            style: root.style
                            title: "快照版"
                            subtitle: "Snapshot / Pre-release / RC"
                            count: snapshotVersionModel.count
                            selected: root.versionGroup === "snapshot"
                            onClicked: root.setVersionGroup("snapshot")
                        }

                        CategoryItem {
                            style: root.style
                            title: "愚人节 / 特殊版本"
                            subtitle: "20w14∞ / One Block 等"
                            count: aprilFoolsVersionModel.count
                            selected: root.versionGroup === "april"
                            onClicked: root.setVersionGroup("april")
                        }

                        CategoryItem {
                            style: root.style
                            title: "远古 Beta"
                            subtitle: "old_beta"
                            count: oldBetaVersionModel.count
                            selected: root.versionGroup === "old_beta"
                            onClicked: root.setVersionGroup("old_beta")
                        }

                        CategoryItem {
                            style: root.style
                            title: "远古 Alpha"
                            subtitle: "old_alpha"
                            count: oldAlphaVersionModel.count
                            selected: root.versionGroup === "old_alpha"
                            onClicked: root.setVersionGroup("old_alpha")
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    radius: root.style.radiusValue
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: root.groupTitle(root.versionGroup)
                            color: root.style.cTextOnSurface
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.activeVersionModel && root.activeVersionModel.count > 0
                                  ? "共 " + root.activeVersionModel.count + " 个版本"
                                  : "该分类暂无版本"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                        }

                        ListView {
                            id: gameList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.activeVersionModel
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Rectangle {
                                width: gameList.width
                                height: 56
                                radius: 8
                                color: root.selectedGameVersion === versionId
                                       ? root.style.cNavSelected
                                       : gameMouse.containsMouse ? root.style.cNavHover : "transparent"
                                border.width: root.selectedGameVersion === versionId ? 1 : 0
                                border.color: root.style.cBorder

                                MouseArea {
                                    id: gameMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedGameVersion = versionId
                                        root.rebuildInstallerModels()
                                    }
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 4

                                    Text {
                                        width: parent.width
                                        text: versionId
                                        color: root.style.cTextOnSurface
                                        font.pixelSize: 14
                                        font.bold: root.selectedGameVersion === versionId
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: versionType + " · " + releaseTime
                                        color: root.style.cTextOnSurfaceVariant
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.style.radiusValue
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            text: "安装配置"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedGameVersion.length > 0
                                  ? "当前选择：Minecraft " + root.selectedGameVersion
                                  : "请先在左侧选择 Minecraft 版本。"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            spacing: 8

                            ChoiceButton {
                                style: root.style
                                text: "原版"
                                selected: root.selectedLoaderKind === "vanilla"
                                onClicked: root.selectedLoaderKind = "vanilla"
                            }

                            ChoiceButton {
                                style: root.style
                                text: "Fabric"
                                selected: root.selectedLoaderKind === "fabric"
                                onClicked: root.selectedLoaderKind = "fabric"
                            }

                            ChoiceButton {
                                style: root.style
                                text: "Quilt"
                                selected: root.selectedLoaderKind === "quilt"
                                onClicked: root.selectedLoaderKind = "quilt"
                            }

                            ChoiceButton {
                                style: root.style
                                text: "Forge"
                                selected: root.selectedLoaderKind === "forge"
                                onClicked: root.selectedLoaderKind = "forge"
                            }

                            ChoiceButton {
                                style: root.style
                                text: "NeoForge"
                                selected: root.selectedLoaderKind === "neoforge"
                                onClicked: root.selectedLoaderKind = "neoforge"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 126
                            radius: root.style.radiusValue
                            color: root.style.cSurfaceContainerHigh
                            border.color: root.style.cBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    text: "加载器版本"
                                    color: root.style.cTextOnSurface
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    visible: root.selectedLoaderKind === "vanilla"
                                    text: "原版不需要选择加载器。安装时会下载 version json、client jar、libraries、natives、assets。"
                                    color: root.style.cTextOnSurfaceVariant
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
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
                                    visible: root.selectedLoaderKind === "forge" || root.selectedLoaderKind === "neoforge"
                                    Layout.fillWidth: true
                                    text: "Forge / NeoForge 当前先下载 installer jar；installer processor 执行下一步补。"
                                    color: root.style.cTextOnSurfaceVariant
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92
                            radius: root.style.radiusValue
                            color: root.style.cSurfaceContainerHigh
                            border.color: root.style.cBorder
                            border.width: 1

                            Text {
                                anchors.fill: parent
                                anchors.margins: 12
                                text: root.installPreview()
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: root.downloadTaskStatus.active
                                      ? "下载任务正在运行，点击右侧按钮查看。"
                                      : "安装目录：~/.local/share/mc-launcher/minecraft/"
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 11
                                elide: Text.ElideLeft
                            }

                            ActionButton {
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
    }

    Rectangle {
        id: downloadDialogOverlay

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
            width: Math.min(root.width - 64, 500)
            height: Math.min(root.height - 64, 300)
            style: root.style
            status: root.downloadTaskStatus
            onCancelRequested: {
                // HMCL 逻辑：UI 立刻关闭；后台任务取消由后端继续处理。
                root.downloadCancelDismissed = true
                root.downloadDialogOpen = false
                root.backend.cancelDownloadTask()
            }
            onCloseRequested: root.downloadDialogOpen = false
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

    function startRefreshCatalog() {
        releaseVersionModel.clear()
        snapshotVersionModel.clear()
        aprilFoolsVersionModel.clear()
        oldBetaVersionModel.clear()
        oldAlphaVersionModel.clear()
        forgeInstallerModel.clear()
        neoforgeInstallerModel.clear()
        fabricLoaderModel.clear()
        quiltLoaderModel.clear()

        root.selectedGameVersion = ""
        root.loadedCatalogJson = ""

        root.catalogTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在获取版本列表",
            "message": "正在连接版本源，界面不会卡死。",
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
                    && root.loadedCatalogJson !== status.catalogJson) {
                root.loadedCatalogJson = status.catalogJson
                root.applyCatalog(JSON.parse(status.catalogJson))
            }
        } catch (e) {
            console.log("Failed to parse catalog task status", e)
        }
    }

    function applyCatalog(catalog) {
        root.catalog = catalog

        releaseVersionModel.clear()
        snapshotVersionModel.clear()
        aprilFoolsVersionModel.clear()
        oldBetaVersionModel.clear()
        oldAlphaVersionModel.clear()

        fabricLoaderModel.clear()
        quiltLoaderModel.clear()

        for (var i = 0; i < root.catalog.gameVersions.length; i++) {
            var game = root.catalog.gameVersions[i]
            var item = {
                "versionId": game.id,
                "versionType": game.versionType,
                "releaseTime": game.releaseTime
            }

            var group = root.classifyGameVersion(game)

            if (group === "release") {
                releaseVersionModel.append(item)
            } else if (group === "snapshot") {
                snapshotVersionModel.append(item)
            } else if (group === "april") {
                aprilFoolsVersionModel.append(item)
            } else if (group === "old_beta") {
                oldBetaVersionModel.append(item)
            } else if (group === "old_alpha") {
                oldAlphaVersionModel.append(item)
            }
        }

        for (var f = 0; f < root.catalog.fabricLoaders.length; f++) {
            fabricLoaderModel.append({
                "version": root.catalog.fabricLoaders[f].version,
                "stable": root.catalog.fabricLoaders[f].stable
            })
        }

        for (var q = 0; q < root.catalog.quiltLoaders.length; q++) {
            quiltLoaderModel.append({
                "version": root.catalog.quiltLoaders[q].version,
                "stable": root.catalog.quiltLoaders[q].stable
            })
        }

        root.setVersionGroup(root.versionGroup)

        if (root.selectedGameVersion.length === 0) {
            root.setVersionGroup("release")
        }

        root.rebuildInstallerModels()
    }

    function classifyGameVersion(game) {
        if (root.isAprilFoolsVersion(game.id)) {
            return "april"
        }

        if (game.versionType === "release") {
            return "release"
        }

        if (game.versionType === "snapshot") {
            return "snapshot"
        }

        if (game.versionType === "old_beta") {
            return "old_beta"
        }

        if (game.versionType === "old_alpha") {
            return "old_alpha"
        }

        return "snapshot"
    }

    function isAprilFoolsVersion(id) {
        var lower = String(id).toLowerCase()

        if (id === "2.0") return true
        if (id === "15w14a") return true
        if (id === "1.RV-Pre1") return true

        return lower.indexOf("infinite") >= 0
            || lower.indexOf("oneblockatatime") >= 0
            || lower.indexOf("_or_b") >= 0
            || lower.indexOf("potato") >= 0
            || lower.indexOf("craftmine") >= 0
            || lower.indexOf("shareware") >= 0
            || lower.indexOf("3d shareware") >= 0
    }

    function setVersionGroup(group) {
        root.versionGroup = group

        if (group === "release") {
            root.activeVersionModel = releaseVersionModel
        } else if (group === "snapshot") {
            root.activeVersionModel = snapshotVersionModel
        } else if (group === "april") {
            root.activeVersionModel = aprilFoolsVersionModel
        } else if (group === "old_beta") {
            root.activeVersionModel = oldBetaVersionModel
        } else if (group === "old_alpha") {
            root.activeVersionModel = oldAlphaVersionModel
        } else {
            root.activeVersionModel = releaseVersionModel
        }

        root.selectFirstVersionInActiveGroup()
        root.rebuildInstallerModels()
    }

    function selectFirstVersionInActiveGroup() {
        if (!root.activeVersionModel || root.activeVersionModel.count <= 0) {
            root.selectedGameVersion = ""
            return
        }

        root.selectedGameVersion = root.activeVersionModel.get(0).versionId
    }

    function groupTitle(group) {
        if (group === "release") return "正式版"
        if (group === "snapshot") return "快照版"
        if (group === "april") return "愚人节 / 特殊版本"
        if (group === "old_beta") return "远古 Beta"
        if (group === "old_alpha") return "远古 Alpha"
        return "版本"
    }

    function rebuildInstallerModels() {
        forgeInstallerModel.clear()
        neoforgeInstallerModel.clear()

        if (!root.catalog || root.selectedGameVersion.length === 0) {
            return
        }

        for (var i = 0; i < root.catalog.forgeInstallers.length; i++) {
            var forge = root.catalog.forgeInstallers[i]
            if (forge.gameVersion === root.selectedGameVersion) {
                forgeInstallerModel.append({
                    "gameVersion": forge.gameVersion,
                    "loaderVersion": forge.loaderVersion,
                    "url": forge.url
                })
            }
        }

        for (var n = 0; n < root.catalog.neoforgeInstallers.length; n++) {
            var neo = root.catalog.neoforgeInstallers[n]
            if (neo.gameVersion === root.selectedGameVersion) {
                neoforgeInstallerModel.append({
                    "gameVersion": neo.gameVersion,
                    "loaderVersion": neo.loaderVersion,
                    "url": neo.url
                })
            }
        }
    }

    function selectedLoaderVersion() {
        if (root.selectedLoaderKind === "fabric" && fabricCombo.currentIndex >= 0) {
            return fabricLoaderModel.get(fabricCombo.currentIndex).version
        }

        if (root.selectedLoaderKind === "quilt" && quiltCombo.currentIndex >= 0) {
            return quiltLoaderModel.get(quiltCombo.currentIndex).version
        }

        if (root.selectedLoaderKind === "forge" && forgeCombo.currentIndex >= 0) {
            return forgeInstallerModel.get(forgeCombo.currentIndex).loaderVersion
        }

        if (root.selectedLoaderKind === "neoforge" && neoforgeCombo.currentIndex >= 0) {
            return neoforgeInstallerModel.get(neoforgeCombo.currentIndex).loaderVersion
        }

        return ""
    }

    function installPreview() {
        if (root.selectedGameVersion.length === 0) {
            return "还没有选择 Minecraft 版本。"
        }

        var loaderVersion = root.selectedLoaderVersion()

        if (root.selectedLoaderKind === "vanilla") {
            return "将安装 " + root.groupTitle(root.versionGroup) + "：Minecraft " + root.selectedGameVersion + " 原版。"
        }

        if (loaderVersion.length === 0) {
            return "请选择 " + root.selectedLoaderKind + " 版本。"
        }

        return "将安装 Minecraft " + root.selectedGameVersion
            + " + " + root.selectedLoaderKind
            + " " + loaderVersion + "。"
    }

    function formatBytes(value) {
        value = Number(value || 0)

        if (value >= 1024 * 1024 * 1024) {
            return (value / 1024 / 1024 / 1024).toFixed(2) + " GB"
        }

        if (value >= 1024 * 1024) {
            return (value / 1024 / 1024).toFixed(2) + " MB"
        }

        if (value >= 1024) {
            return (value / 1024).toFixed(1) + " KB"
        }

        return String(Math.round(value)) + " B"
    }

    function installSelected() {
        root.downloadCancelDismissed = false
        root.downloadFinishHandled = false
        root.downloadDialogOpen = true

        root.backend.installGameVersion(
            root.downloadSource,
            root.selectedGameVersion,
            root.selectedLoaderKind,
            root.selectedLoaderVersion()
        )

        root.pollDownloadTask()
    }

    component CategoryItem: Rectangle {
        id: item

        required property var style
        property string title: ""
        property string subtitle: ""
        property int count: 0
        property bool selected: false

        signal clicked()

        width: parent ? parent.width : 200
        height: 62
        radius: 8

        color: selected
               ? style.cNavSelected
               : mouse.containsMouse ? style.cNavHover : "transparent"

        border.width: selected ? 1 : 0
        border.color: style.cBorder

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    width: parent.width
                    text: item.title
                    color: item.style.cTextOnSurface
                    font.pixelSize: 14
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

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 24
                radius: 12
                color: item.selected ? item.style.cButtonSelected : item.style.cButtonSurface
                border.width: item.selected ? 0 : 1
                border.color: item.style.cBorder

                Text {
                    anchors.centerIn: parent
                    text: String(item.count)
                    color: item.selected ? item.style.cButtonSelectedText : item.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    font.bold: item.selected
                }
            }
        }
    }

    component ChoiceButton: Rectangle {
        id: button

        required property var style
        property string text: ""
        property bool selected: false

        signal clicked()

        width: Math.max(74, label.implicitWidth + 24)
        height: 34
        radius: 17

        color: selected
               ? style.cButtonSelected
               : mouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: selected ? 0 : 1
        border.color: style.cBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.selected ? button.style.cButtonSelectedText : button.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: button.selected
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: button

        required property var style
        property string text: ""
        property bool primary: false

        signal clicked()

        width: Math.max(126, label.implicitWidth + 28)
        height: 38
        radius: 19

        color: primary
               ? mouse.containsMouse ? style.cLaunchButtonHover : style.cLaunchButton
               : mouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: primary ? 0 : 1
        border.color: style.cBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? button.style.cLaunchButtonText : button.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: button.primary
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component MaterialProgressBar: Rectangle {
        id: bar

        required property var style
        property real value: 0

        height: 6
        radius: 2
        color: style.cSurfaceContainerHigh
        clip: true

        Rectangle {
            height: parent.height
            radius: 2
            color: bar.style.cButtonSelected
            width: Math.max(0, Math.min(parent.width, parent.width * bar.value / 100.0))

            Behavior on width {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    component TaskRow: Rectangle {
        id: row

        required property var style
        property string title: ""
        property string rightText: ""
        property real progress: 0
        property bool running: false
        property bool failed: false
        property bool success: false

        height: 48
        color: "transparent"

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: row.title
                    color: row.style.cTextOnSurface
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    text: row.rightText
                    color: row.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            MaterialProgressBar {
                width: parent.width
                style: row.style
                value: row.progress
            }
        }
    }

    component StatBlock: Rectangle {
        id: block

        required property var style
        property string label: ""
        property string value: ""

        implicitHeight: 46
        radius: 8
        color: style.cSurfaceContainerHigh
        border.color: style.cBorder
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                width: parent.width
                text: block.label
                color: block.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: block.value
                color: block.style.cTextOnSurface
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
        }
    }

    // HMCL TaskExecutorDialogPane + TaskListPane 的 Qt/QML 等价实现。
    // 用在“安装所选版本”之后的下载/安装任务弹窗。
    component DownloadDialogCard: Rectangle {
        id: panel

        required property var style
        property var status: ({
            "active": false,
            "cancelled": false,
            "percent": 0,
            "title": "下载任务",
            "message": "",
            "totalFiles": 0,
            "finishedFiles": 0,
            "totalBytes": 0,
            "downloadedBytes": 0,
            "currentFile": "",
            "speed": 0,
            "status": "idle"
        })

        signal cancelRequested()
        signal closeRequested()

        radius: 4
        color: panel.style.cSurfaceContainerHigh
        border.width: 0
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
        }

        // HMCL: center VBox padding 16, bottom BorderPane padding 0 8 8 8
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 0

                Text {
                    width: parent.width
                    height: 18
                    text: panel.status.title || "正在进行"
                    color: panel.style.cTextOnSurface
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                // HMCL TaskListPane: ListView padding top 12
                Item {
                    width: parent.width
                    height: parent.height - 18
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        spacing: 4

                        HmclTaskStageRow {
                            width: parent.width
                            style: panel.style
                            title: panel.stageTitle()
                            state: panel.stageState()
                        }

                        HmclTaskProgressRow {
                            width: parent.width
                            style: panel.style
                            title: panel.taskTitle()
                            message: panel.taskMessage()
                            progress: panel.status.percent || 0
                            indented: true
                        }

                        HmclTaskProgressRow {
                            width: parent.width
                            visible: (panel.status.totalFiles || 0) > 0
                            style: panel.style
                            title: "处理文件"
                            message: (panel.status.finishedFiles || 0) + " / " + (panel.status.totalFiles || 0)
                            progress: panel.filePercent()
                            indented: true
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 46

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 130
                    text: panel.bottomText()
                    color: panel.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                HmclDialogTextButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    style: panel.style
                    text: panel.status.active
                          ? panel.status.status === "cancelling" ? "取消中" : "取消"
                          : "关闭"
                    buttonEnabled: true
                    onClicked: {
                        if (panel.status.active) {
                            if (panel.status.status !== "cancelling") {
                                panel.cancelRequested()
                            }
                        } else {
                            panel.closeRequested()
                        }
                    }
                }
            }
        }

        function stageTitle() {
            if (status.status === "finished") return "完成安装"
            if (status.status === "failed") return "安装失败"
            if (status.status === "cancelled") return "安装已取消"
            if (status.status === "cancelling") return "正在取消"
            return "安装游戏"
        }

        function stageState() {
            if (status.status === "finished") return "success"
            if (status.status === "failed") return "failed"
            if (status.status === "cancelled") return "cancelled"
            return "running"
        }

        function taskTitle() {
            if (status.currentFile && status.currentFile.length > 0) {
                return status.currentFile
            }

            if (status.message && status.message.length > 0) {
                var firstLine = String(status.message).split("\\n")[0]
                if (firstLine.length > 0) return firstLine
            }

            if (status.status === "finished") return "任务完成"
            if (status.status === "failed") return "任务失败"
            if (status.status === "cancelled") return "任务已取消"
            return "等待下载任务开始"
        }

        function taskMessage() {
            if (status.status === "finished") return "100%"
            if (status.status === "failed") return "失败"
            if (status.status === "cancelled") return "已取消"
            if (status.status === "cancelling") return "取消中"
            return String(Math.round(status.percent || 0)) + "%"
        }

        function filePercent() {
            var total = Number(status.totalFiles || 0)
            if (total <= 0) return 0
            return Math.min(100, Math.round(Number(status.finishedFiles || 0) * 100 / total))
        }

        function bottomText() {
            if (status.active) {
                return root.formatBytes(status.speed || 0) + "/s"
            }

            if (status.status === "finished") return "下载完成"
            if (status.status === "cancelled") return "下载已取消"
            if (status.status === "failed") return "下载失败"
            return "空闲"
        }
    }

    component HmclTaskStageRow: Item {
        id: row

        required property var style
        property string title: ""
        property string state: "running"

        height: 26

        Item {
            id: iconBox
            width: 14
            height: 14
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7
                color: "transparent"
                border.width: 1.5
                border.color: row.iconColor()
            }

            Text {
                anchors.centerIn: parent
                text: row.iconText()
                color: row.iconColor()
                font.pixelSize: row.state === "running" ? 9 : 10
                font.bold: true
            }
        }

        Text {
            anchors.left: iconBox.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.title
            color: row.style.cTextOnSurface
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        function iconText() {
            if (state === "success") return "✓"
            if (state === "failed") return "×"
            if (state === "cancelled") return "−"
            return ""
        }

        function iconColor() {
            if (state === "failed") return "#BA1A1A"
            if (state === "cancelled") return row.style.cTextOnSurfaceVariant
            if (state === "success") return row.style.cButtonSelected
            return row.style.cTextOnSurfaceVariant
        }
    }

    component HmclTaskProgressRow: Item {
        id: row

        required property var style
        property string title: ""
        property string message: ""
        property real progress: 0
        property bool indented: false

        height: 42

        Column {
            anchors.left: parent.left
            anchors.leftMargin: row.indented ? 26 : 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: row.title
                    color: row.style.cTextOnSurface
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    text: row.message
                    color: row.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            HmclTinyProgressBar {
                width: parent.width
                style: row.style
                value: row.progress
            }
        }
    }

    component HmclTinyProgressBar: Rectangle {
        id: bar

        required property var style
        property real value: 0

        height: 2
        radius: 1
        color: bar.style.cSurfaceContainer
        clip: true

        Rectangle {
            height: parent.height
            radius: 1
            color: bar.style.cButtonSelected
            width: Math.max(0, Math.min(parent.width, parent.width * bar.value / 100.0))

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    component HmclDialogTextButton: Rectangle {
        id: button

        required property var style
        property string text: ""
        property bool buttonEnabled: true

        signal clicked()

        width: Math.max(72, label.implicitWidth + 28)
        height: 34
        radius: 2
        opacity: button.buttonEnabled ? 1.0 : 0.45
        color: mouse.containsMouse && button.buttonEnabled ? button.style.cButtonHover : "transparent"

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.style.cTextOnSurfaceVariant
            font.pixelSize: 13
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: button.buttonEnabled
            hoverEnabled: true
            cursorShape: button.buttonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    component CatalogTaskPanel: Rectangle {
        id: panel

        required property var style
        property var status: ({
            "active": false,
            "percent": 0,
            "title": "空闲",
            "message": "还没有版本列表刷新任务。"
        })

        radius: style.radiusValue
        color: style.cSurfaceContainer
        border.color: style.cBorder
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            BusyIndicator {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                running: panel.status.active
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: panel.status.title || "正在加载"
                        color: panel.style.cTextOnSurface
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: String(Math.round(panel.status.percent || 0)) + "%"
                        color: panel.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                MaterialProgressBar {
                    Layout.fillWidth: true
                    style: panel.style
                    value: panel.status.percent || 0
                }

                Text {
                    Layout.fillWidth: true
                    text: panel.status.message || "正在等待网络响应。"
                    color: panel.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }
}
