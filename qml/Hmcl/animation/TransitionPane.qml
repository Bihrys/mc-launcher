import QtQuick

Item {
    id: root

    property Component sourceComponent
    property int animationType: ContainerAnimations.forward
    property int duration: 400
    property bool animationsEnabled: true

    clip: true

    onSourceComponentChanged: {
        if (!d.initialized) return
        d.switchTo(root.sourceComponent)
    }

    Component.onCompleted: {
        d.initialized = true
        if (root.sourceComponent) {
            d.currentLoader = loaderA
            loaderA.sourceComponent = root.sourceComponent
            loaderA.opacity = 1
            loaderA.x = 0
            loaderA.y = 0
            loaderA.visible = true
        }
    }

    QtObject {
        id: d
        property bool initialized: false
        property Loader currentLoader: null
        property bool animating: false

        function switchTo(comp) {
            if (animating) {
                exitAnim.stop()
                enterAnim.stop()
                if (currentLoader) {
                    currentLoader.opacity = 0
                    currentLoader.visible = false
                }
            }

            var outgoing = currentLoader
            var incoming = (outgoing === loaderA) ? loaderB : loaderA
            currentLoader = incoming

            incoming.sourceComponent = comp
            incoming.visible = true

            if (!root.animationsEnabled || root.duration <= 0) {
                incoming.opacity = 1
                incoming.x = 0
                incoming.y = 0
                if (outgoing) {
                    outgoing.opacity = 0
                    outgoing.visible = false
                    outgoing.sourceComponent = undefined
                }
                return
            }

            d.animating = true
            var type = root.animationType
            var w = root.width
            var h = root.height
            var offset

            switch (type) {
            case ContainerAnimations.fade:
                incoming.x = 0; incoming.y = 0
                incoming.opacity = 0
                if (outgoing) { outgoing.x = 0; outgoing.y = 0 }
                break
            case ContainerAnimations.forward:
                offset = w > 0 ? w * 0.2 : 50
                incoming.x = offset; incoming.y = 0; incoming.opacity = 0
                if (outgoing) { outgoing.y = 0 }
                break
            case ContainerAnimations.backward:
                offset = w > 0 ? w * 0.2 : 50
                incoming.x = -offset; incoming.y = 0; incoming.opacity = 0
                if (outgoing) { outgoing.y = 0 }
                break
            case ContainerAnimations.swipeLeft:
                incoming.x = w; incoming.y = 0; incoming.opacity = 1
                if (outgoing) { outgoing.y = 0 }
                break
            case ContainerAnimations.swipeRight:
                incoming.x = -w; incoming.y = 0; incoming.opacity = 1
                if (outgoing) { outgoing.y = 0 }
                break
            case ContainerAnimations.slideUpFadeIn:
                offset = h > 0 ? h * 0.2 : 50
                incoming.x = 0; incoming.y = offset; incoming.opacity = 0
                if (outgoing) { outgoing.x = 0 }
                break
            case ContainerAnimations.navigation:
                incoming.x = 0; incoming.y = 0; incoming.opacity = 0
                if (outgoing) { outgoing.y = 0 }
                break
            default:
                incoming.opacity = 1; incoming.x = 0; incoming.y = 0
                if (outgoing) { outgoing.opacity = 0; outgoing.visible = false; outgoing.sourceComponent = undefined }
                d.animating = false
                return
            }

            exitAnim.target = outgoing
            exitAnim.type = type
            exitAnim.containerW = w
            exitAnim.containerH = h
            enterAnim.target = incoming
            enterAnim.type = type
            enterAnim.containerW = w
            enterAnim.containerH = h
            exitAnim.outgoingRef = outgoing
            exitAnim.start()
            enterAnim.start()
        }
    }

    Loader {
        id: loaderA
        anchors.top: parent.top
        width: parent.width
        height: parent.height
        visible: false
        asynchronous: true
    }

    Loader {
        id: loaderB
        anchors.top: parent.top
        width: parent.width
        height: parent.height
        visible: false
        asynchronous: true
    }

    ParallelAnimation {
        id: exitAnim
        property Item target
        property int type
        property real containerW
        property real containerH
        property Item outgoingRef

        NumberAnimation {
            target: exitAnim.target
            property: "opacity"
            to: 0
            duration: {
                if (!exitAnim.target) return 0
                var t = exitAnim.type
                if (t === ContainerAnimations.swipeLeft || t === ContainerAnimations.swipeRight)
                    return root.duration
                return root.duration * 0.5
            }
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: exitAnim.target
            property: "x"
            to: {
                if (!exitAnim.target) return 0
                var t = exitAnim.type
                var offset = exitAnim.containerW > 0 ? exitAnim.containerW * 0.2 : 50
                if (t === ContainerAnimations.forward) return -offset
                if (t === ContainerAnimations.backward) return offset
                if (t === ContainerAnimations.swipeLeft) return -exitAnim.containerW
                if (t === ContainerAnimations.swipeRight) return exitAnim.containerW
                return 0
            }
            duration: root.duration
            easing.type: Easing.OutCubic
        }

        onStopped: {
            if (outgoingRef) {
                outgoingRef.visible = false
                outgoingRef.opacity = 0
                outgoingRef.x = 0
                outgoingRef.y = 0
                outgoingRef.sourceComponent = undefined
            }
        }
    }

    ParallelAnimation {
        id: enterAnim
        property Item target
        property int type
        property real containerW
        property real containerH

        NumberAnimation {
            target: enterAnim.target
            property: "opacity"
            to: 1
            duration: root.duration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: enterAnim.target
            property: "x"
            to: 0
            duration: root.duration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: enterAnim.target
            property: "y"
            to: 0
            duration: root.duration
            easing.type: Easing.OutCubic
        }

        onStopped: d.animating = false
    }
}
