import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

// Qt Quick port of HMCL TaskExecutorDialogPane + TaskListPane.
// Stage rows remain visible, while running file rows are inserted directly
// beneath their inherited stage with the same 26 px indentation as HMCL.
Rectangle {
    id: root

    required property var style
    property var status: ({})
    property bool activeTask: !!root.status.active
    property var stages: root.status.stages || []
    property var files: root.status.files || []
    property bool showTerminalMessage: true

    signal cancelRequested()
    signal closeRequested()

    radius: 4
    color: style.cSurfaceContainerHigh
    clip: true

    function formatBytes(value) {
        var bytes = Number(value || 0)
        if (bytes < 1024)
            return bytes.toFixed(0) + " B"
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KiB"
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MiB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB"
    }

    function formatSpeed(value) {
        if (root.status.speedText && String(root.status.speedText).length > 0)
            return String(root.status.speedText)
        return root.formatBytes(value) + "/s"
    }

    function stageTitle(stage) {
        var title = String(stage.title || "")
        var total = Number(stage.total || 0)
        var count = Number(stage.count || 0)
        return total > 0 ? title + " - " + count + "/" + total : title
    }

    function stageGlyph(stageStatus) {
        if (stageStatus === "running") return "→"
        if (stageStatus === "success" || stageStatus === "finished") return "✓"
        if (stageStatus === "failed") return "×"
        return "…"
    }

    function stageGlyphColor(stageStatus) {
        if (stageStatus === "failed") return "#F44336"
        return root.style.cTextOnSurface
    }

    function filesForStage(stageId) {
        var result = []
        for (var i = 0; i < root.files.length; ++i) {
            var file = root.files[i]
            if (String(file.stageId || "") === String(stageId || ""))
                result.push(file)
        }
        return result
    }

    function orphanFiles() {
        var result = []
        for (var i = 0; i < root.files.length; ++i) {
            var file = root.files[i]
            if (!file.stageId || String(file.stageId).length === 0)
                result.push(file)
        }
        return result
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: 16
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: root.status.title || "安装新游戏"
                color: root.style.cTextOnSurface
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }

            ScrollView {
                id: taskScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: taskColumn
                    width: taskScroll.availableWidth
                    spacing: 0

                    Repeater {
                        model: root.stages

                        delegate: Column {
                            id: stageBlock
                            required property var modelData
                            width: taskColumn.width
                            spacing: 0

                            Item {
                                width: stageBlock.width
                                height: 27

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    text: root.stageGlyph(stageBlock.modelData.status || "waiting")
                                    color: root.stageGlyphColor(stageBlock.modelData.status || "waiting")
                                    font.pixelSize: 15
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 26
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.stageTitle(stageBlock.modelData)
                                    color: root.style.cTextOnSurface
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            Repeater {
                                model: root.filesForStage(stageBlock.modelData.id || "")

                                delegate: Item {
                                    id: fileNode
                                    required property var modelData
                                    width: stageBlock.width
                                    height: 42

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 26
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        spacing: 5

                                        Text {
                                            width: parent.width
                                            text: fileNode.modelData.name || "下载文件"
                                            color: root.style.cTextOnSurface
                                            font.pixelSize: 12
                                            elide: Text.ElideMiddle
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 4
                                            color: Qt.rgba(root.style.cPrimary.r,
                                                           root.style.cPrimary.g,
                                                           root.style.cPrimary.b, 0.16)

                                            Rectangle {
                                                height: parent.height
                                                width: parent.width * Math.max(0, Math.min(100,
                                                       Number(fileNode.modelData.percent || 0))) / 100
                                                color: fileNode.modelData.status === "failed"
                                                       ? "#F44336" : root.style.cPrimary

                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: root.style.animationsEnabled ? 160 : 0
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.orphanFiles()

                        delegate: Item {
                            id: orphanNode
                            required property var modelData
                            width: taskColumn.width
                            height: 42

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 26
                                anchors.right: parent.right
                                spacing: 5

                                Text {
                                    width: parent.width
                                    text: orphanNode.modelData.name || "下载文件"
                                    color: root.style.cTextOnSurface
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    color: Qt.rgba(root.style.cPrimary.r,
                                                   root.style.cPrimary.g,
                                                   root.style.cPrimary.b, 0.16)
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * Math.max(0, Math.min(100,
                                               Number(orphanNode.modelData.percent || 0))) / 100
                                        color: root.style.cPrimary
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        width: taskColumn.width
                        height: 80
                        visible: root.stages.length === 0 && root.files.length === 0
                        text: root.status.message || "正在准备…"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: taskColumn.width
                        visible: root.showTerminalMessage
                                 && (root.status.status === "failed"
                                     || root.status.status === "cancelled")
                                 && root.stages.length > 0
                        text: root.status.message || (root.status.status === "cancelled"
                              ? "启动任务已取消。" : "启动失败。")
                        color: root.status.status === "failed"
                               ? "#D32F2F" : root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 6
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.bottomMargin: 0
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: root.activeTask ? (root.status.speedText || root.formatSpeed(root.status.speed || 0)) : ""
                color: root.style.cTextOnSurface
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Item {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 36

                Text {
                    anchors.centerIn: parent
                    text: root.activeTask && root.status.canCancel !== false ? "取消" : "关闭"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    z: 1
                }

                HmclRipple {
                    id: actionRipple
                    anchors.fill: parent
                    hoverColor: root.style.cTextOnSurface
                    rippleColor: root.style.cPrimary
                    hovered: actionMouse.containsMouse
                    animationsEnabled: root.style.animationsEnabled
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(event) { actionRipple.press(event.x, event.y) }
                    onReleased: actionRipple.release()
                    onCanceled: actionRipple.cancel()
                    onClicked: {
                        if (root.activeTask && root.status.canCancel !== false)
                            root.cancelRequested()
                        else
                            root.closeRequested()
                    }
                }
            }
        }
    }
}
