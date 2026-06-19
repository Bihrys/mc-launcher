import QtQuick

Item {
    id: root

    required property var style

    property Component sourceComponent: null

    // HMCL TabHeader.java:
    // ContainerAnimations.SLIDE_UP_FADE_IN
    // Motion.MEDIUM4 = 400ms
    // Motion.EASE_IN_OUT_CUBIC_EMPHASIZED
    property int duration: 400
    property real containerHeight: height
    property bool animationsEnabled: style.animationsEnabled

    property bool initialized: false
    property bool committing: false

    property real previousOpacity: 1
    property real nextOpacity: 0
    property real nextY: 0

    // HMCL Motion.EASE_IN_OUT_CUBIC_EMPHASIZED:
    // ThreePointCubic(
    //   (0.05, 0),
    //   (0.133333, 0.06),
    //   (0.166666, 0.4),
    //   (0.208333, 0.82),
    //   (0.25, 1)
    // )
    readonly property var hmclEmphasizedCurve: [
        0.05, 0.0,
        0.133333, 0.06,
        0.166666, 0.4,
        0.208333, 0.82,
        0.25, 1.0,
        1.0, 1.0
    ]

    readonly property real enterOffset: root.containerHeight > 0
                                        ? root.containerHeight * 0.2
                                        : 50

    readonly property real previousContentHeight: previousLoader.item
                                                  ? Math.max(previousLoader.item.implicitHeight, previousLoader.item.height)
                                                  : 0

    readonly property real nextContentHeight: nextLoader.item
                                              ? Math.max(nextLoader.item.implicitHeight, nextLoader.item.height)
                                              : 0

    // HMCL TransitionPane 是 StackPane，本身跟随父容器尺寸。
    // 这里还要给 ScrollView 内容高度使用，所以取 old/new 的完整高度。
    readonly property real contentHeight: Math.max(
                                             previousContentHeight,
                                             nextContentHeight + (nextLoader.sourceComponent ? enterOffset : 0),
                                             root.containerHeight,
                                             1
                                         )

    width: parent ? parent.width : 0
    height: contentHeight
    clip: false
    enabled: !transition.running

    Component.onCompleted: {
        root.initialized = true

        if (root.sourceComponent !== null) {
            previousLoader.sourceComponent = root.sourceComponent
            previousLoader.active = true
            nextLoader.sourceComponent = null
            nextLoader.active = false

            root.previousOpacity = 1
            root.nextOpacity = 0
            root.nextY = 0
        }
    }

    onSourceComponentChanged: {
        root.setContent(root.sourceComponent)
    }

    function setContent(component) {
        if (!root.initialized) {
            return
        }

        if (component === null) {
            transition.stop()
            previousLoader.sourceComponent = null
            previousLoader.active = false
            nextLoader.sourceComponent = null
            nextLoader.active = false
            root.previousOpacity = 0
            root.nextOpacity = 0
            root.nextY = 0
            return
        }

        if (previousLoader.sourceComponent === component && nextLoader.sourceComponent === null) {
            return
        }

        // HMCL TransitionPane：新动画会替换 transition_pane 上一次动画。
        // Qt 这里快速连续点击时，先把正在进入的新页面提交为 previous，再进入下一页。
        if (transition.running) {
            root.commitNextAsPrevious()
            transition.stop()
        }

        if (!root.animationsEnabled || previousLoader.sourceComponent === null) {
            previousLoader.sourceComponent = component
            previousLoader.active = true
            nextLoader.sourceComponent = null
            nextLoader.active = false

            root.previousOpacity = 1
            root.nextOpacity = 0
            root.nextY = 0
            return
        }

        nextLoader.sourceComponent = component
        nextLoader.active = true

        // HMCL KeyFrame(Duration.ZERO)
        root.previousOpacity = 1
        root.nextOpacity = 0
        root.nextY = root.enterOffset

        transition.restart()
    }

    function commitNextAsPrevious() {
        if (nextLoader.sourceComponent !== null) {
            previousLoader.sourceComponent = nextLoader.sourceComponent
            previousLoader.active = true
            nextLoader.sourceComponent = null
            nextLoader.active = false
        }

        root.previousOpacity = 1
        root.nextOpacity = 0
        root.nextY = 0
    }

    Loader {
        id: previousLoader

        active: sourceComponent !== null
        width: root.width
        opacity: root.previousOpacity
        visible: active && root.previousOpacity > 0.001
        y: 0
        asynchronous: true
    }

    Loader {
        id: nextLoader

        active: sourceComponent !== null
        width: root.width
        opacity: root.nextOpacity
        visible: active && root.nextOpacity > 0.001
        y: root.nextY
        asynchronous: true
    }

    // 完整对应 HMCL ContainerAnimations.SLIDE_UP_FADE_IN:
    //
    // Duration.ZERO:
    //   previous.opacity = 1
    //   previous.translateY = 0
    //   next.opacity = 0
    //   next.translateY = offset
    //
    // duration * 0.5:
    //   previous.opacity = 0
    //
    // duration:
    //   next.opacity = 1
    //   next.translateY = 0
    ParallelAnimation {
        id: transition

        NumberAnimation {
            target: root
            property: "previousOpacity"
            from: 1
            to: 0
            duration: root.animationsEnabled ? root.duration * 0.5 : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclEmphasizedCurve
        }

        NumberAnimation {
            target: root
            property: "nextOpacity"
            from: 0
            to: 1
            duration: root.animationsEnabled ? root.duration : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclEmphasizedCurve
        }

        NumberAnimation {
            target: root
            property: "nextY"
            from: root.enterOffset
            to: 0
            duration: root.animationsEnabled ? root.duration : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclEmphasizedCurve
        }

        onFinished: {
            root.commitNextAsPrevious()
        }
    }
}
