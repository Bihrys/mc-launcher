import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var style
    property bool autoMemory: true
    property int maxMemoryMb: 2048
    property int minMemoryMb: 256
    property real usedGiB: 12.9
    property real totalGiB: 31.2
    signal autoMemoryChangedByUser(bool value)
    signal maxMemoryChangedByUser(int value)

    width: parent ? parent.width : 800
    implicitHeight: 170
    height: implicitHeight
    color: root.styleValue("cSurface", "#FFFBFE")

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: root.styleValue("cBorder", "#D9D7E2")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 10

        Text {
            text: "游戏内存"
            color: root.styleValue("cTextOnSurface", "#1B1B21")
            font.pixelSize: 13
        }

        RowLayout {
            spacing: 8
            HmclCheckBox {
                style: root.style
                checked: root.autoMemory
                onToggled: function(value) { root.autoMemoryChangedByUser(value) }
            }
            Text {
                text: "自动分配内存"
                color: root.styleValue("cTextOnSurface", "#1B1B21")
                font.pixelSize: 13
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: "最低内存分配"
                color: root.styleValue("cTextOnSurface", "#1B1B21")
                font.pixelSize: 13
                Layout.preferredWidth: 96
            }
            HmclMemorySlider {
                id: memorySlider
                Layout.fillWidth: true
                style: root.style
                from: 512
                to: Math.max(1024, Math.round(root.totalGiB * 1024))
                stepSize: 128
                enabledControl: !root.autoMemory
                value: root.maxMemoryMb
                onMoved: function(value) { root.maxMemoryChangedByUser(Math.round(value)) }
            }
            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 34
                radius: 3
                color: root.styleValue("cSurfaceContainerHigh", "#ECE9F1")
                Text {
                    anchors.centerIn: parent
                    text: String(root.maxMemoryMb)
                    color: root.styleValue("cTextOnSurface", "#1B1B21")
                    font.pixelSize: 12
                }
            }
            Text { text: "MiB"; font.pixelSize: 12; color: root.styleValue("cTextOnSurface", "#1B1B21") }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: root.styleValue("cSecondaryContainer", "#C6C5DD")
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.min(1, (root.usedGiB + root.maxMemoryMb / 1024.0) / Math.max(0.1, root.totalGiB))
                radius: 2
                color: root.styleValue("cLaunchButton", "#4352A5")
                opacity: 0.50
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.min(1, root.usedGiB / Math.max(0.1, root.totalGiB))
                radius: 2
                color: root.styleValue("cLaunchButton", "#4352A5")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "已使用 " + root.usedGiB.toFixed(1) + " GiB / 总内存 " + root.totalGiB.toFixed(1) + " GiB"
                color: root.styleValue("cTextOnSurface", "#1B1B21")
                font.pixelSize: 12
            }
            Text {
                text: "最低分配 " + (root.minMemoryMb / 1024.0).toFixed(1) + " GiB / 实际分配 " + (root.maxMemoryMb / 1024.0).toFixed(1) + " GiB"
                color: root.styleValue("cTextOnSurface", "#1B1B21")
                font.pixelSize: 12
            }
        }
    }
}
