import QtQuick

Item {
    id: root

    required property var style

    property bool active: false
    property bool loaded: false
    property bool initialized: false
    property Component sourceComponent

    // HMCL TabHeader 使用 Motion.MEDIUM4 = 400ms。
    // 但它的曲线是 EASE_IN_OUT_CUBIC_EMPHASIZED，视觉上会很快进入主体。
    property int duration: 400
    property bool animationsEnabled: style.animationsEnabled

    readonly property real enterOffset: parent && parent.height > 0 ? parent.height * 0.2 : 50
    readonly property real contentHeight: loader.item
                                          ? Math.max(loader.item.implicitHeight, loader.item.height)
                                          : 0

    property bool layerVisible: active
    property real contentOpacity: active ? 1 : 0
    property real contentY: active ? 0 : enterOffset

    visible: layerVisible
    width: parent ? parent.width : 0
    height: contentHeight

    Component.onCompleted: {
        root.initialized = true
        root.loaded = root.active
        root.layerVisible = root.active
        root.contentOpacity = root.active ? 1 : 0
        root.contentY = root.active ? 0 : root.enterOffset
    }

    onActiveChanged: {
        if (!root.initialized) {
            return
        }

        enterAnimation.stop()
        exitAnimation.stop()

        if (root.active) {
            root.loaded = true
            root.layerVisible = true

            if (!root.animationsEnabled) {
                root.contentOpacity = 1
                root.contentY = 0
                return
            }

            // HMCL SLIDE_UP_FADE_IN:
            // 新内容从 0ms 开始滑入，不等待旧内容淡出。
            root.contentOpacity = 0
            root.contentY = root.enterOffset
            enterAnimation.restart()
        } else {
            if (!root.layerVisible) {
                return
            }

            if (!root.animationsEnabled) {
                root.contentOpacity = 0
                root.contentY = 0
                root.layerVisible = false
                return
            }

            // 旧内容只做前半段淡出，不上滑。
            root.contentOpacity = 1
            root.contentY = 0
            exitAnimation.restart()
        }
    }

    Loader {
        id: loader

        active: root.loaded
        asynchronous: true
        sourceComponent: root.sourceComponent
        width: root.width
        opacity: root.contentOpacity
        y: root.contentY
    }

    // 对应 HMCL:
    // KeyFrame(0): next opacity 0, translateY offset
    // KeyFrame(duration): next opacity 1, translateY 0
    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "contentOpacity"
            from: 0
            to: 1
            duration: root.animationsEnabled ? root.duration : 0
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "contentY"
            from: root.enterOffset
            to: 0
            duration: root.animationsEnabled ? root.duration : 0
            easing.type: Easing.OutCubic
        }
    }

    // 对应 HMCL:
    // KeyFrame(0): previous opacity 1
    // KeyFrame(duration * 0.5): previous opacity 0
    SequentialAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "contentOpacity"
            from: 1
            to: 0
            duration: root.animationsEnabled ? root.duration / 2 : 0
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: {
                if (!root.active) {
                    root.layerVisible = false
                    root.contentOpacity = 0
                    root.contentY = 0
                }
            }
        }
    }
}
