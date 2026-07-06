import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls" as HmclControls

Rectangle {
    id: root

    required property var style
    property var status: ({})
    property bool activeTask: !!root.status.active
    property var stages: root.status.stages || []

    signal cancelRequested()
    signal closeRequested()

    radius: 4
    color: style.cSurfaceContainerHigh
    border.color: style.cBorder
    border.width: 1
    clip: true

    function formatBytes(v) {
        var n = Number(v || 0)
        if (n <= 0) return "0 B"
        var units = ["B", "KB", "MB", "GB"]
        var idx = 0
        while (n >= 1024 && idx < units.length - 1) {
            n = n / 1024
            idx++
        }
        return n.toFixed(idx === 0 ? 0 : 1) + " " + units[idx]
    }

    function formatSpeed(v) {
        if (root.status.speedText && String(root.status.speedText).length > 0)
            return String(root.status.speedText)
        return formatBytes(v) + "/s"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            text: root.status.title || "下载任务"
            color: root.style.cTextOnSurface
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
        }

        ListView {
            id: taskListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: root.stages

            delegate: Item {
                required property var modelData
                required property int index
                width: taskListView.width
                height: stageRow.implicitHeight + stageBar.height + 6

                RowLayout {
                    id: stageRow
                    width: parent.width
                    height: 24
                    spacing: 8

                    Item {
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter

                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var s = modelData.status || "waiting"
                                var color = s === "running" ? root.style.cPrimary
                                          : s === "success" ? "#4CAF50"
                                          : s === "failed" ? "#F44336"
                                          : root.style.cTextOnSurfaceVariant
                                ctx.fillStyle = color
                                ctx.font = "bold 12px sans-serif"
                                ctx.textAlign = "center"
                                ctx.textBaseline = "middle"
                                var icon = s === "running" ? "▶"
                                         : s === "success" ? "✔"
                                         : s === "failed" ? "✖"
                                         : "•••"
                                ctx.fillText(icon, 7, 7)
                            }
                            Component.onCompleted: requestPaint()
                            Connections {
                                target: modelData ? null : null
                                function onStatusChanged() { requestPaint() }
                            }
                            Timer {
                                interval: 500
                                running: true
                                repeat: true
                                onTriggered: parent.requestPaint()
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: {
                            var title = modelData.title || ""
                            var total = modelData.total || 0
                            var count = modelData.count || 0
                            if (total > 0)
                                return title + " - " + count + "/" + total
                            return title
                        }
                        color: root.style.cTextOnSurface
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: stageBar
                    anchors.top: stageRow.bottom
                    anchors.topMargin: 2
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.right: parent.right
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(root.style.cTextOnSurface.r, root.style.cTextOnSurface.g, root.style.cTextOnSurface.b, 0.08)
                    visible: (modelData.status || "waiting") === "running"

                    Rectangle {
                        height: parent.height
                        radius: 1.5
                        width: {
                            var total = modelData.total || 0
                            var count = modelData.count || 0
                            if (total <= 0) return 0
                            return parent.width * Math.min(1.0, count / total)
                        }
                        color: root.style.cPrimary

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: root.stages.length === 0 && root.activeTask
                text: root.status.message || "正在准备…"
                color: root.style.cTextOnSurfaceVariant
                font.pixelSize: 12
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            color: root.style.cBorder
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: root.activeTask ? root.formatSpeed(root.status.speed || 0) : ""
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                }

                Label {
                    Layout.fillWidth: true
                    text: {
                        if (!root.activeTask) {
                            if (root.status.status === "finished") return "安装完成"
                            if (root.status.status === "failed") return root.status.message || "安装失败"
                            if (root.status.status === "cancelled") return "已取消"
                            return ""
                        }
                        var finished = root.status.finishedFiles || 0
                        var total = root.status.totalFiles || 0
                        var bytes = root.formatBytes(root.status.downloadedBytes || 0)
                        var totalB = root.formatBytes(root.status.totalBytes || 0)
                        return finished + "/" + total + " 文件  " + bytes + "/" + totalB
                    }
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                radius: 3
                color: cancelMouse.containsMouse ? root.style.cButtonHover : root.style.cButtonSurface

                Label {
                    anchors.centerIn: parent
                    text: root.activeTask ? "取消" : "关闭"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 12
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.activeTask)
                            root.cancelRequested()
                        else
                            root.closeRequested()
                    }
                }
            }
        }
    }
}
