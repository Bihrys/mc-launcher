import QtQuick

Item {
    id: root

    property var style
    property real from: 0
    property real to: 1
    property real stepSize: 1
    property real value: 0
    property bool enabledControl: true
    signal moved(real value)

    implicitWidth: 220
    implicitHeight: 24
    opacity: enabledControl ? 1.0 : 0.40

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var v = root.style[name]
            if (v !== undefined && v !== null)
                return v
        }
        return fallback
    }

    function ratio() {
        if (root.to <= root.from)
            return 0
        return Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))
    }

    function valueFromX(x) {
        var r = Math.max(0, Math.min(1, x / Math.max(1, track.width)))
        var raw = root.from + r * (root.to - root.from)
        if (root.stepSize > 0)
            raw = Math.round(raw / root.stepSize) * root.stepSize
        return Math.max(root.from, Math.min(root.to, raw))
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 2
        radius: 1
        color: root.styleValue("cSecondaryContainer", "#C6C5DD")

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.ratio()
            height: 2
            radius: 1
            color: root.styleValue("cLaunchButton", "#4352A5")
        }
    }

    Rectangle {
        id: thumb
        width: 12
        height: 12
        radius: 6
        x: track.x + track.width * root.ratio() - width / 2
        y: track.y + track.height / 2 - height / 2
        color: root.styleValue("cLaunchButton", "#4352A5")

        Behavior on x {
            enabled: !dragArea.drag.active
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.enabledControl
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) {
            root.value = root.valueFromX(mouse.x)
            root.moved(root.value)
        }
        onPositionChanged: function(mouse) {
            if (pressed) {
                root.value = root.valueFromX(mouse.x)
                root.moved(root.value)
            }
        }
    }
}
