import QtQuick

Item {
    id: root

    required property var style

    property bool active: false
    property bool loaded: false
    property bool initialized: false
    property Component sourceComponent
    property int duration: 400
    property bool animationsEnabled: style.animationsEnabled

    readonly property real enterOffset: parent && parent.height > 0 ? parent.height * 0.2 : 50
    readonly property real contentHeight: loader.item
                                          ? Math.max(loader.item.implicitHeight, loader.item.height)
                                          : 0

    property bool layerVisible: active
    property real contentOpacity: active ? 1 : 0
    property real contentY: 0

    visible: layerVisible
    width: parent ? parent.width : 0
    height: contentHeight

    Component.onCompleted: {
        root.initialized = true
        root.loaded = root.active
        root.layerVisible = root.active
        root.contentOpacity = root.active ? 1 : 0
        root.contentY = 0
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
            // 新内容前半段保持透明，后半段从下方向上滑入。
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

            // HMCL SLIDE_UP_FADE_IN:
            // 旧内容只淡出，不做 translateY。
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

        onLoaded: {
            if (root.active) {
                root.contentOpacity = root.animationsEnabled ? root.contentOpacity : 1
                root.contentY = root.animationsEnabled ? root.contentY : 0
            }
        }
    }

    SequentialAnimation {
        id: enterAnimation

        PauseAnimation {
            duration: root.duration / 2
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "contentOpacity"
                from: 0
                to: 1
                duration: root.duration / 2
                easing.type: Easing.InOutCubic
            }

            NumberAnimation {
                target: root
                property: "contentY"
                from: root.enterOffset
                to: 0
                duration: root.duration / 2
                easing.type: Easing.InOutCubic
            }
        }
    }

    SequentialAnimation {
        id: exitAnimation

        NumberAnimation {
            target: root
            property: "contentOpacity"
            from: 1
            to: 0
            duration: root.duration / 2
            easing.type: Easing.InOutCubic
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
