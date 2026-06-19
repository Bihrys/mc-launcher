import QtQuick

Item {
    id: root

    required property var style

    property Component sourceComponent: null
    property int duration: 400
    property real containerHeight: height
    property bool animationsEnabled: style.animationsEnabled

    property bool initialized: false
    property bool suppressCommit: false

    property real currentOpacity: 1
    property real incomingOpacity: 0
    property real incomingY: 0

    readonly property real enterOffset: root.containerHeight > 0 ? root.containerHeight * 0.2 : 50
    readonly property real currentContentHeight: currentLoader.item
                                                 ? Math.max(currentLoader.item.implicitHeight, currentLoader.item.height)
                                                 : 0
    readonly property real incomingContentHeight: incomingLoader.item
                                                  ? Math.max(incomingLoader.item.implicitHeight, incomingLoader.item.height)
                                                  : 0

    // 关键：动画期间给 incoming 的 y 偏移预留空间，避免“拦腰截断”。
    readonly property real contentHeight: Math.max(
                                             currentLoader.sourceComponent ? currentContentHeight : 0,
                                             incomingLoader.sourceComponent ? incomingContentHeight + enterOffset : 0,
                                             1
                                         )

    width: parent ? parent.width : 0
    height: contentHeight
    clip: false

    Component.onCompleted: {
        root.initialized = true

        if (root.sourceComponent !== null) {
            currentLoader.sourceComponent = root.sourceComponent
            root.currentOpacity = 1
            root.incomingOpacity = 0
            root.incomingY = 0
        }
    }

    onSourceComponentChanged: {
        root.switchContent(root.sourceComponent)
    }

    function stopTransitionWithoutCommit() {
        root.suppressCommit = true
        transitionAnimation.stop()
        root.suppressCommit = false
    }

    function switchContent(component) {
        if (!root.initialized) {
            return
        }

        if (component === null) {
            root.stopTransitionWithoutCommit()
            currentLoader.sourceComponent = null
            incomingLoader.sourceComponent = null
            return
        }

        if (currentLoader.sourceComponent === component && incomingLoader.sourceComponent === null) {
            return
        }

        // 快速连续点击时，先把上一次 incoming 提交成 current，再开始下一次动画。
        if (incomingLoader.sourceComponent !== null) {
            root.stopTransitionWithoutCommit()
            currentLoader.sourceComponent = incomingLoader.sourceComponent
            currentLoader.active = true
            incomingLoader.sourceComponent = null
            incomingLoader.active = false
            root.currentOpacity = 1
            root.incomingOpacity = 0
            root.incomingY = 0
        } else {
            transitionAnimation.stop()
        }

        if (!root.animationsEnabled || currentLoader.sourceComponent === null) {
            currentLoader.sourceComponent = component
            currentLoader.active = true
            incomingLoader.sourceComponent = null
            incomingLoader.active = false
            root.currentOpacity = 1
            root.incomingOpacity = 0
            root.incomingY = 0
            return
        }

        incomingLoader.sourceComponent = component
        incomingLoader.active = true

        root.currentOpacity = 1
        root.incomingOpacity = 0
        root.incomingY = root.enterOffset

        transitionAnimation.restart()
    }

    Loader {
        id: currentLoader

        active: sourceComponent !== null
        width: root.width
        opacity: root.currentOpacity
        y: 0
        asynchronous: true
    }

    Loader {
        id: incomingLoader

        active: sourceComponent !== null
        width: root.width
        opacity: root.incomingOpacity
        y: root.incomingY
        asynchronous: true
    }

    // HMCL ContainerAnimations.SLIDE_UP_FADE_IN:
    // previous: opacity 1 -> 0, duration * 0.5
    // next: opacity 0 -> 1, translateY offset -> 0, duration
    ParallelAnimation {
        id: transitionAnimation

        NumberAnimation {
            target: root
            property: "currentOpacity"
            from: 1
            to: 0
            duration: root.animationsEnabled ? root.duration / 2 : 0
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "incomingOpacity"
            from: 0
            to: 1
            duration: root.animationsEnabled ? root.duration : 0
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "incomingY"
            from: root.enterOffset
            to: 0
            duration: root.animationsEnabled ? root.duration : 0
            easing.type: Easing.OutCubic
        }

        onStopped: {
            if (root.suppressCommit) {
                return
            }

            if (incomingLoader.sourceComponent !== null) {
                currentLoader.sourceComponent = incomingLoader.sourceComponent
                currentLoader.active = true
                incomingLoader.sourceComponent = null
                incomingLoader.active = false
                root.currentOpacity = 1
                root.incomingOpacity = 0
                root.incomingY = 0
            }
        }
    }
}
