import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

// Qt Quick port of HMCL AbstractInstallersPage.InstallersPageSkin.
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

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 76

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 1
                anchors.rightMargin: -1
                anchors.topMargin: 1
                anchors.bottomMargin: -1
                radius: 4
                color: Qt.rgba(0, 0, 0, page.style.darkMode ? 0.30 : 0.18)
            }

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: page.style.cSurfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "游戏实例名称"
                        color: page.style.cTextOnSurface
                        font.pixelSize: 13
                    }

                    TextField {
                        id: instanceNameField
                        Layout.preferredWidth: 152
                        Layout.maximumWidth: 300
                        Layout.preferredHeight: 36
                        text: page.controller.installVersionName
                        color: page.style.cTextOnSurface
                        selectByMouse: true
                        leftPadding: 10
                        rightPadding: 10
                        font.pixelSize: 13

                        background: Rectangle {
                            radius: 2
                            color: page.style.cSurfaceContainerHigh
                            border.width: instanceNameField.activeFocus ? 1 : 0
                            border.color: page.style.cPrimary
                        }

                        onTextEdited: {
                            page.controller.installVersionName = text
                            page.controller.installNameModifiedByUser = true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        ScrollView {
            id: installerScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            contentHeight: installerFlow.implicitHeight
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
            ScrollBar.vertical: ScrollBar {
                policy: installerFlow.implicitHeight > installerScroll.availableHeight
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            Flow {
                id: installerFlow
                width: installerScroll.availableWidth
                flow: Flow.LeftToRight
                spacing: 16

                DownloadInstallerCard {
                    style: page.style
                    width: 180
                    libraryId: "game"
                    title: "Minecraft"
                    statusText: page.controller.installerStatus("vanilla")
                    iconSource: page.controller.loaderIcon("vanilla")
                    selected: true
                    removable: false
                    installActionVisible: false
                }

                DownloadInstallerCard {
                    style: page.style
                    width: 180
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
                    width: 180
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
                    width: 180
                    libraryId: "optifine"
                    title: "OptiFine"
                    statusText: page.controller.installerStatus("optifine")
                    iconSource: page.controller.loaderIcon("optifine")
                    selected: page.controller.installerSelected("optifine")
                    removable: page.controller.installerSelected("optifine")
                    incompatibleCard: page.controller.installerIncompatibleWith("optifine").length > 0
                    onInstallClicked: page.controller.selectInstaller("optifine")
                    onRemoveClicked: page.controller.removeInstaller("optifine")
                }

                DownloadInstallerCard {
                    style: page.style
                    width: 180
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
                    width: 180
                    libraryId: "fabric-api"
                    title: "Fabric API"
                    statusText: page.controller.installerStatus("fabric-api")
                    iconSource: page.controller.loaderIcon("fabric-api")
                    selected: page.controller.installerSelected("fabric-api")
                    removable: page.controller.installerSelected("fabric-api")
                    incompatibleCard: page.controller.installerIncompatibleWith("fabric-api").length > 0
                    onInstallClicked: page.controller.selectInstaller("fabric-api")
                    onRemoveClicked: page.controller.removeInstaller("fabric-api")
                }

                DownloadInstallerCard {
                    style: page.style
                    width: 180
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
                    width: 180
                    libraryId: "quilt-api"
                    title: "QSL/QFAPI"
                    statusText: page.controller.installerStatus("quilt-api")
                    iconSource: page.controller.loaderIcon("quilt-api")
                    selected: page.controller.installerSelected("quilt-api")
                    removable: page.controller.installerSelected("quilt-api")
                    incompatibleCard: page.controller.installerIncompatibleWith("quilt-api").length > 0
                    onInstallClicked: page.controller.selectInstaller("quilt-api")
                    onRemoveClicked: page.controller.removeInstaller("quilt-api")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            Item { Layout.fillWidth: true }

            DownloadButton {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                style: page.style
                text: page.controller.downloadTaskStatus.active ? "查看任务" : "安装"
                primary: true
                buttonEnabled: page.controller.isValidVersionName(page.controller.installVersionName)
                onClicked: {
                    if (page.controller.downloadTaskStatus.active) {
                        page.controller.downloadDialogOpen = false
                        page.controller.downloadDialogOpen = true
                    } else {
                        page.controller.installSelected()
                    }
                }
            }
        }
    }
}
