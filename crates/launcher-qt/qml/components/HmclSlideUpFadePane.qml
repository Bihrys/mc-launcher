import QtQuick

Item {
    id: root

    required property var style

    property Component sourceComponent: null

    // HMCL:
    // ContainerAnimations.SLIDE_UP_FADE_IN
    // Motion.MEDIUM4 = 400ms
    // Motion.EASE_IN_OUT_CUBIC_EMPHASIZED
    property int duration: 400
    property real containerHeight: height
    property bool animationsEnabled: style.animationsEnabled

    property bool initialized: false

    property Component sourceA: null
    property Component sourceB: null

    property int currentLayer: -1
    property int previousLayer: -1
    property int nextLayer: -1

    property real previousOpacity: 1
    property real nextOpacity: 0
    property real nextY: 0

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

    readonly property real aContentHeight: loaderA.item
                                           ? Math.max(loaderA.item.implicitHeight, loaderA.item.height)
                                           : 0

    readonly property real bContentHeight: loaderB.item
                                           ? Math.max(loaderB.item.implicitHeight, loaderB.item.height)
                                           : 0

    readonly property real contentHeight: Math.max(
                                             aContentHeight + Math.max(0, root.layerY(0)),
                                             bContentHeight + Math.max(0, root.layerY(1)),
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
            root.sourceA = root.sourceComponent
            root.sourceB = null
            root.currentLayer = 0
            root.previousLayer = -1
            root.nextLayer = -1
            root.previousOpacity = 1
            root.nextOpacity = 0
            root.nextY = 0
        }
    }

    onSourceComponentChanged: {
        root.setContent(root.sourceComponent)
    }

    function layerOpacity(layer) {
        if (transition.running) {
            if (layer === root.previousLayer) {
                return root.previousOpacity
            }

            if (layer === root.nextLayer) {
                return root.nextOpacity
            }
        }

        return layer === root.currentLayer ? 1 : 0
    }

    function layerY(layer) {
        if (transition.running && layer === root.nextLayer) {
            return root.nextY
        }

        return 0
    }

    function layerActive(layer) {
        if (layer === 0) {
            return root.sourceA !== null
        }

        return root.sourceB !== null
    }

    function setLayerSource(layer, component) {
        if (layer === 0) {
            root.sourceA = component
        } else {
            root.sourceB = component
        }
    }

    function clearInactiveLayer() {
        if (root.currentLayer === 0) {
            root.sourceB = null
        } else if (root.currentLayer === 1) {
            root.sourceA = null
        }
    }

    function commitIncomingAsCurrent() {
        if (root.nextLayer !== -1) {
            root.currentLayer = root.nextLayer
        }

        root.previousLayer = -1
        root.nextLayer = -1
        root.previousOpacity = 1
        root.nextOpacity = 0
        root.nextY = 0

        root.clearInactiveLayer()
    }

    function setContent(component) {
        if (!root.initialized) {
            return
        }

        if (component === null) {
            transition.stop()
            root.sourceA = null
            root.sourceB = null
            root.currentLayer = -1
            root.previousLayer = -1
            root.nextLayer = -1
            root.previousOpacity = 0
            root.nextOpacity = 0
            root.nextY = 0
            return
        }

        if (root.currentLayer === 0 && root.sourceA === component && !transition.running) {
            return
        }

        if (root.currentLayer === 1 && root.sourceB === component && !transition.running) {
            return
        }

        // 快速连续点击时，先把正在进入的新页面作为当前页面。
        // 这里不重新加载页面，只切换层角色，避免闪烁。
        if (transition.running) {
            transition.stop()
            root.commitIncomingAsCurrent()
        }

        if (root.currentLayer === -1 || !root.animationsEnabled) {
            root.sourceA = component
            root.sourceB = null
            root.currentLayer = 0
            root.previousLayer = -1
            root.nextLayer = -1
            root.previousOpacity = 1
            root.nextOpacity = 0
            root.nextY = 0
            return
        }

        var targetLayer = root.currentLayer === 0 ? 1 : 0

        root.setLayerSource(targetLayer, component)

        root.previousLayer = root.currentLayer
        root.nextLayer = targetLayer

        // HMCL KeyFrame(Duration.ZERO)
        root.previousOpacity = 1
        root.nextOpacity = 0
        root.nextY = root.enterOffset

        transition.restart()
    }

    Loader {
        id: loaderA

        active: root.sourceA !== null
        sourceComponent: root.sourceA
        width: root.width
        opacity: root.layerOpacity(0)
        visible: active && opacity > 0.001
        y: root.layerY(0)

        // 关键：动画结束时不能异步重建，否则会闪。
        asynchronous: false
    }

    Loader {
        id: loaderB

        active: root.sourceB !== null
        sourceComponent: root.sourceB
        width: root.width
        opacity: root.layerOpacity(1)
        visible: active && opacity > 0.001
        y: root.layerY(1)

        // 关键：动画结束时不能异步重建，否则会闪。
        asynchronous: false
    }

    // HMCL ContainerAnimations.SLIDE_UP_FADE_IN：
    // previous: 0ms opacity=1 -> 200ms opacity=0
    // next:     0ms opacity=0, translateY=height*0.2 -> 400ms opacity=1, translateY=0
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
            root.commitIncomingAsCurrent()
        }
    }
}
