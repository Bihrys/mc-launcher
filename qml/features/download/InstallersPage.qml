import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "components"

Item {
    id: page
    objectName: "downloadInstallersPage"
    required property var style
    required property var controller

    function logPageState(action) {
        if (!page.controller)
            return
        page.controller.logAction(action, {
            "gameVersion": page.controller.selectedGameVersion,
            "loaderKind": page.controller.loaderVersionKind,
            "visible": page.visible,
            "enabled": page.enabled,
            "opacity": page.opacity,
            "width": page.width,
            "height": page.height
        })
    }

    Component.onCompleted: page.logPageState("installers_page_completed")
    onVisibleChanged: page.logPageState("installers_page_visible_changed")

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                radius: 4
                color: page.style.cSurfaceContainerHigh
                border.color: page.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "版本名称"
                        color: page.style.cTextOnSurface
                        font.pixelSize: 13
                    }

                    TextField {
                        Layout.preferredWidth: 300
                        Layout.preferredHeight: 36
                        text: page.controller.installVersionName
                        selectByMouse: true
                        onTextEdited: {
                            page.controller.installVersionName = text
                            page.controller.installNameModifiedByUser = true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    DownloadButton {
                        Layout.preferredWidth: 110
                        style: page.style
                        text: "返回版本列表"
                        onClicked: page.controller.closeInstallerPane()
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

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "game"
                        title: "Minecraft"
                        statusText: page.controller.installerStatus("vanilla")
                        iconSource: page.controller.loaderIcon("vanilla")
                        selected: page.controller.installerSelected("vanilla")
                        removable: false
                        onInstallClicked: page.controller.selectInstaller("vanilla")
                    }

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "forge"
                        title: "Forge"
                        statusText: page.controller.installerStatus("forge")
                        iconSource: page.controller.loaderIcon("forge")
                        selected: page.controller.installerSelected("forge")
                        removable: page.controller.installerSelected("forge")
                        incompatibleCard: page.controller.installerIncompatibleWith("forge").length > 0
                        onInstallClicked: page.controller.selectInstaller("forge")
                        onRemoveClicked: page.controller.removeInstaller("forge")
                    }

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "neoforge"
                        title: "NeoForge"
                        statusText: page.controller.installerStatus("neoforge")
                        iconSource: page.controller.loaderIcon("neoforge")
                        selected: page.controller.installerSelected("neoforge")
                        removable: page.controller.installerSelected("neoforge")
                        incompatibleCard: page.controller.installerIncompatibleWith("neoforge").length > 0
                        onInstallClicked: page.controller.selectInstaller("neoforge")
                        onRemoveClicked: page.controller.removeInstaller("neoforge")
                    }

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "optifine"
                        title: "OptiFine"
                        statusText: page.controller.installerStatus("optifine")
                        iconSource: page.controller.loaderIcon("optifine")
                        pendingCard: true
                    }

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "fabric"
                        title: "Fabric"
                        statusText: page.controller.installerStatus("fabric")
                        iconSource: page.controller.loaderIcon("fabric")
                        selected: page.controller.installerSelected("fabric")
                        removable: page.controller.installerSelected("fabric")
                        incompatibleCard: page.controller.installerIncompatibleWith("fabric").length > 0
                        onInstallClicked: page.controller.selectInstaller("fabric")
                        onRemoveClicked: page.controller.removeInstaller("fabric")
                    }

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "fabric-api"
                        title: "Fabric API"
                        statusText: page.controller.installerStatus("fabric-api")
                        iconSource: page.controller.loaderIcon("fabric-api")
                        pendingCard: true
                    }

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "quilt"
                        title: "Quilt"
                        statusText: page.controller.installerStatus("quilt")
                        iconSource: page.controller.loaderIcon("quilt")
                        selected: page.controller.installerSelected("quilt")
                        removable: page.controller.installerSelected("quilt")
                        incompatibleCard: page.controller.installerIncompatibleWith("quilt").length > 0
                        onInstallClicked: page.controller.selectInstaller("quilt")
                        onRemoveClicked: page.controller.removeInstaller("quilt")
                    }

                    DownloadInstallerCard {
                        style: page.style
                        width: page.controller.installerCardWidth(installerFlow.width)
                        libraryId: "quilt-api"
                        title: "Quilt API"
                        statusText: page.controller.installerStatus("quilt-api")
                        iconSource: page.controller.loaderIcon("quilt-api")
                        pendingCard: true
                    }


                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                visible: false
                radius: 4
                color: page.style.cSurfaceContainerHigh
                border.color: page.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: page.controller.loaderTitle(page.controller.selectedLoaderKind) + " 版本"
                        color: page.style.cTextOnSurface
                        font.pixelSize: 13
                        font.bold: true
                    }

                    ComboBox {
                        id: loaderVersionCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        model: page.controller.selectedLoaderKind === "fabric" ? page.controller.fabricLoaders
                               : page.controller.selectedLoaderKind === "quilt" ? page.controller.quiltLoaders
                               : page.controller.selectedLoaderKind === "forge" ? page.controller.forgeInstallers
                               : page.controller.selectedLoaderKind === "neoforge" ? page.controller.neoForgeInstallers
                               : null
                        textRole: page.controller.selectedLoaderKind === "forge" || page.controller.selectedLoaderKind === "neoforge"
                                  ? "loaderVersion" : "version"

                        onActivated: function(index) {
                            page.controller.setSelectedLoaderVersionFromIndex(page.controller.selectedLoaderKind, index)
                        }
                    }

                    Text {
                        Layout.preferredWidth: 128
                        text: page.controller.selectedLoaderVersion().length > 0
                              ? "当前：" + page.controller.selectedLoaderVersion()
                              : "无可用版本"
                        color: page.style.cTextOnSurfaceVariant
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

                DownloadButton {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40
                    style: page.style
                    text: page.controller.downloadTaskStatus.active ? "查看任务" : "安装"
                    primary: true
                    onClicked: {
                        if (page.controller.downloadTaskStatus.active) {
                            page.controller.downloadDialogOpen = true
                        } else {
                            page.controller.installSelected()
                        }
                    }
                }
            }
        }
}
