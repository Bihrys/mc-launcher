import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    objectName: "downloadPage"

    required property var style
    required property var backend

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

    Rectangle {
        anchors.fill: parent
        z: 1000
        visible: opacity > 0
        opacity: controller.downloadDialogOpen ? 1 : 0
        color: "#80000000"

        Behavior on opacity {
            NumberAnimation {
                duration: root.style.animationsEnabled ? 160 : 0
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: controller.downloadDialogOpen
            onClicked: {
                if (!controller.downloadTaskStatus.active)
                    controller.downloadDialogOpen = false
            }
        }

        TaskExecutorDialogPane {
            anchors.centerIn: parent
            width: Math.min(root.width - 64, 500)
            height: Math.min(root.height - 64, 300)
            opacity: controller.downloadDialogOpen ? 1 : 0
            scale: controller.downloadDialogOpen ? 1 : 0.97
            style: root.style
            status: controller.downloadTaskStatus

            Behavior on opacity {
                NumberAnimation {
                    duration: root.style.animationsEnabled ? 160 : 0
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.style.animationsEnabled ? 180 : 0
                    easing.type: Easing.OutCubic
                }
            }

            onCancelRequested: {
                controller.downloadCancelDismissed = true
                controller.downloadDialogOpen = false
                root.backend.cancelDownloadTask()
            }
            onCloseRequested: controller.downloadDialogOpen = false
        }
    }
}
