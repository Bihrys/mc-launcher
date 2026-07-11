import QtQuick

Item {
    id: root
    objectName: "downloadWizardPageStack"

    required property var style
    required property var controller

    readonly property int currentPage: controller.loaderVersionPaneOpen ? 2
                                       : controller.installerPaneOpen ? 1 : 0
    property int previousPage: 0
    readonly property real pageOffset: Math.max(48, width * 0.20)
    readonly property int transitionDuration: style.animationsEnabled ? 400 : 0

    function pageName(index) {
        if (index === 1)
            return "installers"
        if (index === 2)
            return "loaderVersions"
        return "versions"
    }

    function pageX(index) {
        if (index === root.currentPage)
            return 0
        return index < root.currentPage ? -root.pageOffset : root.pageOffset
    }

    function logPageState(reason) {
        root.controller.logAction("download_stack_page_changed", {
            "reason": reason || "state",
            "from": root.pageName(root.previousPage),
            "to": root.pageName(root.currentPage),
            "currentPage": root.currentPage,
            "installerPaneOpen": root.controller.installerPaneOpen,
            "loaderVersionPaneOpen": root.controller.loaderVersionPaneOpen,
            "gameVersion": root.controller.selectedGameVersion,
            "loaderKind": root.controller.loaderVersionKind
        })
    }

    onCurrentPageChanged: {
        root.logPageState("controller_state")
        root.previousPage = root.currentPage
    }

    Component.onCompleted: {
        root.previousPage = root.currentPage
        root.logPageState("completed")
    }

    // HMCL 的向导由 WizardController 保存页面状态。这里同样让三个页面实例
    // 持续存在，仅改变位置和透明度；避免动态 Loader 在切换时先销毁旧页面，
    // 但新 InstallersPage 创建失败后留下空白容器。
    VersionsPage {
        id: versionsPage
        objectName: "downloadVersionsWizardPage"
        anchors.fill: parent
        style: root.style
        controller: root.controller
        enabled: root.currentPage === 0
        visible: enabled || opacity > 0.001
        opacity: root.currentPage === 0 ? 1 : 0
        x: root.pageX(0)
        z: root.currentPage === 0 ? 3 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.InOutCubic
            }
        }
    }

    InstallersPage {
        id: installersPage
        objectName: "downloadInstallersWizardPage"
        anchors.fill: parent
        style: root.style
        controller: root.controller
        enabled: root.currentPage === 1
        visible: enabled || opacity > 0.001
        opacity: root.currentPage === 1 ? 1 : 0
        x: root.pageX(1)
        z: root.currentPage === 1 ? 3 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.InOutCubic
            }
        }
    }

    LoaderVersionsPage {
        id: loaderVersionsPage
        objectName: "downloadLoaderVersionsWizardPage"
        anchors.fill: parent
        style: root.style
        controller: root.controller
        enabled: root.currentPage === 2
        visible: enabled || opacity > 0.001
        opacity: root.currentPage === 2 ? 1 : 0
        x: root.pageX(2)
        z: root.currentPage === 2 ? 3 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.InOutCubic
            }
        }
    }
}
