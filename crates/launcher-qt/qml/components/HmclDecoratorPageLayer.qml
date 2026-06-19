import QtQuick

Item {
    id: root

    required property var style

    property bool active: false
    property real leftWidth: 0
    property Component leftComponent: null
    property Component centerComponent: null

    property int duration: style.motionShort4
    property bool animationsEnabled: style.animationsEnabled

    property bool initialized: false
    property real pageOpacity: active ? 1 : 0
    property real leftX: 0
    property real centerX: 0

    readonly property var hmclEaseCurve: [
        0.25, 0.1,
        0.25, 1.0,
        1.0, 1.0
    ]

    anchors.fill: parent
    visible: active || enterAnimation.running || exitAnimation.running
    opacity: pageOpacity
    clip: true
    z: active ? 10 : 1

    Loader {
        id: leftLoader

        x: root.leftX
        y: 0
        width: root.leftWidth
        height: root.height
        visible: root.leftWidth > 0
        active: root.leftComponent !== null && root.leftWidth > 0
        sourceComponent: root.leftComponent
    }

    Loader {
        id: centerLoader

        x: root.leftWidth + root.centerX
        y: 0
        width: Math.max(1, root.width - root.leftWidth)
        height: root.height
        active: root.centerComponent !== null
        sourceComponent: root.centerComponent
    }

    Component.onCompleted: {
        root.initialized = true

        if (root.active) {
            root.pageOpacity = 1
            root.leftX = 0
            root.centerX = 0
            root.visible = true
        } else {
            root.pageOpacity = 0
            root.leftX = -30
            root.centerX = 30
            root.visible = false
        }
    }

    onActiveChanged: {
        if (!root.initialized) {
            return
        }

        enterAnimation.stop()
        exitAnimation.stop()

        if (!root.animationsEnabled) {
            root.pageOpacity = root.active ? 1 : 0
            root.leftX = 0
            root.centerX = 0
            root.visible = root.active
            return
        }

        if (root.active) {
            root.visible = true
            root.pageOpacity = 0
            root.leftX = -30
            root.centerX = 30
            enterAnimation.restart()
        } else {
            root.pageOpacity = 1
            root.leftX = 0
            root.centerX = 0
            exitAnimation.restart()
        }
    }

    SequentialAnimation {
        id: enterAnimation

        // HMCL NAVIGATION:
        // nextNode opacity 在前半段保持 0。
        PauseAnimation {
            duration: root.duration / 2
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "pageOpacity"
                from: 0
                to: 1
                duration: root.duration / 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.hmclEaseCurve
            }

            NumberAnimation {
                target: root
                property: "leftX"
                from: -30
                to: 0
                duration: root.duration / 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.hmclEaseCurve
            }

            NumberAnimation {
                target: root
                property: "centerX"
                from: 30
                to: 0
                duration: root.duration / 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.hmclEaseCurve
            }
        }
    }

    SequentialAnimation {
        id: exitAnimation

        ParallelAnimation {
            // HMCL NAVIGATION:
            // previousNode opacity 在前半段 1 -> 0。
            NumberAnimation {
                target: root
                property: "pageOpacity"
                from: 1
                to: 0
                duration: root.duration / 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.hmclEaseCurve
            }

            NumberAnimation {
                target: root
                property: "leftX"
                from: 0
                to: -30
                duration: root.duration / 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.hmclEaseCurve
            }

            NumberAnimation {
                target: root
                property: "centerX"
                from: 0
                to: 30
                duration: root.duration / 2
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.hmclEaseCurve
            }
        }

        ScriptAction {
            script: {
                if (!root.active) {
                    root.visible = false
                    root.pageOpacity = 0
                    root.leftX = -30
                    root.centerX = 30
                }
            }
        }
    }
}
