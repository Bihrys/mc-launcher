import QtQuick

Item {
    id: root

    default property alias contentData: content.data

    required property var style

    property bool active: false
    property int duration: style.motionShort4
    property int slideOffset: 30
    property bool animationsEnabled: style.animationsEnabled

    property bool initialized: false

    clip: true
    visible: root.active || enterAnimation.running || exitAnimation.running

    Item {
        id: content

        width: root.width
        height: root.height
        x: root.active ? 0 : root.slideOffset
        opacity: root.active ? 1 : 0
    }

    Component.onCompleted: {
        root.initialized = true

        if (root.active) {
            root.visible = true
            content.opacity = 1
            content.x = 0
        } else {
            root.visible = false
            content.opacity = 0
            content.x = root.slideOffset
        }
    }

    onActiveChanged: {
        if (!root.initialized) {
            return
        }

        enterAnimation.stop()
        exitAnimation.stop()

        if (!root.animationsEnabled) {
            root.visible = root.active
            content.opacity = root.active ? 1 : 0
            content.x = root.active ? 0 : root.slideOffset
            return
        }

        if (root.active) {
            root.visible = true
            content.opacity = 0
            content.x = root.slideOffset
            enterAnimation.restart()
        } else {
            content.opacity = 1
            content.x = 0
            exitAnimation.restart()
        }
    }

    SequentialAnimation {
        id: enterAnimation

        PauseAnimation {
            duration: root.duration / 2
        }

        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                from: 0
                to: 1
                duration: root.duration / 2
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: content
                property: "x"
                from: root.slideOffset
                to: 0
                duration: root.duration / 2
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: exitAnimation

        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                from: 1
                to: 0
                duration: root.duration / 2
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: content
                property: "x"
                from: 0
                to: root.slideOffset
                duration: root.duration / 2
                easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                if (!root.active) {
                    root.visible = false
                    content.opacity = 0
                    content.x = root.slideOffset
                }
            }
        }
    }
}
