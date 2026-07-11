import QtQuick

Item {
    id: root
    objectName: "downloadWizardPageStack"
    clip: true

    required property var style
    required property var controller

    // Desired page is derived from the HMCL-style wizard state kept by the
    // controller. activePage is the page that has completed its transition.
    readonly property int currentPage: controller.loaderVersionPaneOpen ? 2
                                       : controller.installerPaneOpen ? 1 : 0
    property int activePage: 0
    property int desiredPage: 0
    property bool transitionStartQueued: false

    // HMCL DecoratorWizardDisplayer:
    // navigate(page, FORWARD/BACKWARD, Motion.SHORT4, Motion.EASE)
    readonly property int transitionDuration: style.animationsEnabled ? 200 : 0
    readonly property int halfDuration: Math.round(transitionDuration * 0.5)
    readonly property real transitionOffset: width > 0 ? width * 0.20 : 50

    function pageName(index) {
        if (index === 1)
            return "installers"
        if (index === 2)
            return "loaderVersions"
        return "versions"
    }

    function pageAt(index) {
        if (index === 1)
            return installersFrame
        if (index === 2)
            return loaderVersionsFrame
        return versionsFrame
    }

    function forEachPage(callback) {
        callback(versionsFrame, 0)
        callback(installersFrame, 1)
        callback(loaderVersionsFrame, 2)
    }

    function resetFrame(frame, shown) {
        frame.translateX = 0
        frame.opacity = shown ? 1 : 0
        frame.visible = shown
        frame.enabled = shown
        frame.z = shown ? 2 : 0
    }

    function snapTo(index, reason) {
        transitionAnimation.stop()
        root.forEachPage(function(frame, frameIndex) {
            root.resetFrame(frame, frameIndex === index)
        })
        root.activePage = index
        root.desiredPage = index
        root.controller.logAction("download_stack_transition_snapped", {
            "reason": reason || "snap",
            "page": root.pageName(index),
            "animationsEnabled": !!root.style.animationsEnabled
        })
    }

    function requestTransition(index, reason) {
        if (index < 0 || index > 2)
            return

        root.desiredPage = index

        if (transitionAnimation.running || root.transitionStartQueued)
            return

        // HMCL TransitionPane starts the animation from Platform.runLater so
        // the new page completes layout before the first key frame. Qt.callLater
        // provides the equivalent next-event-loop behavior in Qt Quick.
        root.transitionStartQueued = true
        Qt.callLater(function() {
            root.transitionStartQueued = false
            root.beginDesiredTransition(reason || "controller_state")
        })
    }

    function beginDesiredTransition(reason) {
        if (transitionAnimation.running)
            return

        var nextIndex = root.desiredPage
        var previousIndex = root.activePage

        if (nextIndex === previousIndex) {
            root.snapTo(nextIndex, reason || "same_page")
            return
        }

        if (!root.style.animationsEnabled || root.transitionDuration <= 0
                || root.width <= 0 || root.height <= 0) {
            root.snapTo(nextIndex, reason || "animation_disabled")
            return
        }

        var outgoing = root.pageAt(previousIndex)
        var incoming = root.pageAt(nextIndex)
        var forward = nextIndex > previousIndex
        var outgoingEnd = forward ? -root.transitionOffset : root.transitionOffset
        var incomingMid = forward ? root.transitionOffset : -root.transitionOffset

        root.forEachPage(function(frame) {
            frame.visible = false
            frame.enabled = false
            frame.opacity = 0
            frame.translateX = 0
            frame.z = 0
        })

        // Equivalent to AnimationUtils.reset(previousNode, true) and
        // AnimationUtils.reset(nextNode, false) in HMCL TransitionPane.
        outgoing.visible = true
        outgoing.enabled = false
        outgoing.opacity = 1
        outgoing.translateX = 0
        outgoing.z = 1

        incoming.visible = true
        incoming.enabled = false
        incoming.opacity = 0
        incoming.translateX = 0
        incoming.z = 2

        transitionAnimation.outgoingPage = outgoing
        transitionAnimation.incomingPage = incoming
        transitionAnimation.targetPageIndex = nextIndex
        transitionAnimation.outgoingEndX = outgoingEnd
        transitionAnimation.incomingMidX = incomingMid

        root.controller.logAction("download_stack_transition_started", {
            "reason": reason || "controller_state",
            "from": root.pageName(previousIndex),
            "to": root.pageName(nextIndex),
            "direction": forward ? "forward" : "backward",
            "durationMs": root.transitionDuration,
            "halfDurationMs": root.halfDuration,
            "offset": root.transitionOffset,
            "easing": "cubic-bezier(0.25,0.1,0.25,1.0)"
        })

        transitionAnimation.restart()
    }

    function finishTransition() {
        var completedIndex = transitionAnimation.targetPageIndex
        var completedPage = root.pageAt(completedIndex)

        root.forEachPage(function(frame, frameIndex) {
            root.resetFrame(frame, frameIndex === completedIndex)
        })

        root.activePage = completedIndex

        root.controller.logAction("download_stack_transition_finished", {
            "page": root.pageName(completedIndex),
            "desiredPage": root.pageName(root.desiredPage)
        })

        // A title-bar Back action can update the controller while the content
        // transition is running. HMCL serializes animations; mirror that by
        // starting the latest requested page only after the current one ends.
        if (root.desiredPage !== root.activePage)
            root.requestTransition(root.desiredPage, "queued_state")
    }

    onCurrentPageChanged: requestTransition(currentPage, "controller_state")

    Component.onCompleted: {
        root.activePage = root.currentPage
        root.desiredPage = root.currentPage
        root.snapTo(root.currentPage, "completed")
    }

    Component.onDestruction: transitionAnimation.stop()

    // Persistent page instances prevent the blank-page failure caused by
    // dynamically destroying and recreating Loader content. The wrapper Items
    // animate a Translate transform, which is the Qt Quick equivalent of
    // JavaFX Node.translateX and does not conflict with anchors.fill.
    Item {
        id: versionsFrame
        objectName: "downloadVersionsWizardFrame"
        anchors.fill: parent
        visible: false
        enabled: false
        opacity: 0
        property real translateX: 0
        transform: Translate { x: versionsFrame.translateX }

        VersionsPage {
            objectName: "downloadVersionsWizardPage"
            anchors.fill: parent
            style: root.style
            controller: root.controller
        }
    }

    Item {
        id: installersFrame
        objectName: "downloadInstallersWizardFrame"
        anchors.fill: parent
        visible: false
        enabled: false
        opacity: 0
        property real translateX: 0
        transform: Translate { x: installersFrame.translateX }

        InstallersPage {
            objectName: "downloadInstallersWizardPage"
            anchors.fill: parent
            style: root.style
            controller: root.controller
        }
    }

    Item {
        id: loaderVersionsFrame
        objectName: "downloadLoaderVersionsWizardFrame"
        anchors.fill: parent
        visible: false
        enabled: false
        opacity: 0
        property real translateX: 0
        transform: Translate { x: loaderVersionsFrame.translateX }

        LoaderVersionsPage {
            objectName: "downloadLoaderVersionsWizardPage"
            anchors.fill: parent
            style: root.style
            controller: root.controller
        }
    }

    // Exact reproduction of HMCL ContainerAnimations.FORWARD/BACKWARD:
    // 0-100 ms: old page moves 20% and fades to zero. The new page remains
    // invisible while moving from center to its 20% entry offset.
    // 100-200 ms: the new page moves to center and fades from zero to one.
    SequentialAnimation {
        id: transitionAnimation

        property Item outgoingPage: null
        property Item incomingPage: null
        property int targetPageIndex: 0
        property real outgoingEndX: 0
        property real incomingMidX: 0

        ParallelAnimation {
            NumberAnimation {
                target: transitionAnimation.outgoingPage
                property: "translateX"
                to: transitionAnimation.outgoingEndX
                duration: root.halfDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
            }
            NumberAnimation {
                target: transitionAnimation.outgoingPage
                property: "opacity"
                to: 0
                duration: root.halfDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
            }
            NumberAnimation {
                target: transitionAnimation.incomingPage
                property: "translateX"
                to: transitionAnimation.incomingMidX
                duration: root.halfDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: transitionAnimation.incomingPage
                property: "translateX"
                to: 0
                duration: root.halfDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
            }
            NumberAnimation {
                target: transitionAnimation.incomingPage
                property: "opacity"
                to: 1
                duration: root.halfDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
            }
        }

        ScriptAction { script: root.finishTransition() }
    }

    // HMCL sets TransitionPane mouseTransparent while animation is playing.
    // This transparent blocker prevents delegates from receiving a second click
    // during the two-stage transition while keeping the title bar independent.
    MouseArea {
        anchors.fill: parent
        z: 1000
        visible: transitionAnimation.running
        enabled: visible
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        preventStealing: true
        onWheel: function(wheel) { wheel.accepted = true }
    }
}
