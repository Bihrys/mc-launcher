import QtQuick

Item {
    id: root

    required property var style

    property string currentPageKey: ""
    property var currentState: null
    property int stateSerial: 0
    property string navigationDirection: "start"
    property bool canGoBack: false

    property bool initialized: false

    property Component sourceA: null
    property Component sourceB: null
    property string keyA: ""
    property string keyB: ""
    property var stateA: null
    property var stateB: null

    property int currentLayer: -1
    property int previousLayer: -1
    property int nextLayer: -1

    property var stackKeys: []
    property var stackComponents: []
    property var stackStates: []

    property real previousOpacity: 1
    property real nextOpacity: 0
    property real previousLeftX: 0
    property real previousCenterX: 0
    property real nextLeftX: 0
    property real nextCenterX: 0

    readonly property int duration: style.motionShort4
    readonly property bool animationsEnabled: style.animationsEnabled

    readonly property var hmclEaseCurve: [
        0.25, 0.1,
        0.25, 1.0,
        1.0, 1.0
    ]

    clip: true
    focus: true

    function init(key, component, state) {
        if (root.initialized) {
            return
        }

        root.sourceA = component
        root.keyA = key
        root.stateA = state

        root.sourceB = null
        root.keyB = ""
        root.stateB = null

        root.currentLayer = 0
        root.previousLayer = -1
        root.nextLayer = -1

        root.currentPageKey = key
        root.currentState = state
        root.navigationDirection = "start"
        root.stateSerial += 1

        root.stackKeys = [key]
        root.stackComponents = [component]
        root.stackStates = [state]
        root.canGoBack = false

        root.initialized = true
        root.forceActiveFocus()
    }

    function navigate(key, component, state) {
        if (!root.initialized) {
            root.init(key, component, state)
            return
        }

        if (root.currentPageKey === key && !transition.running) {
            root.currentState = state
            root.stateSerial += 1
            return
        }

        if (transition.running) {
            transition.stop()
            root.commitIncomingAsCurrent()
        }

        var targetLayer = root.currentLayer === 0 ? 1 : 0
        root.setLayerSource(targetLayer, key, component, state)

        root.previousLayer = root.currentLayer
        root.nextLayer = targetLayer

        root.navigationDirection = "next"
        root.currentPageKey = key
        root.currentState = state
        root.stateSerial += 1

        var keys = root.stackKeys.slice()
        var comps = root.stackComponents.slice()
        var states = root.stackStates.slice()
        keys.push(key)
        comps.push(component)
        states.push(state)
        root.stackKeys = keys
        root.stackComponents = comps
        root.stackStates = states
        root.canGoBack = root.stackKeys.length > 1

        root.startNavigationAnimation("next")
    }

    function close() {
        if (root.stackKeys.length <= 1) {
            return false
        }

        if (transition.running) {
            transition.stop()
            root.commitIncomingAsCurrent()
        }

        var keys = root.stackKeys.slice()
        var comps = root.stackComponents.slice()
        var states = root.stackStates.slice()

        keys.pop()
        comps.pop()
        states.pop()

        var key = keys[keys.length - 1]
        var component = comps[comps.length - 1]
        var state = states[states.length - 1]

        root.stackKeys = keys
        root.stackComponents = comps
        root.stackStates = states
        root.canGoBack = root.stackKeys.length > 1

        var targetLayer = root.currentLayer === 0 ? 1 : 0
        root.setLayerSource(targetLayer, key, component, state)

        root.previousLayer = root.currentLayer
        root.nextLayer = targetLayer

        root.navigationDirection = "previous"
        root.currentPageKey = key
        root.currentState = state
        root.stateSerial += 1

        root.startNavigationAnimation("previous")
        return true
    }

    function clear() {
        if (root.stackKeys.length <= 1) {
            return
        }

        if (transition.running) {
            transition.stop()
            root.commitIncomingAsCurrent()
        }

        var key = root.stackKeys[0]
        var component = root.stackComponents[0]
        var state = root.stackStates[0]

        root.stackKeys = [key]
        root.stackComponents = [component]
        root.stackStates = [state]
        root.canGoBack = false

        var targetLayer = root.currentLayer === 0 ? 1 : 0
        root.setLayerSource(targetLayer, key, component, state)

        root.previousLayer = root.currentLayer
        root.nextLayer = targetLayer

        root.navigationDirection = "previous"
        root.currentPageKey = key
        root.currentState = state
        root.stateSerial += 1

        root.startNavigationAnimation("previous")
    }

    function setLayerSource(layer, key, component, state) {
        if (layer === 0) {
            root.sourceA = component
            root.keyA = key
            root.stateA = state
        } else {
            root.sourceB = component
            root.keyB = key
            root.stateB = state
        }
    }

    function clearInactiveLayer() {
        if (root.currentLayer === 0) {
            root.sourceB = null
            root.keyB = ""
            root.stateB = null
        } else if (root.currentLayer === 1) {
            root.sourceA = null
            root.keyA = ""
            root.stateA = null
        }
    }

    function startNavigationAnimation(direction) {
        root.previousOpacity = 1
        root.nextOpacity = 0

        root.previousLeftX = 0
        root.previousCenterX = 0

        if (direction === "previous") {
            root.nextLeftX = 30
            root.nextCenterX = -30
        } else {
            root.nextLeftX = -30
            root.nextCenterX = 30
        }

        if (!root.animationsEnabled || !root.currentState || root.currentState.animate === false) {
            root.commitIncomingAsCurrent()
            return
        }

        transition.restart()
    }

    function commitIncomingAsCurrent() {
        if (root.nextLayer !== -1) {
            root.currentLayer = root.nextLayer
        }

        root.previousLayer = -1
        root.nextLayer = -1

        root.previousOpacity = 1
        root.nextOpacity = 0
        root.previousLeftX = 0
        root.previousCenterX = 0
        root.nextLeftX = 0
        root.nextCenterX = 0

        root.clearInactiveLayer()
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

    function layerLeftX(layer) {
        if (transition.running) {
            if (layer === root.previousLayer) {
                return root.previousLeftX
            }
            if (layer === root.nextLayer) {
                return root.nextLeftX
            }
        }

        return 0
    }

    function layerCenterX(layer) {
        if (transition.running) {
            if (layer === root.previousLayer) {
                return root.previousCenterX
            }
            if (layer === root.nextLayer) {
                return root.nextCenterX
            }
        }

        return 0
    }

    Loader {
        id: loaderA

        anchors.fill: parent
        active: root.sourceA !== null
        sourceComponent: root.sourceA
        opacity: root.layerOpacity(0)
        visible: active && opacity > 0.001
        z: root.nextLayer === 0 ? 2 : 1

        Binding {
            target: loaderA.item
            property: "leftTranslateX"
            value: root.layerLeftX(0)
            when: loaderA.item !== null
        }

        Binding {
            target: loaderA.item
            property: "centerTranslateX"
            value: root.layerCenterX(0)
            when: loaderA.item !== null
        }
    }

    Loader {
        id: loaderB

        anchors.fill: parent
        active: root.sourceB !== null
        sourceComponent: root.sourceB
        opacity: root.layerOpacity(1)
        visible: active && opacity > 0.001
        z: root.nextLayer === 1 ? 2 : 1

        Binding {
            target: loaderB.item
            property: "leftTranslateX"
            value: root.layerLeftX(1)
            when: loaderB.item !== null
        }

        Binding {
            target: loaderB.item
            property: "centerTranslateX"
            value: root.layerCenterX(1)
            when: loaderB.item !== null
        }
    }

    ParallelAnimation {
        id: transition

        NumberAnimation {
            target: root
            property: "previousOpacity"
            from: 1
            to: 0
            duration: root.duration / 2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclEaseCurve
        }

        NumberAnimation {
            target: root
            property: "previousLeftX"
            from: 0
            to: root.navigationDirection === "previous" ? 30 : -30
            duration: root.duration / 2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclEaseCurve
        }

        NumberAnimation {
            target: root
            property: "previousCenterX"
            from: 0
            to: root.navigationDirection === "previous" ? -30 : 30
            duration: root.duration / 2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclEaseCurve
        }

        SequentialAnimation {
            PauseAnimation {
                duration: root.duration / 2
            }

            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "nextOpacity"
                    from: 0
                    to: 1
                    duration: root.duration / 2
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.hmclEaseCurve
                }

                NumberAnimation {
                    target: root
                    property: "nextLeftX"
                    to: 0
                    duration: root.duration / 2
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.hmclEaseCurve
                }

                NumberAnimation {
                    target: root
                    property: "nextCenterX"
                    to: 0
                    duration: root.duration / 2
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.hmclEaseCurve
                }
            }
        }

        onFinished: {
            root.commitIncomingAsCurrent()
        }
    }
}
