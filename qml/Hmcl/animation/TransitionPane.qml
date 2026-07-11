import QtQuick

Item {
    id: root

    property Component sourceComponent
    property int animationType: ContainerAnimations.forward
    property int duration: 400
    property bool animationsEnabled: true

    clip: true
    enabled: !d.animating

    Component.onDestruction: {
        exitAnimation.stop()
        enterAnimation.stop()
        cleanupTimer.stop()
    }

    onSourceComponentChanged: {
        if (d.initialized)
            d.switchTo(root.sourceComponent)
    }

    Component.onCompleted: {
        d.initialized = true
        if (root.sourceComponent) {
            d.currentLoader = loaderA
            loaderA.sourceComponent = root.sourceComponent
            d.resetLoader(loaderA, true)
        }
    }

    QtObject {
        id: d
        property bool initialized: false
        property Loader currentLoader: null
        property Loader outgoingLoader: null
        property bool animating: false

        function resetLoader(loader, shown) {
            if (!loader) return
            loader.x = 0
            loader.y = 0
            loader.opacity = shown ? 1 : 0
            loader.visible = shown
        }

        function switchTo(component) {
            if (!component) return
            if (animating) {
                exitAnimation.stop()
                enterAnimation.stop()
                finishOutgoing()
            }

            var outgoing = currentLoader
            var incoming = outgoing === loaderA ? loaderB : loaderA
            currentLoader = incoming
            outgoingLoader = outgoing
            incoming.sourceComponent = component
            incoming.visible = true

            if (!outgoing || !root.animationsEnabled || root.duration <= 0
                    || root.animationType === ContainerAnimations.none) {
                resetLoader(incoming, true)
                if (outgoing) {
                    resetLoader(outgoing, false)
                    deferCleanup(outgoing)
                }
                outgoingLoader = null
                animating = false
                return
            }

            var type = root.animationType
            var widthOffset = root.width > 0 ? root.width * 0.2 : 50
            var heightOffset = root.height > 0 ? root.height * 0.2 : 50

            resetLoader(outgoing, true)
            resetLoader(incoming, false)

            if (type === ContainerAnimations.forward) {
                incoming.x = widthOffset
            } else if (type === ContainerAnimations.backward) {
                incoming.x = -widthOffset
            } else if (type === ContainerAnimations.swipeLeft) {
                incoming.x = root.width
                incoming.opacity = 1
            } else if (type === ContainerAnimations.swipeRight) {
                incoming.x = -root.width
                incoming.opacity = 1
            } else if (type === ContainerAnimations.slideUpFadeIn) {
                incoming.y = heightOffset
            } else {
                incoming.x = 0
                incoming.y = 0
            }

            animating = true
            exitAnimation.targetLoader = outgoing
            exitAnimation.transitionType = type
            enterAnimation.targetLoader = incoming
            enterAnimation.transitionType = type
            exitAnimation.restart()
            enterAnimation.restart()
        }

        function finishOutgoing() {
            if (!outgoingLoader) return
            resetLoader(outgoingLoader, false)
            deferCleanup(outgoingLoader)
            outgoingLoader = null
        }

        function deferCleanup(loader) {
            cleanupTimer.targetLoader = loader
            cleanupTimer.restart()
        }
    }

    Timer {
        id: cleanupTimer
        property Loader targetLoader: null
        interval: 0
        repeat: false
        onTriggered: {
            if (targetLoader && targetLoader !== d.currentLoader)
                targetLoader.sourceComponent = undefined
            targetLoader = null
        }
    }

    Loader {
        id: loaderA
        anchors.top: parent.top
        width: parent.width
        height: parent.height
        visible: false
    }

    Loader {
        id: loaderB
        anchors.top: parent.top
        width: parent.width
        height: parent.height
        visible: false
    }

    ParallelAnimation {
        id: exitAnimation
        property Loader targetLoader: null
        property int transitionType: ContainerAnimations.none
        property int phaseDuration: {
            if (transitionType === ContainerAnimations.forward
                    || transitionType === ContainerAnimations.backward
                    || transitionType === ContainerAnimations.slideUpFadeIn)
                return root.duration * 0.5
            return root.duration
        }

        NumberAnimation {
            target: exitAnimation.targetLoader
            property: "opacity"
            to: exitAnimation.transitionType === ContainerAnimations.swipeLeft
                || exitAnimation.transitionType === ContainerAnimations.swipeRight ? 1 : 0
            duration: exitAnimation.phaseDuration
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: exitAnimation.targetLoader
            property: "x"
            to: {
                var type = exitAnimation.transitionType
                var offset = root.width > 0 ? root.width * 0.2 : 50
                if (type === ContainerAnimations.forward) return -offset
                if (type === ContainerAnimations.backward) return offset
                if (type === ContainerAnimations.swipeLeft) return -root.width
                if (type === ContainerAnimations.swipeRight) return root.width
                return 0
            }
            duration: exitAnimation.phaseDuration
            easing.type: Easing.InOutCubic
        }

        onStopped: d.finishOutgoing()
    }

    SequentialAnimation {
        id: enterAnimation
        property Loader targetLoader: null
        property int transitionType: ContainerAnimations.none
        property bool delayed: transitionType === ContainerAnimations.forward
                               || transitionType === ContainerAnimations.backward
        property int enterDuration: delayed ? root.duration * 0.5 : root.duration

        PauseAnimation { duration: enterAnimation.delayed ? root.duration * 0.5 : 0 }

        ParallelAnimation {
            NumberAnimation {
                target: enterAnimation.targetLoader
                property: "opacity"
                to: 1
                duration: enterAnimation.enterDuration
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: enterAnimation.targetLoader
                property: "x"
                to: 0
                duration: enterAnimation.enterDuration
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: enterAnimation.targetLoader
                property: "y"
                to: 0
                duration: enterAnimation.enterDuration
                easing.type: Easing.InOutCubic
            }
        }

        onStopped: d.animating = false
    }
}
