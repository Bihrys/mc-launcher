import QtQuick
import "../../Hmcl/animation" as HmclAnimation

Item {
    id: root
    required property var style
    required property var controller

    property int currentPage: controller.loaderVersionPaneOpen ? 2
                              : controller.installerPaneOpen ? 1 : 0
    property int previousPage: 0

    Component {
        id: versionsComponent
        VersionsPage { style: root.style; controller: root.controller }
    }
    Component {
        id: installersComponent
        InstallersPage { style: root.style; controller: root.controller }
    }
    Component {
        id: loaderVersionsComponent
        LoaderVersionsPage { style: root.style; controller: root.controller }
    }

    onCurrentPageChanged: {
        var forward = currentPage > previousPage
        transition.animationType = forward
                ? HmclAnimation.ContainerAnimations.forward
                : HmclAnimation.ContainerAnimations.backward
        transition.sourceComponent = currentPage === 2
                ? loaderVersionsComponent
                : currentPage === 1 ? installersComponent : versionsComponent
        previousPage = currentPage
    }

    Component.onCompleted: previousPage = currentPage

    HmclAnimation.TransitionPane {
        id: transition
        anchors.fill: parent
        duration: root.style.animationsEnabled ? 400 : 0
        animationsEnabled: root.style.animationsEnabled
        sourceComponent: versionsComponent
    }
}
