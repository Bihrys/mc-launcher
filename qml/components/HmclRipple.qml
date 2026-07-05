import QtQuick

Item {
    id: root

    // Qt 转写 HMCL RipplerContainer + JFXRippler。
    // 对应源码：
    //   org.jackhuang.hmcl.ui.construct.RipplerContainer
    //   com.jfoenix.controls.JFXRippler
    //   root.css: .rippler-container / .jfx-rippler
    // 行为：hover 产生 0.04 onSurface 覆盖层；按下从鼠标位置生成圆形扩散；释放后扩散到边界并淡出。
    property color hoverColor: "#000000"
    property color rippleColor: "#000000"
    property real hoverOpacity: 0.04
    property real overlayOpacity: 0.20
    property real rippleOpacity: 0.30
    property bool hovered: false
    property bool pressed: false
    property bool animationsEnabled: true
    property bool circularMask: false
    property int hoverDuration: 200      // Motion.SHORT4 近似
    property int overlayDuration: 300    // JFXRippler.OverLayRipple in/out
    property int rippleInDuration: 600   // JFXRippler.Ripple inAnimation
    property int rippleOutMaxDuration: 800

    property real originX: width / 2
    property real originY: height / 2
    property real rippleRadius: computeRippleRadius(originX, originY)

    anchors.fill: parent
    clip: true
    visible: width > 0 && height > 0

    function computeRippleRadius(x, y) {
        var dx = Math.max(x, width - x)
        var dy = Math.max(y, height - y)
        return Math.sqrt(dx * dx + dy * dy) / 0.9 + 2
    }

    function hmclCurve() {
        // JFXRippler.RIPPLE_INTERPOLATOR = SPLINE(0.0825, 0.3025, 0.0875, 0.9975)
        return [0.0825, 0.3025, 0.0875, 0.9975, 1.0, 1.0]
    }

    function press(x, y) {
        if (!root.animationsEnabled) {
            return
        }
        root.originX = x
        root.originY = y
        root.rippleRadius = root.computeRippleRadius(x, y)
        rippleInAnimation.stop()
        rippleOutAnimation.stop()
        overlayOutAnimation.stop()
        rippleCircle.x = root.originX - root.rippleRadius
        rippleCircle.y = root.originY - root.rippleRadius
        rippleCircle.width = root.rippleRadius * 2
        rippleCircle.height = root.rippleRadius * 2
        rippleCircle.radius = root.rippleRadius
        rippleCircle.opacity = root.rippleOpacity
        rippleCircle.scale = 0
        overlayCover.opacity = root.overlayOpacity
        root.pressed = true
        rippleInAnimation.start()
    }

    function release() {
        if (!root.animationsEnabled) {
            root.pressed = false
            rippleCircle.opacity = 0
            overlayCover.opacity = 0
            return
        }
        root.pressed = false
        rippleInAnimation.stop()
        rippleOutAnimation.stop()
        overlayOutAnimation.stop()
        rippleOutAnimation.duration = Math.min(root.rippleOutMaxDuration, (0.9 * 500) / Math.max(0.1, rippleCircle.scale))
        rippleOutAnimation.start()
        overlayOutAnimation.start()
    }

    function cancel() {
        release()
    }

    Rectangle {
        id: hoverCover
        anchors.fill: parent
        color: root.hoverColor
        opacity: root.hovered ? root.hoverOpacity : 0

        Behavior on opacity {
            enabled: root.animationsEnabled && !root.pressed
            NumberAnimation {
                duration: root.hoverDuration
                easing.type: root.hovered ? Easing.InCubic : Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: overlayCover
        anchors.fill: parent
        color: root.rippleColor
        opacity: 0
    }

    Rectangle {
        id: rippleCircle
        width: 1
        height: 1
        radius: width / 2
        color: root.rippleColor
        opacity: 0
        scale: 0
        transformOrigin: Item.Center
    }

    ParallelAnimation {
        id: rippleInAnimation
        NumberAnimation {
            target: rippleCircle
            property: "scale"
            from: 0
            to: 0.9
            duration: root.rippleInDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclCurve()
        }
    }

    ParallelAnimation {
        id: rippleOutAnimation
        property int duration: 450

        NumberAnimation {
            target: rippleCircle
            property: "scale"
            to: 1
            duration: rippleOutAnimation.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclCurve()
        }

        NumberAnimation {
            target: rippleCircle
            property: "opacity"
            to: 0
            duration: rippleOutAnimation.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hmclCurve()
        }

        onStopped: {
            if (!root.pressed) {
                rippleCircle.scale = 0
                rippleCircle.opacity = 0
            }
        }
    }

    NumberAnimation {
        id: overlayOutAnimation
        target: overlayCover
        property: "opacity"
        to: 0
        duration: root.overlayDuration
        easing.type: Easing.OutCubic
    }
}
