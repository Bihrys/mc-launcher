import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    objectName: "downloadPage"

    required property var style
    required property var backend
    required property var taskDialogHost

    readonly property string pageTitle: controller.loaderVersionPaneOpen
                                                ? "选择 " + controller.loaderTitle(controller.loaderVersionKind) + " 版本"
                                                : (controller.installerPaneOpen
                                                   ? "安装新游戏 - " + controller.selectedGameVersion
                                                   : "下载")

    function handleBack() {
        return controller.handleBack()
    }

    function refreshCurrentPage() {
        controller.refreshCurrentPage()
    }

    DownloadPageController {
        id: controller
        style: root.style
        backend: root.backend
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        DownloadSidebar {
            Layout.preferredWidth: controller.showDownloadSidebar() ? 200 : 0
            Layout.fillHeight: true
            visible: controller.showDownloadSidebar()
            clip: true
            style: root.style
            controller: controller
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            DownloadPageStack {
                anchors.fill: parent
                visible: controller.currentTab === "game"
                opacity: visible ? 1 : 0
                style: root.style
                controller: controller

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.style.animationsEnabled ? 180 : 0
                        easing.type: Easing.OutCubic
                    }
                }
            }

            DownloadPlaceholderPage {
                anchors.fill: parent
                visible: controller.currentTab !== "game"
                opacity: visible ? 1 : 0
                style: root.style
                title: controller.placeholderTitle(controller.currentTab)
                message: ""

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.style.animationsEnabled ? 180 : 0
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Connections {
        target: controller

        function onDownloadDialogOpenChanged() {
            if (!controller.downloadDialogOpen)
                return
            root.taskDialogHost.openTransferTask("game")
        }
    }
}
