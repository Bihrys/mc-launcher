import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    property string downloadSource: "official"
    property string selectedGameVersion: ""
    property string selectedLoaderKind: "vanilla"
    property var catalog: null

    ListModel { id: gameModel }
    ListModel { id: fabricLoaderModel }
    ListModel { id: quiltLoaderModel }
    ListModel { id: forgeInstallerModel }
    ListModel { id: neoforgeInstallerModel }

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
                    text: "按 HMCL 的结构移植：游戏版本列表 + 加载器版本 + 安装任务。"
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
                text: "刷新列表"
                primary: true
                onClicked: root.refreshCatalog()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 980
            Layout.preferredHeight: 430
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 265
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
                            text: "Minecraft 版本"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            text: root.catalog
                                  ? "Release: " + root.catalog.latestRelease + " / Snapshot: " + root.catalog.latestSnapshot
                                  : "点击刷新列表"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        ListView {
                            id: gameList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: gameModel

                            delegate: Rectangle {
                                width: gameList.width
                                height: 56
                                radius: 8
                                color: root.selectedGameVersion === id
                                       ? root.style.cNavSelected
                                       : gameMouse.containsMouse ? root.style.cNavHover : "transparent"
                                border.width: root.selectedGameVersion === id ? 1 : 0
                                border.color: root.style.cBorder

                                MouseArea {
                                    id: gameMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedGameVersion = id
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
                                        text: id
                                        color: root.style.cTextOnSurface
                                        font.pixelSize: 14
                                        font.bold: root.selectedGameVersion === id
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
                            Layout.preferredHeight: 118
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
                            Layout.preferredHeight: 78
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
                                text: "安装目录：~/.local/share/mc-launcher/minecraft/"
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 11
                                elide: Text.ElideLeft
                            }

                            ActionButton {
                                style: root.style
                                text: "安装所选版本"
                                primary: true
                                onClicked: root.installSelected()
                            }
                        }
                    }
                }
            }
        }

        OutputPanel {
            Layout.fillWidth: true
            Layout.maximumWidth: 980
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            style: root.style
            text: root.backend.output
        }
    }

    function refreshCatalog() {
        var raw = root.backend.refreshDownloadCatalog(root.downloadSource)
        root.catalog = JSON.parse(raw)

        gameModel.clear()
        fabricLoaderModel.clear()
        quiltLoaderModel.clear()

        for (var i = 0; i < root.catalog.gameVersions.length; i++) {
            var game = root.catalog.gameVersions[i]
            gameModel.append({
                "id": game.id,
                "versionType": game.versionType,
                "releaseTime": game.releaseTime
            })
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

        if (gameModel.count > 0 && root.selectedGameVersion.length === 0) {
            root.selectedGameVersion = gameModel.get(0).id
        }

        root.rebuildInstallerModels()
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
            return "将安装 Minecraft " + root.selectedGameVersion + " 原版。"
        }

        if (loaderVersion.length === 0) {
            return "请选择 " + root.selectedLoaderKind + " 版本。"
        }

        return "将安装 Minecraft " + root.selectedGameVersion
            + " + " + root.selectedLoaderKind
            + " " + loaderVersion + "。"
    }

    function installSelected() {
        root.backend.installGameVersion(
            root.downloadSource,
            root.selectedGameVersion,
            root.selectedLoaderKind,
            root.selectedLoaderVersion()
        )
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

    component OutputPanel: Rectangle {
        id: panel

        required property var style
        property string text: ""

        radius: style.radiusValue
        color: style.cSurfaceContainer
        border.color: style.cBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "输出"
                color: panel.style.cTextOnSurface
                font.pixelSize: 14
                font.bold: true
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    width: parent.width
                    readOnly: true
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    text: panel.text
                    placeholderText: "刷新版本列表或安装版本后，输出会显示在这里。"
                    color: panel.style.cTextOnSurface
                    placeholderTextColor: panel.style.cTextOnSurfaceVariant
                    background: Item {}
                }
            }
        }
    }
}
