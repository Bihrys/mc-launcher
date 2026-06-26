import QtQuick
import QtQuick.Controls
Item {
    id: root
    required property var style
    property bool running: true
    implicitWidth: 64
    implicitHeight: 64
    Canvas {
        id: canvas
        anchors.centerIn: parent
        width: 42
        height: 42
        rotation: 0
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.beginPath()
            ctx.lineWidth = 3
            ctx.strokeStyle = root.style.cLaunchButton
            ctx.arc(width / 2, height / 2, 15, Math.PI * 0.05, Math.PI * 1.45)
            ctx.stroke()
        }
        NumberAnimation on rotation { running: root.running && root.visible; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        Timer { interval: 80; running: root.running && root.visible; repeat: true; onTriggered: canvas.requestPaint() }
    }
}
