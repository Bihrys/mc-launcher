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
    property bool developmentPending: false
    signal autoMemoryChangedByUser(bool value)
    signal maxMemoryChangedByUser(int value)

    width: parent ? parent.width : 800
    implicitHeight: 170
    height: implicitHeight
    color: root.styleValue("cSurface", "#FFFBFE")
    enabled: !root.developmentPending
    opacity: root.developmentPending ? 0.72 : 1.0

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

        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Text {
                Layout.fillWidth: true
                text: "游戏内存"
                color: root.styleValue("cTextOnSurface", "#1B1B21")
                font.pixelSize: 13
            }
            Rectangle {
                visible: root.developmentPending
                Layout.preferredWidth: memoryPendingLabel.implicitWidth + 10
                Layout.preferredHeight: 20
                radius: 10
                color: root.styleValue("cSurfaceContainerHigh", "#ECE9F1")
                border.width: 1
                border.color: root.styleValue("cBorder", "#D9D7E2")
                Text {
                    id: memoryPendingLabel
                    anchors.centerIn: parent
                    text: "待开发"
                    color: root.styleValue("cTextOnSurfaceVariant", "#454651")
                    font.pixelSize: 10
                }
            }
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
                id: memoryField
                Layout.preferredWidth: 60
                Layout.preferredHeight: 34
                radius: 3
                color: root.styleValue("cSurfaceContainerHigh", "#ECE9F1")
                opacity: root.autoMemory ? 0.55 : 1.0

                TextInput {
                    id: memoryInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    enabled: !root.autoMemory
                    selectByMouse: true
                    validator: IntValidator { bottom: 512; top: Math.max(1024, Math.round(root.totalGiB * 1024)) }
                    text: String(root.maxMemoryMb)
                    color: root.styleValue("cTextOnSurface", "#1B1B21")
                    font.pixelSize: 12
                    onEditingFinished: {
                        var v = parseInt(text)
                        if (!isNaN(v))
                            root.maxMemoryChangedByUser(v)
                        else
                            text = String(root.maxMemoryMb)
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: root.styleValue("cBorder", "#D9D7E2")
                }

                Rectangle {
                    id: activeUnderline
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    height: 2
                    width: memoryInput.activeFocus ? parent.width : 0
                    color: root.styleValue("cLaunchButton", "#4352A5")
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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
