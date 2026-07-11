import QtQuick

Item {
        id: spinner

        required property var style
        property bool running: true
        property real startAngle: 45
        property real arcLength: 5
        property real strokeWidth: 4

        implicitWidth: 50
        implicitHeight: 50

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width
                var h = height
                var sw = spinner.strokeWidth
                var radius = Math.max(1, Math.min(w, h) / 2 - sw)
                var cx = w / 2
                var cy = h / 2
                var start = (spinner.startAngle - 90) * Math.PI / 180
                var span = Math.max(1, spinner.arcLength) * Math.PI / 180

                ctx.lineWidth = sw
                ctx.lineCap = "round"
                ctx.strokeStyle = spinner.style.cPrimaryContainer
                ctx.beginPath()
                ctx.arc(cx, cy, radius, start, start + span, false)
                ctx.stroke()
            }
        }

        onStartAngleChanged: canvas.requestPaint()
        onArcLengthChanged: canvas.requestPaint()
        onVisibleChanged: canvas.requestPaint()
        onWidthChanged: canvas.requestPaint()
        onHeightChanged: canvas.requestPaint()

        SequentialAnimation {
            running: spinner.running && spinner.visible && spinner.style.animationsEnabled
            loops: Animation.Infinite

            ParallelAnimation {
                NumberAnimation { target: spinner; property: "arcLength"; from: 5; to: 250; duration: 400; easing.type: Easing.Linear }
                NumberAnimation { target: spinner; property: "startAngle"; from: 45; to: 90; duration: 400; easing.type: Easing.Linear }
            }
            PauseAnimation { duration: 300 }
            ParallelAnimation {
                NumberAnimation { target: spinner; property: "arcLength"; from: 250; to: 5; duration: 400; easing.type: Easing.Linear }
                NumberAnimation { target: spinner; property: "startAngle"; from: 90; to: 435; duration: 400; easing.type: Easing.Linear }
            }
            ParallelAnimation {
                NumberAnimation { target: spinner; property: "arcLength"; from: 5; to: 250; duration: 400; easing.type: Easing.Linear }
                NumberAnimation { target: spinner; property: "startAngle"; from: 495; to: 540; duration: 400; easing.type: Easing.Linear }
            }
            PauseAnimation { duration: 300 }
            ParallelAnimation {
                NumberAnimation { target: spinner; property: "arcLength"; from: 250; to: 5; duration: 400; easing.type: Easing.Linear }
                NumberAnimation { target: spinner; property: "startAngle"; from: 540; to: 885; duration: 400; easing.type: Easing.Linear }
            }
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 5600
            loops: Animation.Infinite
            running: spinner.running && spinner.visible && !spinner.style.animationsEnabled
        }
    }
