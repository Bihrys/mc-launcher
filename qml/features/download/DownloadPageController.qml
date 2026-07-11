import QtQuick
import QtQml.Models

Item {
    id: root
    objectName: "downloadPageController"
    visible: false
    width: 0
    height: 0

    required property var style
    required property var backend

    property string currentTab: "game"
    property string downloadSource: "auto"
    property string selectedGameVersion: ""
    property string selectedGameReleaseTime: ""
    property string selectedLoaderKind: "vanilla"

    property string installVersionName: ""
    property bool installNameModifiedByUser: false
    property string selectedFabricVersion: ""
    property string selectedQuiltVersion: ""
    property string selectedForgeVersion: ""
    property string selectedNeoForgeVersion: ""
    property bool installerPaneOpen: false
    property bool loaderVersionPaneOpen: false
    property string loaderVersionKind: ""
    property string versionFilter: "release"
    property string searchText: ""
    property string loaderSearchText: ""
    property var catalog: null
    property var allForgeInstallers: []
    property var allNeoForgeInstallers: []
    property bool downloadDialogOpen: false
    property bool downloadCancelDismissed: false
    property bool downloadFinishHandled: false
    property string loadedCatalogJson: ""
    property string loadedLoaderMetadataJson: ""
    property bool catalogLoadFailed: false
    property string catalogFailedMessage: ""
    property int catalogRevision: 0
    readonly property int visibleVersionCount: visibleVersionModel.count

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

    property var installerMetadataTaskStatus: ({
        "active": false,
        "percent": 0,
        "title": "空闲",
        "message": "还没有版本加载任务。",
        "metadataReady": false,
        "metadataJson": ""
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
    ListModel { id: visibleLoaderVersionModel }

    readonly property var allVersions: allVersionsModel
    readonly property var visibleVersions: visibleVersionModel
    readonly property var fabricLoaders: fabricLoaderModel
    readonly property var quiltLoaders: quiltLoaderModel
    readonly property var forgeInstallers: forgeInstallerModel
    readonly property var neoForgeInstallers: neoforgeInstallerModel
    readonly property var visibleLoaderVersions: visibleLoaderVersionModel

    function logAction(action, details) {
        if (!root.backend)
            return
        root.backend.logUiAction("ui.download", action, JSON.stringify(details || {}))
    }

    onCurrentTabChanged: root.logAction("tab_changed", {"tab": root.currentTab})
    onDownloadSourceChanged: root.logAction("source_changed", {"source": root.downloadSource})
    onSelectedGameVersionChanged: root.logAction("game_version_selected", {
        "version": root.selectedGameVersion
    })
    onSelectedLoaderKindChanged: root.logAction("loader_kind_selected", {
        "loaderKind": root.selectedLoaderKind,
        "loaderVersion": root.selectedLoaderVersion()
    })
    onInstallerPaneOpenChanged: root.logAction("installer_pane_changed", {
        "open": root.installerPaneOpen,
        "gameVersion": root.selectedGameVersion
    })
    onLoaderVersionPaneOpenChanged: root.logAction("loader_version_pane_changed", {
        "open": root.loaderVersionPaneOpen,
        "kind": root.loaderVersionKind
    })
    onDownloadDialogOpenChanged: root.logAction("download_dialog_changed", {
        "open": root.downloadDialogOpen,
        "status": root.downloadTaskStatus.status || ""
    })
    onVersionFilterChanged: root.logAction("version_filter_changed", {"filter": root.versionFilter})
    onSearchTextChanged: root.logAction("search_changed", {"length": root.searchText.length})
    onLoaderSearchTextChanged: root.logAction("loader_search_changed", {"length": root.loaderSearchText.length})

    // HMCL completes refresh tasks on the JavaFX application thread and then
    // updates the observable list directly. Mirror that event-driven path by
    // consuming the backend property change signal. The 250 ms poller remains
    // only as a compatibility/failure-state fallback.
    Connections {
        target: root.backend
        ignoreUnknownSignals: true

        function onDownloadCatalogJsonChanged() {
            root.consumeCatalogPayload(root.backend.downloadCatalogJson, "backend_signal")
        }
    }

    Component.onCompleted: {
        root.logAction("page_completed", {})
        root.startRefreshCatalog()
    }

    Component.onDestruction: root.logAction("page_destroyed", {
        "selectedGameVersion": root.selectedGameVersion,
        "selectedLoaderKind": root.selectedLoaderKind,
        "downloadDialogOpen": root.downloadDialogOpen
    })

    Timer {
        id: catalogTaskPoller
        interval: 250
        repeat: true
        running: false
        onTriggered: root.pollDownloadCatalogTask()
    }

    Timer {
        id: installerMetadataPoller
        interval: 250
        repeat: true
        running: false
        onTriggered: root.pollInstallerMetadataTask()
    }

    Timer {
        id: downloadTaskPoller
        interval: 250
        repeat: true
        running: true
        onTriggered: root.pollDownloadTask()
    }

    function showDownloadSidebar() {
        return !root.installerPaneOpen && !root.loaderVersionPaneOpen
    }

    function handleBack() {
        if (root.loaderVersionPaneOpen) {
            root.closeLoaderVersionPane()
            visibleLoaderVersionModel.clear()
            return true
        }

        if (root.installerPaneOpen) {
            root.closeInstallerPane()
            return true
        }

        return false
    }

    function refreshCurrentPage() {
        if (root.loaderVersionPaneOpen && root.loaderVersionKind.length > 0) {
            root.startFetchLoaderMetadata(root.loaderVersionKind)
        } else if (!root.installerPaneOpen) {
            root.startRefreshCatalog()
        }
    }

    function startRefreshCatalog() {
        // HMCL does not destruct the JFXListView while refreshAsync is running.
        // Keep the current model intact until a complete new payload is ready.
        // This also prevents a failed refresh from leaving a permanently empty
        // UI after the backend had already supplied a valid catalog.
        root.loadedCatalogJson = ""
        root.loadedLoaderMetadataJson = ""
        root.loaderVersionPaneOpen = false
        root.loaderVersionKind = ""
        root.catalogLoadFailed = false
        root.catalogFailedMessage = ""

        root.catalogTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在获取版本列表",
            "message": "正在连接 Minecraft 版本源。",
            "catalogReady": false,
            "catalogJson": ""
        }

        root.logAction("catalog_refresh_requested", {
            "source": root.downloadSource,
            "existingAllCount": allVersionsModel.count,
            "existingVisibleCount": visibleVersionModel.count
        })
        root.backend.startRefreshDownloadCatalog(root.downloadSource)
        catalogTaskPoller.restart()
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

            if (!status.active)
                catalogTaskPoller.stop()

            if (status.catalogReady
                    && status.catalogJson
                    && status.catalogJson.length > 0) {
                root.consumeCatalogPayload(status.catalogJson, "task_poller")
            } else if (!status.active && !status.catalogReady) {
                root.catalogLoadFailed = true
                root.catalogFailedMessage = status.message || "获取版本列表失败，点击重试"
            }
        } catch (e) {
            root.logAction("catalog_task_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0}); console.log("Failed to parse download catalog task status", e)
            root.catalogLoadFailed = true
            root.catalogFailedMessage = "解析版本数据失败，点击重试"
        }
    }

    function startFetchInstallerMetadata() {
        if (root.selectedGameVersion.length === 0) {
            return
        }

        fabricLoaderModel.clear()
        quiltLoaderModel.clear()
        forgeInstallerModel.clear()
        neoforgeInstallerModel.clear()
        root.allForgeInstallers = []
        root.allNeoForgeInstallers = []

        root.installerMetadataTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在加载安装器列表",
            "message": "Minecraft " + root.selectedGameVersion,
            "metadataReady": false,
            "metadataJson": ""
        }

        root.backend.startFetchInstallerMetadata(root.downloadSource, root.selectedGameVersion)
        installerMetadataPoller.restart()
    }

    function startFetchLoaderMetadata(kind) {
        if (root.selectedGameVersion.length === 0 || kind.length === 0) {
            return
        }

        visibleLoaderVersionModel.clear()
        root.loaderSearchText = ""

        if (kind === "fabric") {
            fabricLoaderModel.clear()
            root.selectedFabricVersion = ""
        } else if (kind === "quilt") {
            quiltLoaderModel.clear()
            root.selectedQuiltVersion = ""
        } else if (kind === "forge") {
            forgeInstallerModel.clear()
            root.selectedForgeVersion = ""
        } else if (kind === "neoforge") {
            neoforgeInstallerModel.clear()
            root.selectedNeoForgeVersion = ""
        }

        root.loadedLoaderMetadataJson = ""
        root.loaderVersionKind = kind
        root.loaderVersionPaneOpen = true

        root.logAction("loader_versions_page_open_requested", {
            "gameVersion": root.selectedGameVersion,
            "loaderKind": kind
        })

        root.installerMetadataTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在加载 " + root.loaderTitle(kind) + " 版本",
            "message": "Minecraft " + root.selectedGameVersion,
            "metadataReady": false,
            "metadataJson": ""
        }

        root.backend.startFetchLoaderMetadata(root.downloadSource, root.selectedGameVersion, kind)
        installerMetadataPoller.restart()
    }

    function pollInstallerMetadataTask() {
        var raw = root.backend.pollInstallerMetadataTask()

        if (!raw || raw.length === 0) {
            return
        }

        try {
            var status = JSON.parse(raw)
            root.installerMetadataTaskStatus = status

            if (!status.active) {
                installerMetadataPoller.stop()
            }

            if (!status.active && status.metadataReady) {
                if (status.metadataJson
                        && status.metadataJson.length > 0
                        && status.metadataJson !== root.loadedLoaderMetadataJson) {
                    root.loadedLoaderMetadataJson = status.metadataJson
                    root.parseInstallerMetadata(status.metadataJson)
                }
            }
        } catch (e) {
            root.logAction("installer_task_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0}); console.log("Failed to parse installer metadata task", e)
        }
    }

    function parseInstallerMetadata(raw) {
        try {
            var data = JSON.parse(raw)
            var kind = data.loaderKind || root.loaderVersionKind

            if (!kind || kind === "fabric") {
                fabricLoaderModel.clear()
            }
            if (!kind || kind === "quilt") {
                quiltLoaderModel.clear()
            }
            if (!kind || kind === "forge") {
                forgeInstallerModel.clear()
            }
            if (!kind || kind === "neoforge") {
                neoforgeInstallerModel.clear()
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

            var forge = data.forgeInstallers || []
            for (var i = 0; i < forge.length; i++) {
                forgeInstallerModel.append({
                    "loaderVersion": forge[i].loaderVersion || "",
                    "gameVersion": forge[i].gameVersion || root.selectedGameVersion,
                    "releaseTime": forge[i].releaseTime || ""
                })
            }

            var neo = data.neoforgeInstallers || []
            for (var n = 0; n < neo.length; n++) {
                neoforgeInstallerModel.append({
                    "loaderVersion": neo[n].loaderVersion || "",
                    "gameVersion": neo[n].gameVersion || root.selectedGameVersion,
                    "releaseTime": neo[n].releaseTime || ""
                })
            }

            root.rebuildVisibleLoaderVersions()
            root.logAction("installer_metadata_models_rebuilt", {
                "loaderKind": kind || "all",
                "fabricCount": fabricLoaderModel.count,
                "quiltCount": quiltLoaderModel.count,
                "forgeCount": forgeInstallerModel.count,
                "neoForgeCount": neoforgeInstallerModel.count,
                "visibleCount": visibleLoaderVersionModel.count
            })
        } catch (e) {
            root.logAction("installer_metadata_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0}); console.log("Failed to parse installer metadata", e)
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
            root.logAction("download_task_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0}); console.log("Failed to parse download task status", e)
        }
    }

    function consumeCatalogPayload(raw, origin) {
        if (!raw || raw.length === 0 || raw === root.loadedCatalogJson)
            return

        root.loadedCatalogJson = raw
        root.catalogLoadFailed = false
        root.catalogFailedMessage = ""
        root.logAction("catalog_payload_received", {
            "origin": origin || "unknown",
            "rawLength": raw.length
        })
        root.parseCatalog(raw)
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
            visibleLoaderVersionModel.clear()

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
            root.catalogRevision += 1

            root.logAction("catalog_models_rebuilt", {
                "revision": root.catalogRevision,
                "allCount": allVersionsModel.count,
                "visibleCount": visibleVersionModel.count,
                "filter": root.versionFilter,
                "searchLength": root.searchText.length
            })

            if (visibleVersionModel.count > 0) {
                root.selectVersion(0)
            }

            root.installerPaneOpen = false
            root.loaderVersionPaneOpen = false
            root.loaderVersionKind = ""
        } catch (e) {
            root.catalogLoadFailed = true
            root.catalogFailedMessage = "解析版本数据失败，点击重试"
            root.logAction("catalog_parse_failed", {
                "error": String(e),
                "rawLength": raw ? raw.length : 0
            })
            console.log("Failed to parse download catalog", e)
        }
    }

    function rebuildVisibleVersions() {
        visibleVersionModel.clear()

        var rawQuery = root.searchText || ""
        var lowerQuery = rawQuery.toLowerCase()
        var regex = null
        if (rawQuery.indexOf("regex:") === 0) {
            try {
                regex = new RegExp(rawQuery.substring(6))
            } catch (e) {
                // HMCL keeps the category-filtered list when the expression is illegal.
                root.logAction("version_search_regex_invalid", {"error": String(e)})
                regex = null
                lowerQuery = ""
            }
        }

        for (var i = 0; i < allVersionsModel.count; i++) {
            var item = allVersionsModel.get(i)

            if (root.versionFilter !== "all" && item.group !== root.versionFilter) {
                continue
            }

            var versionText = String(item.versionId)
            if (regex && !regex.test(versionText)) {
                continue
            }
            if (!regex && lowerQuery.length > 0
                    && versionText.toLowerCase().indexOf(lowerQuery) < 0) {
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

        root.logAction("visible_versions_rebuilt", {
            "allCount": allVersionsModel.count,
            "visibleCount": visibleVersionModel.count,
            "filter": root.versionFilter,
            "searchLength": rawQuery.length,
            "regex": regex !== null
        })
    }

    function openInstallerForVersion(visibleIndex) {
        root.selectVersion(visibleIndex)

        if (root.selectedGameVersion.length === 0) {
            root.logAction("installer_page_open_rejected", {
                "visibleIndex": visibleIndex,
                "visibleCount": visibleVersionModel.count
            })
            return
        }

        root.loaderVersionPaneOpen = false
        root.loaderVersionKind = ""
        root.installVersionName = root.selectedGameVersion
        root.installNameModifiedByUser = false
        root.selectedLoaderKind = "vanilla"
        root.selectedFabricVersion = ""
        root.selectedQuiltVersion = ""
        root.selectedForgeVersion = ""
        root.selectedNeoForgeVersion = ""
        root.installerPaneOpen = true

        root.logAction("installer_page_open_requested", {
            "visibleIndex": visibleIndex,
            "gameVersion": root.selectedGameVersion,
            "releaseTime": root.selectedGameReleaseTime
        })
    }

    function closeInstallerPane() {
        root.installerPaneOpen = false
        root.loaderVersionPaneOpen = false
        root.loaderVersionKind = ""
    }

    function closeLoaderVersionPane() {
        root.loaderVersionPaneOpen = false
        root.loaderVersionKind = ""
    }

    function selectInstaller(kind) {
        if (kind === "vanilla") {
            root.selectedLoaderKind = "vanilla"
            root.selectedFabricVersion = ""
            root.selectedQuiltVersion = ""
            root.selectedForgeVersion = ""
            root.selectedNeoForgeVersion = ""
            if (!root.installNameModifiedByUser)
                root.installVersionName = root.selectedGameVersion
            return
        }

        root.startFetchLoaderMetadata(kind)
    }

    function chooseLoaderVersion(kind, index) {
        var version = ""

        if (kind === "fabric" && index >= 0 && index < fabricLoaderModel.count) {
            version = fabricLoaderModel.get(index).version || ""
            root.selectedFabricVersion = version
        } else if (kind === "quilt" && index >= 0 && index < quiltLoaderModel.count) {
            version = quiltLoaderModel.get(index).version || ""
            root.selectedQuiltVersion = version
        } else if (kind === "forge" && index >= 0 && index < forgeInstallerModel.count) {
            version = forgeInstallerModel.get(index).loaderVersion || ""
            root.selectedForgeVersion = version
        } else if (kind === "neoforge" && index >= 0 && index < neoforgeInstallerModel.count) {
            version = neoforgeInstallerModel.get(index).loaderVersion || ""
            root.selectedNeoForgeVersion = version
        }

        if (version.length === 0) {
            return
        }

        root.clearOtherLoaderSelections(kind)
        root.selectedLoaderKind = kind
        if (!root.installNameModifiedByUser)
            root.installVersionName = root.buildInstallVersionName()
        root.closeLoaderVersionPane()
    }

    function clearOtherLoaderSelections(kind) {
        if (kind !== "fabric") {
            root.selectedFabricVersion = ""
        }
        if (kind !== "quilt") {
            root.selectedQuiltVersion = ""
        }
        if (kind !== "forge") {
            root.selectedForgeVersion = ""
        }
        if (kind !== "neoforge") {
            root.selectedNeoForgeVersion = ""
        }
    }

    function firstInstallerVersion(kind) {
        if (kind === "fabric" && fabricLoaderModel.count > 0) {
            return fabricLoaderModel.get(0).version || ""
        }

        if (kind === "quilt" && quiltLoaderModel.count > 0) {
            return quiltLoaderModel.get(0).version || ""
        }

        if (kind === "forge" && forgeInstallerModel.count > 0) {
            return forgeInstallerModel.get(0).loaderVersion || ""
        }

        if (kind === "neoforge" && neoforgeInstallerModel.count > 0) {
            return neoforgeInstallerModel.get(0).loaderVersion || ""
        }

        return ""
    }

    function loaderModelCount(kind) {
        if (kind === "fabric") {
            return fabricLoaderModel.count
        }
        if (kind === "quilt") {
            return quiltLoaderModel.count
        }
        if (kind === "forge") {
            return forgeInstallerModel.count
        }
        if (kind === "neoforge") {
            return neoforgeInstallerModel.count
        }
        return 0
    }

    function loaderVersionValueAt(kind, index) {
        if (index < 0) {
            return ""
        }
        if (kind === "fabric" && index < fabricLoaderModel.count) {
            return fabricLoaderModel.get(index).version || ""
        }
        if (kind === "quilt" && index < quiltLoaderModel.count) {
            return quiltLoaderModel.get(index).version || ""
        }
        if (kind === "forge" && index < forgeInstallerModel.count) {
            return forgeInstallerModel.get(index).loaderVersion || ""
        }
        if (kind === "neoforge" && index < neoforgeInstallerModel.count) {
            return neoforgeInstallerModel.get(index).loaderVersion || ""
        }
        return ""
    }

    function loaderSubtitleAt(kind, index) {
        if (kind === "fabric" && index < fabricLoaderModel.count) {
            return fabricLoaderModel.get(index).stable ? "稳定版" : "实验版"
        }
        if (kind === "quilt" && index < quiltLoaderModel.count) {
            return quiltLoaderModel.get(index).stable ? "稳定版" : "实验版"
        }
        if (kind === "forge" && index < forgeInstallerModel.count) {
            return forgeInstallerModel.get(index).releaseTime || "Forge installer"
        }
        if (kind === "neoforge" && index < neoforgeInstallerModel.count) {
            return neoforgeInstallerModel.get(index).releaseTime || "NeoForge installer"
        }
        return ""
    }

    function rebuildVisibleLoaderVersions() {
        visibleLoaderVersionModel.clear()

        var kind = root.loaderVersionKind
        var query = root.loaderSearchText.toLowerCase()
        var count = root.loaderModelCount(kind)

        for (var i = 0; i < count; i++) {
            var version = root.loaderVersionValueAt(kind, i)
            if (version.length === 0) {
                continue
            }
            if (query.length > 0 && version.toLowerCase().indexOf(query) < 0) {
                continue
            }

            visibleLoaderVersionModel.append({
                "sourceIndex": i,
                "version": version,
                "subtitle": root.loaderSubtitleAt(kind, i)
            })
        }
    }

    function selectVisibleLoaderVersion(visibleIndex) {
        if (visibleIndex < 0 || visibleIndex >= visibleLoaderVersionModel.count) {
            return
        }

        var item = visibleLoaderVersionModel.get(visibleIndex)
        root.chooseLoaderVersion(root.loaderVersionKind, item.sourceIndex)
    }

    function setSelectedLoaderVersionFromIndex(kind, index) {
        if (index < 0) {
            return
        }

        if (kind === "fabric" && index < fabricLoaderModel.count) {
            root.selectedFabricVersion = fabricLoaderModel.get(index).version || ""
        } else if (kind === "quilt" && index < quiltLoaderModel.count) {
            root.selectedQuiltVersion = quiltLoaderModel.get(index).version || ""
        } else if (kind === "forge" && index < forgeInstallerModel.count) {
            root.selectedForgeVersion = forgeInstallerModel.get(index).loaderVersion || ""
        } else if (kind === "neoforge" && index < neoforgeInstallerModel.count) {
            root.selectedNeoForgeVersion = neoforgeInstallerModel.get(index).loaderVersion || ""
        }

        root.installVersionName = root.buildInstallVersionName()
    }

    function buildInstallVersionName() {
        if (root.selectedLoaderKind === "vanilla") {
            return root.selectedGameVersion
        }

        return root.selectedGameVersion + "-" + root.loaderTitle(root.selectedLoaderKind)
    }

    function loaderTitle(kind) {
        switch (kind) {
        case "fabric":
            return "Fabric"
        case "quilt":
            return "Quilt"
        case "forge":
            return "Forge"
        case "neoforge":
            return "NeoForge"
        case "fabric-api":
            return "Fabric API"
        case "quilt-api":
            return "Quilt API"
        case "optifine":
            return "OptiFine"
        default:
            return "Minecraft"
        }
    }

    function loaderIcon(kind) {
        switch (kind) {
        case "fabric":
        case "fabric-api":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/fabric.png"
        case "quilt":
        case "quilt-api":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/quilt.png"
        case "forge":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/forge.png"
        case "neoforge":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/neoforge.png"
        case "optifine":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/optifine.png"
        default:
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/grass.png"
        }
    }

    function installerCardWidth(containerWidth) {
        return 180
    }

    function installerStatus(kind) {
        if (kind === "vanilla") {
            return "版本 " + root.selectedGameVersion
        }

        if (kind === "fabric") {
            return root.selectedFabricVersion.length > 0 ? "版本 " + root.selectedFabricVersion : "不安装"
        }

        if (kind === "quilt") {
            return root.selectedQuiltVersion.length > 0 ? "版本 " + root.selectedQuiltVersion : "不安装"
        }

        if (kind === "forge") {
            return root.selectedForgeVersion.length > 0 ? "版本 " + root.selectedForgeVersion : "不安装"
        }

        if (kind === "neoforge") {
            return root.selectedNeoForgeVersion.length > 0 ? "版本 " + root.selectedNeoForgeVersion : "不安装"
        }

        if (kind === "fabric-api" || kind === "quilt-api" || kind === "optifine") {
            return "后续安装器扩展"
        }

        return "不安装"
    }

    function installerSelected(kind) {
        if (kind === "vanilla") {
            return true
        }

        return root.selectedLoaderKind === kind
    }

    function removeInstaller(kind) {
        if (root.selectedLoaderKind === kind) {
            root.selectedLoaderKind = "vanilla"
            root.selectedFabricVersion = ""
            root.selectedQuiltVersion = ""
            root.selectedForgeVersion = ""
            root.selectedNeoForgeVersion = ""
            if (!root.installNameModifiedByUser)
                root.installVersionName = root.selectedGameVersion
        }
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


    function isValidVersionName(name) {
        if (!name || name.length === 0 || name === "." || name === ".." || name === "~")
            return false
        // HMCLGameRepository.isValidVersionId -> FileUtils.isNameValidForJar.
        // Linux 下允许中文和空格，但禁止 JAR/路径危险字符。
        return !/[!\u0000-\u001F\u007F-\u009F\/:\uFFFD\uFFFE\uFFFF]/.test(name)
    }

    function installSelected() {
        if (root.selectedGameVersion.length === 0) {
            root.backend.output = "请选择 Minecraft 版本。"
            return
        }

        var instanceName = String(root.installVersionName || "")
        if (!root.isValidVersionName(instanceName)) {
            root.backend.output = "版本名称无效：不能为空，不能是 .、..、~，并且不能包含 !、/、: 或控制字符。"
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
            instanceName,
            root.selectedLoaderKind,
            loaderVersion
        )

        root.pollDownloadTask()
    }

    function selectedLoaderVersion() {
        switch (root.selectedLoaderKind) {
        case "fabric":
            return root.selectedFabricVersion
        case "quilt":
            return root.selectedQuiltVersion
        case "forge":
            return root.selectedForgeVersion
        case "neoforge":
            return root.selectedNeoForgeVersion
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

}
