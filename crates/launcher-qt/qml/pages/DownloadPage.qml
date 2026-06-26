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

    property string installVersionName: ""
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

    ListModel {
        id: allVersionsModel
    }
    ListModel {
        id: visibleVersionModel
    }

    ListModel {
        id: fabricLoaderModel
    }
    ListModel {
        id: quiltLoaderModel
    }
    ListModel {
        id: forgeInstallerModel
    }
    ListModel {
        id: neoforgeInstallerModel
    }
    ListModel {
        id: visibleLoaderVersionModel
    }

    Component.onCompleted: {
        root.startRefreshCatalog();
    }

    Timer {
        id: catalogTaskPoller
        interval: 250
        repeat: true
        running: true
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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: root.showDownloadSidebar() ? 200 : 0
            Layout.fillHeight: true
            visible: root.showDownloadSidebar()
            color: "transparent"
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                HmclClassTitle {
                    width: parent.width
                    text: "游戏"
                }

                DownloadNavItem {
                    width: parent.width
                    style: root.style
                    iconSource: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/grass.png"
                    title: "游戏"
                    subtitle: "Minecraft"
                    selected: root.currentTab === "game"
                    onClicked: root.currentTab = "game"
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

                HmclClassTitle {
                    width: parent.width
                    text: "内容"
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
                    height: 4
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.style.cBorder
                }

                Text {
                    width: parent.width
                    text: root.catalog ? "最新正式版 " + root.catalog.latestRelease + "\n最新快照 " + root.catalog.latestSnapshot : ""
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
                message: ""
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
                    root.downloadDialogOpen = false;
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
                root.downloadCancelDismissed = true;
                root.downloadDialogOpen = false;
                root.backend.cancelDownloadTask();
            }

            onCloseRequested: root.downloadDialogOpen = false
        }
    }

    function showDownloadSidebar() {
        return !root.installerPaneOpen && !root.loaderVersionPaneOpen;
    }

    function handleBack() {
        if (root.loaderVersionPaneOpen) {
            root.loaderVersionPaneOpen = false;
            root.installerPaneOpen = false;
            root.loaderVersionKind = "";
            visibleLoaderVersionModel.clear();
            return true;
        }

        if (root.installerPaneOpen) {
            root.closeInstallerPane();
            return true;
        }

        return false;
    }

    function startRefreshCatalog() {
        allVersionsModel.clear();
        visibleVersionModel.clear();
        fabricLoaderModel.clear();
        quiltLoaderModel.clear();
        forgeInstallerModel.clear();
        neoforgeInstallerModel.clear();
        visibleLoaderVersionModel.clear();

        root.selectedGameVersion = "";
        root.selectedGameReleaseTime = "";
        root.loadedCatalogJson = "";
        root.loadedLoaderMetadataJson = "";
        root.catalog = null;
        root.allForgeInstallers = [];
        root.allNeoForgeInstallers = [];
        root.loaderVersionPaneOpen = false;
        root.loaderVersionKind = "";

        root.catalogTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在获取版本列表",
            "message": "正在连接 Minecraft 版本源。",
            "catalogReady": false,
            "catalogJson": ""
        };

        root.backend.startRefreshDownloadCatalog(root.downloadSource);
        root.pollDownloadCatalogTask();
    }

    function pollDownloadCatalogTask() {
        var raw = root.backend.pollDownloadCatalogTask();

        if (!raw || raw.length === 0) {
            return;
        }

        try {
            var status = JSON.parse(raw);
            root.catalogTaskStatus = status;

            if (status.catalogReady && status.catalogJson && status.catalogJson.length > 0 && status.catalogJson !== root.loadedCatalogJson) {
                root.loadedCatalogJson = status.catalogJson;
                root.parseCatalog(status.catalogJson);
            }
        } catch (e) {
            console.log("Failed to parse download catalog task status", e);
        }
    }

    function startFetchInstallerMetadata() {
        if (root.selectedGameVersion.length === 0) {
            return;
        }

        fabricLoaderModel.clear();
        quiltLoaderModel.clear();
        forgeInstallerModel.clear();
        neoforgeInstallerModel.clear();
        root.allForgeInstallers = [];
        root.allNeoForgeInstallers = [];

        root.installerMetadataTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在加载安装器列表",
            "message": "Minecraft " + root.selectedGameVersion,
            "metadataReady": false,
            "metadataJson": ""
        };

        root.backend.startFetchInstallerMetadata(root.downloadSource, root.selectedGameVersion);
        installerMetadataPoller.restart();
    }

    function startFetchLoaderMetadata(kind) {
        if (root.selectedGameVersion.length === 0 || kind.length === 0) {
            return;
        }

        visibleLoaderVersionModel.clear();
        root.loaderSearchText = "";

        if (kind === "fabric") {
            fabricLoaderModel.clear();
            root.selectedFabricVersion = "";
        } else if (kind === "quilt") {
            quiltLoaderModel.clear();
            root.selectedQuiltVersion = "";
        } else if (kind === "forge") {
            forgeInstallerModel.clear();
            root.selectedForgeVersion = "";
        } else if (kind === "neoforge") {
            neoforgeInstallerModel.clear();
            root.selectedNeoForgeVersion = "";
        }

        root.loadedLoaderMetadataJson = "";
        root.loaderVersionKind = kind;
        root.loaderVersionPaneOpen = true;

        root.installerMetadataTaskStatus = {
            "active": true,
            "percent": 5,
            "title": "正在加载 " + root.loaderTitle(kind) + " 版本",
            "message": "Minecraft " + root.selectedGameVersion,
            "metadataReady": false,
            "metadataJson": ""
        };

        root.backend.startFetchLoaderMetadata(root.downloadSource, root.selectedGameVersion, kind);
        installerMetadataPoller.restart();
    }

    function pollInstallerMetadataTask() {
        var raw = root.backend.pollInstallerMetadataTask();

        if (!raw || raw.length === 0) {
            return;
        }

        try {
            var status = JSON.parse(raw);
            root.installerMetadataTaskStatus = status;

            if (!status.active && status.metadataReady) {
                installerMetadataPoller.stop();

                if (status.metadataJson && status.metadataJson.length > 0 && status.metadataJson !== root.loadedLoaderMetadataJson) {
                    root.loadedLoaderMetadataJson = status.metadataJson;
                    root.parseInstallerMetadata(status.metadataJson);
                }
            }
        } catch (e) {
            console.log("Failed to parse installer metadata task", e);
        }
    }

    function parseInstallerMetadata(raw) {
        try {
            var data = JSON.parse(raw);
            var kind = data.loaderKind || root.loaderVersionKind;

            if (!kind || kind === "fabric") {
                fabricLoaderModel.clear();
            }
            if (!kind || kind === "quilt") {
                quiltLoaderModel.clear();
            }
            if (!kind || kind === "forge") {
                forgeInstallerModel.clear();
            }
            if (!kind || kind === "neoforge") {
                neoforgeInstallerModel.clear();
            }

            var fabric = data.fabricLoaders || [];
            for (var f = 0; f < fabric.length; f++) {
                fabricLoaderModel.append({
                    "version": fabric[f].version || "",
                    "stable": !!fabric[f].stable
                });
            }

            var quilt = data.quiltLoaders || [];
            for (var q = 0; q < quilt.length; q++) {
                quiltLoaderModel.append({
                    "version": quilt[q].version || "",
                    "stable": !!quilt[q].stable
                });
            }

            var forge = data.forgeInstallers || [];
            for (var i = 0; i < forge.length; i++) {
                forgeInstallerModel.append({
                    "loaderVersion": forge[i].loaderVersion || "",
                    "gameVersion": forge[i].gameVersion || root.selectedGameVersion,
                    "releaseTime": forge[i].releaseTime || ""
                });
            }

            var neo = data.neoforgeInstallers || [];
            for (var n = 0; n < neo.length; n++) {
                neoforgeInstallerModel.append({
                    "loaderVersion": neo[n].loaderVersion || "",
                    "gameVersion": neo[n].gameVersion || root.selectedGameVersion,
                    "releaseTime": neo[n].releaseTime || ""
                });
            }

            root.rebuildVisibleLoaderVersions();
        } catch (e) {
            console.log("Failed to parse installer metadata", e);
        }
    }

    function pollDownloadTask() {
        var raw = root.backend.pollDownloadTask();

        if (!raw || raw.length === 0) {
            return;
        }

        try {
            root.downloadTaskStatus = JSON.parse(raw);

            if (root.downloadTaskStatus.active && root.downloadTaskStatus.status !== "cancelling" && root.downloadTaskStatus.status !== "cancelled" && !root.downloadCancelDismissed) {
                root.downloadDialogOpen = true;
            }

            if (root.downloadTaskStatus.status === "finished" && !root.downloadFinishHandled) {
                root.downloadFinishHandled = true;
                root.backend.refreshInstalledVersions();
            }

            if (!root.downloadTaskStatus.active) {
                root.downloadCancelDismissed = false;
            }
        } catch (e) {
            console.log("Failed to parse download task status", e);
        }
    }

    function parseCatalog(raw) {
        try {
            var data = JSON.parse(raw);
            root.catalog = data;

            allVersionsModel.clear();
            fabricLoaderModel.clear();
            quiltLoaderModel.clear();
            forgeInstallerModel.clear();
            neoforgeInstallerModel.clear();
            visibleLoaderVersionModel.clear();

            var versions = data.gameVersions || [];
            for (var i = 0; i < versions.length; i++) {
                var item = versions[i];
                var group = root.groupForVersion(item.id || "", item.versionType || "");
                allVersionsModel.append({
                    "versionId": item.id || "",
                    "versionType": item.versionType || "",
                    "releaseTime": item.releaseTime || "",
                    "group": group,
                    "iconSource": root.iconForVersionGroup(group),
                    "tagText": root.tagForVersionGroup(group)
                });
            }

            var fabric = data.fabricLoaders || [];
            for (var f = 0; f < fabric.length; f++) {
                fabricLoaderModel.append({
                    "version": fabric[f].version || "",
                    "stable": !!fabric[f].stable
                });
            }

            var quilt = data.quiltLoaders || [];
            for (var q = 0; q < quilt.length; q++) {
                quiltLoaderModel.append({
                    "version": quilt[q].version || "",
                    "stable": !!quilt[q].stable
                });
            }

            root.allForgeInstallers = data.forgeInstallers || [];
            root.allNeoForgeInstallers = data.neoforgeInstallers || [];

            root.rebuildVisibleVersions();

            if (visibleVersionModel.count > 0) {
                root.selectVersion(0);
            }

            root.installerPaneOpen = false;
            root.loaderVersionPaneOpen = false;
            root.loaderVersionKind = "";
        } catch (e) {
            console.log("Failed to parse download catalog", e);
        }
    }

    function rebuildVisibleVersions() {
        visibleVersionModel.clear();

        var query = root.searchText.toLowerCase();

        for (var i = 0; i < allVersionsModel.count; i++) {
            var item = allVersionsModel.get(i);

            if (root.versionFilter !== "all" && item.group !== root.versionFilter) {
                continue;
            }

            if (query.length > 0 && String(item.versionId).toLowerCase().indexOf(query) < 0) {
                continue;
            }

            visibleVersionModel.append({
                "sourceIndex": i,
                "versionId": item.versionId,
                "versionType": item.versionType,
                "releaseTime": item.releaseTime,
                "group": item.group,
                "iconSource": item.iconSource,
                "tagText": item.tagText
            });
        }
    }

    function openInstallerForVersion(visibleIndex) {
        root.selectVersion(visibleIndex);

        root.installerPaneOpen = true;
        root.loaderVersionPaneOpen = false;
        root.loaderVersionKind = "";
        root.installVersionName = root.selectedGameVersion;
        root.selectedLoaderKind = "vanilla";
        root.selectedFabricVersion = "";
        root.selectedQuiltVersion = "";
        root.selectedForgeVersion = "";
        root.selectedNeoForgeVersion = "";
    }

    function closeInstallerPane() {
        root.installerPaneOpen = false;
        root.loaderVersionPaneOpen = false;
        root.loaderVersionKind = "";
    }

    function closeLoaderVersionPane() {
        root.loaderVersionPaneOpen = false;
        root.loaderVersionKind = "";
    }

    function selectInstaller(kind) {
        if (kind === "vanilla") {
            root.selectedLoaderKind = "vanilla";
            root.selectedFabricVersion = "";
            root.selectedQuiltVersion = "";
            root.selectedForgeVersion = "";
            root.selectedNeoForgeVersion = "";
            root.installVersionName = root.selectedGameVersion;
            return;
        }

        root.startFetchLoaderMetadata(kind);
    }

    function chooseLoaderVersion(kind, index) {
        var version = "";

        if (kind === "fabric" && index >= 0 && index < fabricLoaderModel.count) {
            version = fabricLoaderModel.get(index).version || "";
            root.selectedFabricVersion = version;
        } else if (kind === "quilt" && index >= 0 && index < quiltLoaderModel.count) {
            version = quiltLoaderModel.get(index).version || "";
            root.selectedQuiltVersion = version;
        } else if (kind === "forge" && index >= 0 && index < forgeInstallerModel.count) {
            version = forgeInstallerModel.get(index).loaderVersion || "";
            root.selectedForgeVersion = version;
        } else if (kind === "neoforge" && index >= 0 && index < neoforgeInstallerModel.count) {
            version = neoforgeInstallerModel.get(index).loaderVersion || "";
            root.selectedNeoForgeVersion = version;
        }

        if (version.length === 0) {
            return;
        }

        root.clearOtherLoaderSelections(kind);
        root.selectedLoaderKind = kind;
        root.installVersionName = root.buildInstallVersionName();
        root.closeLoaderVersionPane();
    }

    function clearOtherLoaderSelections(kind) {
        if (kind !== "fabric") {
            root.selectedFabricVersion = "";
        }
        if (kind !== "quilt") {
            root.selectedQuiltVersion = "";
        }
        if (kind !== "forge") {
            root.selectedForgeVersion = "";
        }
        if (kind !== "neoforge") {
            root.selectedNeoForgeVersion = "";
        }
    }

    function firstInstallerVersion(kind) {
        if (kind === "fabric" && fabricLoaderModel.count > 0) {
            return fabricLoaderModel.get(0).version || "";
        }

        if (kind === "quilt" && quiltLoaderModel.count > 0) {
            return quiltLoaderModel.get(0).version || "";
        }

        if (kind === "forge" && forgeInstallerModel.count > 0) {
            return forgeInstallerModel.get(0).loaderVersion || "";
        }

        if (kind === "neoforge" && neoforgeInstallerModel.count > 0) {
            return neoforgeInstallerModel.get(0).loaderVersion || "";
        }

        return "";
    }

    function loaderModelCount(kind) {
        if (kind === "fabric") {
            return fabricLoaderModel.count;
        }
        if (kind === "quilt") {
            return quiltLoaderModel.count;
        }
        if (kind === "forge") {
            return forgeInstallerModel.count;
        }
        if (kind === "neoforge") {
            return neoforgeInstallerModel.count;
        }
        return 0;
    }

    function loaderVersionValueAt(kind, index) {
        if (index < 0) {
            return "";
        }
        if (kind === "fabric" && index < fabricLoaderModel.count) {
            return fabricLoaderModel.get(index).version || "";
        }
        if (kind === "quilt" && index < quiltLoaderModel.count) {
            return quiltLoaderModel.get(index).version || "";
        }
        if (kind === "forge" && index < forgeInstallerModel.count) {
            return forgeInstallerModel.get(index).loaderVersion || "";
        }
        if (kind === "neoforge" && index < neoforgeInstallerModel.count) {
            return neoforgeInstallerModel.get(index).loaderVersion || "";
        }
        return "";
    }

    function loaderSubtitleAt(kind, index) {
        if (kind === "fabric" && index < fabricLoaderModel.count) {
            return fabricLoaderModel.get(index).stable ? "稳定版" : "实验版";
        }
        if (kind === "quilt" && index < quiltLoaderModel.count) {
            return quiltLoaderModel.get(index).stable ? "稳定版" : "实验版";
        }
        if (kind === "forge" && index < forgeInstallerModel.count) {
            return forgeInstallerModel.get(index).releaseTime || "Forge installer";
        }
        if (kind === "neoforge" && index < neoforgeInstallerModel.count) {
            return neoforgeInstallerModel.get(index).releaseTime || "NeoForge installer";
        }
        return "";
    }

    function rebuildVisibleLoaderVersions() {
        visibleLoaderVersionModel.clear();

        var kind = root.loaderVersionKind;
        var query = root.loaderSearchText.toLowerCase();
        var count = root.loaderModelCount(kind);

        for (var i = 0; i < count; i++) {
            var version = root.loaderVersionValueAt(kind, i);
            if (version.length === 0) {
                continue;
            }
            if (query.length > 0 && version.toLowerCase().indexOf(query) < 0) {
                continue;
            }

            visibleLoaderVersionModel.append({
                "sourceIndex": i,
                "version": version,
                "subtitle": root.loaderSubtitleAt(kind, i)
            });
        }
    }

    function selectVisibleLoaderVersion(visibleIndex) {
        if (visibleIndex < 0 || visibleIndex >= visibleLoaderVersionModel.count) {
            return;
        }

        var item = visibleLoaderVersionModel.get(visibleIndex);
        root.chooseLoaderVersion(root.loaderVersionKind, item.sourceIndex);
    }

    function setSelectedLoaderVersionFromIndex(kind, index) {
        if (index < 0) {
            return;
        }

        if (kind === "fabric" && index < fabricLoaderModel.count) {
            root.selectedFabricVersion = fabricLoaderModel.get(index).version || "";
        } else if (kind === "quilt" && index < quiltLoaderModel.count) {
            root.selectedQuiltVersion = quiltLoaderModel.get(index).version || "";
        } else if (kind === "forge" && index < forgeInstallerModel.count) {
            root.selectedForgeVersion = forgeInstallerModel.get(index).loaderVersion || "";
        } else if (kind === "neoforge" && index < neoforgeInstallerModel.count) {
            root.selectedNeoForgeVersion = neoforgeInstallerModel.get(index).loaderVersion || "";
        }

        root.installVersionName = root.buildInstallVersionName();
    }

    function buildInstallVersionName() {
        if (root.selectedLoaderKind === "vanilla") {
            return root.selectedGameVersion;
        }

        return root.selectedGameVersion + "-" + root.loaderTitle(root.selectedLoaderKind);
    }

    function loaderTitle(kind) {
        switch (kind) {
        case "fabric":
            return "Fabric";
        case "quilt":
            return "Quilt";
        case "forge":
            return "Forge";
        case "neoforge":
            return "NeoForge";
        case "fabric-api":
            return "Fabric API";
        case "quilt-api":
            return "Quilt API";
        case "optifine":
            return "OptiFine";
        default:
            return "Minecraft";
        }
    }

    function loaderIcon(kind) {
        switch (kind) {
        case "fabric":
        case "fabric-api":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/fabric.png";
        case "quilt":
        case "quilt-api":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/quilt.png";
        case "forge":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/forge.png";
        case "neoforge":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/neoforge.png";
        case "optifine":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/optifine.png";
        default:
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/grass.png";
        }
    }

    function installerCardWidth(containerWidth) {
        return 180;
    }

    function installerStatus(kind) {
        if (kind === "vanilla") {
            return "版本 " + root.selectedGameVersion;
        }

        if (kind === "fabric") {
            return root.selectedFabricVersion.length > 0 ? "版本 " + root.selectedFabricVersion : "不安装";
        }

        if (kind === "quilt") {
            return root.selectedQuiltVersion.length > 0 ? "版本 " + root.selectedQuiltVersion : "不安装";
        }

        if (kind === "forge") {
            return root.selectedForgeVersion.length > 0 ? "版本 " + root.selectedForgeVersion : "不安装";
        }

        if (kind === "neoforge") {
            return root.selectedNeoForgeVersion.length > 0 ? "版本 " + root.selectedNeoForgeVersion : "不安装";
        }

        if (kind === "fabric-api" || kind === "quilt-api" || kind === "optifine") {
            return "后续安装器扩展";
        }

        return "不安装";
    }

    function installerSelected(kind) {
        if (kind === "vanilla") {
            return true;
        }

        return root.selectedLoaderKind === kind;
    }

    function removeInstaller(kind) {
        if (root.selectedLoaderKind === kind) {
            root.selectedLoaderKind = "vanilla";
            root.selectedFabricVersion = "";
            root.selectedQuiltVersion = "";
            root.selectedForgeVersion = "";
            root.selectedNeoForgeVersion = "";
            root.installVersionName = root.selectedGameVersion;
        }
    }

    function selectVersion(visibleIndex) {
        if (visibleIndex < 0 || visibleIndex >= visibleVersionModel.count) {
            return;
        }

        var item = visibleVersionModel.get(visibleIndex);
        root.selectedGameVersion = item.versionId;
        root.selectedGameReleaseTime = item.releaseTime;
        root.rebuildLoaderModels();
    }

    function rebuildLoaderModels() {
        forgeInstallerModel.clear();
        neoforgeInstallerModel.clear();

        for (var i = 0; i < root.allForgeInstallers.length; i++) {
            var forge = root.allForgeInstallers[i];
            if (forge.gameVersion === root.selectedGameVersion) {
                forgeInstallerModel.append({
                    "loaderVersion": forge.loaderVersion || "",
                    "gameVersion": forge.gameVersion || "",
                    "releaseTime": forge.releaseTime || ""
                });
            }
        }

        for (var n = 0; n < root.allNeoForgeInstallers.length; n++) {
            var neo = root.allNeoForgeInstallers[n];
            if (neo.gameVersion === root.selectedGameVersion) {
                neoforgeInstallerModel.append({
                    "loaderVersion": neo.loaderVersion || "",
                    "gameVersion": neo.gameVersion || "",
                    "releaseTime": neo.releaseTime || ""
                });
            }
        }
    }

    function installSelected() {
        if (root.selectedGameVersion.length === 0) {
            root.backend.output = "请选择 Minecraft 版本。";
            return;
        }

        var loaderVersion = root.selectedLoaderVersion();

        if (root.selectedLoaderKind !== "vanilla" && loaderVersion.length === 0) {
            root.backend.output = "请选择加载器版本。";
            return;
        }

        root.downloadFinishHandled = false;
        root.downloadCancelDismissed = false;
        root.downloadDialogOpen = true;

        root.backend.installGameVersion(root.downloadSource, root.selectedGameVersion, root.selectedLoaderKind, loaderVersion);

        root.pollDownloadTask();
    }

    function selectedLoaderVersion() {
        switch (root.selectedLoaderKind) {
        case "fabric":
            return root.selectedFabricVersion;
        case "quilt":
            return root.selectedQuiltVersion;
        case "forge":
            return root.selectedForgeVersion;
        case "neoforge":
            return root.selectedNeoForgeVersion;
        default:
            return "";
        }
    }

    function groupForVersion(id, type) {
        if (root.isAprilFoolsVersion(id)) {
            return "april";
        }

        if (type === "release") {
            return "release";
        }

        if (type === "snapshot" || type === "pending" || type === "unobfuscated") {
            return "snapshot";
        }

        return "old";
    }

    function isAprilFoolsVersion(id) {
        return id === "20w14∞" || id === "3D Shareware v1.34" || id === "22w13oneBlockAtATime" || id === "23w13a_or_b" || id.indexOf("infinite") >= 0;
    }

    function iconForVersionGroup(group) {
        switch (group) {
        case "release":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/grass.png";
        case "snapshot":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/command.png";
        case "april":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/april_fools.png";
        default:
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/craft_table.png";
        }
    }

    function tagForVersionGroup(group) {
        switch (group) {
        case "release":
            return "正式版";
        case "snapshot":
            return "快照版";
        case "april":
            return "愚人节";
        default:
            return "远古版本";
        }
    }

    function placeholderTitle(tab) {
        switch (tab) {
        case "modpack":
            return "整合包";
        case "mod":
            return "Mod";
        case "resourcepack":
            return "资源包";
        case "shader":
            return "光影包";
        case "world":
            return "世界";
        default:
            return "下载内容";
        }
    }

    component GameDownloadPane: Item {
        Item {
            anchors.fill: parent
            clip: true

            VersionsPagePane {
                anchors.fill: parent
                visible: !root.installerPaneOpen && !root.loaderVersionPaneOpen
                opacity: visible ? 1 : 0
            }

            HmclInstallersPagePane {
                anchors.fill: parent
                visible: root.installerPaneOpen && !root.loaderVersionPaneOpen
                opacity: visible ? 1 : 0
            }

            LoaderVersionsPagePane {
                anchors.fill: parent
                visible: root.loaderVersionPaneOpen
                opacity: visible ? 1 : 0
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.style.animationsEnabled ? 120 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    component VersionsPagePane: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 4
                color: root.style.cSurfaceContainerHigh
                border.color: root.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: "名称"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 13
                    }

                    TextField {
                        id: searchField

                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "输入版本名称进行搜索"
                        text: root.searchText
                        onTextChanged: {
                            root.searchText = text;
                            root.rebuildVisibleVersions();
                        }
                    }

                    Text {
                        text: "版本类型"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 13
                    }

                    ComboBox {
                        id: versionFilterCombo
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 36
                        model: ["正式版", "快照版", "愚人节", "远古版本", "全部"]
                        currentIndex: 0

                        onCurrentIndexChanged: {
                            var values = ["release", "snapshot", "april", "old", "all"];
                            root.versionFilter = values[currentIndex];
                            root.rebuildVisibleVersions();
                        }
                    }

                    HmclButton {
                        Layout.preferredWidth: 72
                        style: root.style
                        text: "刷新"
                        primary: true
                        buttonEnabled: !root.catalogTaskStatus.active
                        onClicked: root.startRefreshCatalog()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                visible: false
            }

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
                    anchors.margins: 8
                    model: visibleVersionModel
                    spacing: 0
                    clip: true
                    visible: !root.catalogTaskStatus.active

                    delegate: Item {
                        id: versionDelegate

                        required property int index
                        required property string versionId
                        required property string versionType
                        required property string releaseTime
                        required property string group
                        required property string iconSource
                        required property string tagText

                        width: versionList.width
                        height: 64

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

                HmclSpinner {
                    anchors.centerIn: parent
                    width: 50
                    height: 50
                    style: root.style
                    visible: root.catalogTaskStatus.active
                    running: visible
                }

                Text {
                    anchors.centerIn: parent
                    visible: visibleVersionModel.count === 0 && !root.catalogTaskStatus.active
                    text: "没有匹配的版本"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                }
            }
        }
    }

    component LoaderVersionsPagePane: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 4
                color: root.style.cSurfaceContainerHigh
                border.color: root.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: root.loaderTitle(root.loaderVersionKind) + " 版本"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 13
                        font.bold: true
                    }

                    TextField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "输入版本名称进行搜索"
                        text: root.loaderSearchText
                        onTextChanged: {
                            root.loaderSearchText = text;
                            root.rebuildVisibleLoaderVersions();
                        }
                    }

                    HmclButton {
                        Layout.preferredWidth: 72
                        style: root.style
                        text: "返回"
                        onClicked: root.closeLoaderVersionPane()
                    }

                    HmclButton {
                        Layout.preferredWidth: 72
                        style: root.style
                        text: "刷新"
                        primary: true
                        buttonEnabled: !root.installerMetadataTaskStatus.active
                        onClicked: root.startFetchLoaderMetadata(root.loaderVersionKind)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                visible: false
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: root.style.cSurfaceContainerHigh
                border.color: root.style.cBorder
                border.width: 1
                clip: true

                ListView {
                    id: loaderVersionList

                    anchors.fill: parent
                    anchors.margins: 8
                    model: visibleLoaderVersionModel
                    spacing: 0
                    clip: true
                    visible: !root.installerMetadataTaskStatus.active

                    delegate: Item {
                        id: loaderVersionDelegate

                        required property int index
                        required property int sourceIndex
                        required property string version
                        required property string subtitle

                        width: loaderVersionList.width
                        height: 64

                        RemoteVersionCell {
                            anchors.fill: parent
                            style: root.style
                            versionId: loaderVersionDelegate.version
                            tagText: root.loaderTitle(root.loaderVersionKind)
                            iconSource: root.loaderIcon(root.loaderVersionKind)
                            subtitle: loaderVersionDelegate.subtitle
                            selected: root.selectedLoaderKind === root.loaderVersionKind && root.selectedLoaderVersion() === loaderVersionDelegate.version
                            onClicked: root.selectVisibleLoaderVersion(loaderVersionDelegate.index)
                        }
                    }
                }

                HmclSpinner {
                    anchors.centerIn: parent
                    width: 50
                    height: 50
                    style: root.style
                    visible: root.installerMetadataTaskStatus.active
                    running: visible
                }

                Text {
                    anchors.centerIn: parent
                    visible: visibleLoaderVersionModel.count === 0 && !root.installerMetadataTaskStatus.active
                    text: "没有匹配的 " + root.loaderTitle(root.loaderVersionKind) + " 版本"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                }
            }
        }
    }

    component HmclInstallersPagePane: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                radius: 4
                color: root.style.cSurfaceContainerHigh
                border.color: root.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "版本名称"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 13
                    }

                    TextField {
                        Layout.preferredWidth: 300
                        Layout.preferredHeight: 36
                        text: root.installVersionName
                        onTextChanged: root.installVersionName = text
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    HmclButton {
                        Layout.preferredWidth: 110
                        style: root.style
                        text: "返回版本列表"
                        onClicked: root.closeInstallerPane()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                visible: false
            }

            ScrollView {
                id: installerScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                contentWidth: availableWidth
                contentHeight: installerFlow.implicitHeight

                Flow {
                    id: installerFlow

                    width: installerScroll.availableWidth
                    flow: Flow.LeftToRight
                    spacing: 16

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "game"
                        title: "Minecraft"
                        statusText: root.installerStatus("vanilla")
                        iconSource: root.loaderIcon("vanilla")
                        selected: root.installerSelected("vanilla")
                        removable: false
                        onInstallClicked: root.selectInstaller("vanilla")
                    }

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "forge"
                        title: "Forge"
                        statusText: root.installerStatus("forge")
                        iconSource: root.loaderIcon("forge")
                        selected: root.installerSelected("forge")
                        removable: root.installerSelected("forge")
                        onInstallClicked: root.selectInstaller("forge")
                        onRemoveClicked: root.removeInstaller("forge")
                    }

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "neoforge"
                        title: "NeoForge"
                        statusText: root.installerStatus("neoforge")
                        iconSource: root.loaderIcon("neoforge")
                        selected: root.installerSelected("neoforge")
                        removable: root.installerSelected("neoforge")
                        onInstallClicked: root.selectInstaller("neoforge")
                        onRemoveClicked: root.removeInstaller("neoforge")
                    }

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "optifine"
                        title: "OptiFine"
                        statusText: root.installerStatus("optifine")
                        iconSource: root.loaderIcon("optifine")
                        disabledCard: true
                    }

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "fabric"
                        title: "Fabric"
                        statusText: root.installerStatus("fabric")
                        iconSource: root.loaderIcon("fabric")
                        selected: root.installerSelected("fabric")
                        removable: root.installerSelected("fabric")
                        onInstallClicked: root.selectInstaller("fabric")
                        onRemoveClicked: root.removeInstaller("fabric")
                    }

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "fabric-api"
                        title: "Fabric API"
                        statusText: root.installerStatus("fabric-api")
                        iconSource: root.loaderIcon("fabric-api")
                        disabledCard: true
                    }

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "quilt"
                        title: "Quilt"
                        statusText: root.installerStatus("quilt")
                        iconSource: root.loaderIcon("quilt")
                        selected: root.installerSelected("quilt")
                        removable: root.installerSelected("quilt")
                        onInstallClicked: root.selectInstaller("quilt")
                        onRemoveClicked: root.removeInstaller("quilt")
                    }

                    InstallerItemCard {
                        style: root.style
                        width: root.installerCardWidth(installerFlow.width)
                        libraryId: "quilt-api"
                        title: "Quilt API"
                        statusText: root.installerStatus("quilt-api")
                        iconSource: root.loaderIcon("quilt-api")
                        disabledCard: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                visible: false
                radius: 4
                color: root.style.cSurfaceContainerHigh
                border.color: root.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: root.loaderTitle(root.selectedLoaderKind) + " 版本"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 13
                        font.bold: true
                    }

                    ComboBox {
                        id: loaderVersionCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        model: root.selectedLoaderKind === "fabric" ? fabricLoaderModel : root.selectedLoaderKind === "quilt" ? quiltLoaderModel : root.selectedLoaderKind === "forge" ? forgeInstallerModel : root.selectedLoaderKind === "neoforge" ? neoforgeInstallerModel : null
                        textRole: root.selectedLoaderKind === "forge" || root.selectedLoaderKind === "neoforge" ? "loaderVersion" : "version"

                        onActivated: function (index) {
                            root.setSelectedLoaderVersionFromIndex(root.selectedLoaderKind, index);
                        }
                    }

                    Text {
                        Layout.preferredWidth: 128
                        text: root.selectedLoaderVersion().length > 0 ? "当前：" + root.selectedLoaderVersion() : "无可用版本"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                Item {
                    Layout.fillWidth: true
                }

                HmclButton {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40
                    style: root.style
                    text: root.downloadTaskStatus.active ? "查看任务" : "安装"
                    primary: true
                    onClicked: {
                        if (root.downloadTaskStatus.active) {
                            root.downloadDialogOpen = true;
                        } else {
                            root.installSelected();
                        }
                    }
                }
            }
        }
    }

    component InstallerItemCard: Item {
        id: card

        required property var style
        property string libraryId: ""
        property string title: ""
        property string statusText: ""
        property string iconSource: ""
        property bool selected: false
        property bool removable: false
        property bool disabledCard: false

        signal installClicked
        signal removeClicked

        height: width * 0.7
        opacity: disabledCard ? 0.52 : 1.0

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.topMargin: 2
            radius: 4
            color: Qt.rgba(0, 0, 0, card.style.darkMode ? 0.34 : 0.20)
            visible: !card.disabledCard
        }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: mouse.containsMouse && !card.disabledCard ? Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.06) : card.style.cSurface
            border.color: "transparent"
            border.width: 0
        }

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 3

            Image {
                width: 32
                height: 32
                anchors.horizontalCenter: parent.horizontalCenter
                source: card.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            Text {
                width: parent.width
                text: card.title
                color: card.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: card.statusText
                color: card.style.cTextOnSurfaceVariant
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    visible: card.removable
                    color: removeMouse.containsMouse ? Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.10) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: card.style.cTextOnSurface
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: removeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mouse.accepted = true;
                            card.removeClicked();
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    visible: !card.disabledCard
                    color: installMouse.containsMouse ? Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.10) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: card.selected ? "↻" : "➜"
                        color: card.style.cTextOnSurface
                        font.pixelSize: 17
                    }

                    MouseArea {
                        id: installMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mouse.accepted = true;
                            card.installClicked();
                        }
                    }
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !card.disabledCard
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: card.installClicked()
        }
    }

    component HmclSpinner: Item {
        id: spinner

        required property var style
        property bool running: true
        property real startAngle: 45
        property real arcLength: 5
        property real strokeWidth: 4

        implicitWidth: 50
        implicitHeight: 50

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width;
                var h = height;
                var sw = spinner.strokeWidth;
                var radius = Math.max(1, Math.min(w, h) / 2 - sw);
                var cx = w / 2;
                var cy = h / 2;
                var start = (spinner.startAngle - 90) * Math.PI / 180;
                var span = Math.max(1, spinner.arcLength) * Math.PI / 180;

                ctx.lineWidth = sw;
                ctx.lineCap = "round";
                ctx.strokeStyle = spinner.style.cPrimaryContainer;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, start, start + span, false);
                ctx.stroke();
            }
        }

        onStartAngleChanged: canvas.requestPaint()
        onArcLengthChanged: canvas.requestPaint()
        onVisibleChanged: canvas.requestPaint()
        onWidthChanged: canvas.requestPaint()
        onHeightChanged: canvas.requestPaint()

        SequentialAnimation {
            running: spinner.running && spinner.visible && spinner.style.animationsEnabled
            loops: Animation.Infinite

            ParallelAnimation {
                NumberAnimation {
                    target: spinner
                    property: "arcLength"
                    from: 5
                    to: 250
                    duration: 400
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: spinner
                    property: "startAngle"
                    from: 45
                    to: 90
                    duration: 400
                    easing.type: Easing.Linear
                }
            }
            PauseAnimation {
                duration: 300
            }
            ParallelAnimation {
                NumberAnimation {
                    target: spinner
                    property: "arcLength"
                    from: 250
                    to: 5
                    duration: 400
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: spinner
                    property: "startAngle"
                    from: 90
                    to: 435
                    duration: 400
                    easing.type: Easing.Linear
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: spinner
                    property: "arcLength"
                    from: 5
                    to: 250
                    duration: 400
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: spinner
                    property: "startAngle"
                    from: 495
                    to: 540
                    duration: 400
                    easing.type: Easing.Linear
                }
            }
            PauseAnimation {
                duration: 300
            }
            ParallelAnimation {
                NumberAnimation {
                    target: spinner
                    property: "arcLength"
                    from: 250
                    to: 5
                    duration: 400
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    target: spinner
                    property: "startAngle"
                    from: 540
                    to: 885
                    duration: 400
                    easing.type: Easing.Linear
                }
            }
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 5600
            loops: Animation.Infinite
            running: spinner.running && spinner.visible && !spinner.style.animationsEnabled
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

        signal clicked

        height: 48

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: item.selected ? Qt.rgba(item.style.cPrimary.r, item.style.cPrimary.g, item.style.cPrimary.b, 0.14) : (mouse.containsMouse ? Qt.rgba(item.style.cTextOnSurface.r, item.style.cTextOnSurface.g, item.style.cTextOnSurface.b, 0.06) : "transparent")
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

        signal clicked

        height: 56

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: cell.selected ? Qt.rgba(cell.style.cPrimary.r, cell.style.cPrimary.g, cell.style.cPrimary.b, 0.14) : (mouse.containsMouse ? Qt.rgba(cell.style.cTextOnSurface.r, cell.style.cTextOnSurface.g, cell.style.cTextOnSurface.b, 0.06) : "transparent")
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

        signal clicked

        width: label.implicitWidth + 24
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: chip.selected ? Qt.rgba(chip.style.cPrimary.r, chip.style.cPrimary.g, chip.style.cPrimary.b, 0.16) : (mouse.containsMouse ? Qt.rgba(chip.style.cTextOnSurface.r, chip.style.cTextOnSurface.g, chip.style.cTextOnSurface.b, 0.06) : chip.style.cSurfaceContainer)
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

        signal clicked

        implicitHeight: 36
        height: 36
        opacity: button.buttonEnabled ? 1.0 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: button.primary ? button.style.cPrimary : (mouse.containsMouse ? button.style.cButtonHover : button.style.cButtonSurface)
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

        signal cancelRequested
        signal closeRequested

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
                            card.cancelRequested();
                        } else {
                            card.closeRequested();
                        }
                    }
                }
            }
        }
    }
}
