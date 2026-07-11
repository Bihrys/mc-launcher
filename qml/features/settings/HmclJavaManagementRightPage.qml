import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl

Column {
    id: root

    property var style
    property var backend
    property var settingsPage

    property var javaItems: []
    property var disabledItems: []
    property bool loading: false
    property bool showDisabled: false
    property string taskTitle: ""
    property string taskMessage: ""
    property string pendingPath: ""
    property bool pendingManaged: false

    width: parent ? parent.width : 800
    spacing: 10

    function logAction(action, details) {
        if (root.backend)
            root.backend.logUiAction("ui.settings.java", action, JSON.stringify(details || {}))
    }

    function applyJavaPayload(raw, origin) {
        if (!raw || raw.length === 0)
            return
        try {
            var obj = JSON.parse(raw)
            root.javaItems = obj.runtimes || []
            root.disabledItems = obj.disabled || []
            root.logAction("java_payload_applied", {
                "origin": origin,
                "runtimeCount": root.javaItems.length,
                "disabledCount": root.disabledItems.length
            })
        } catch (e) {
            root.logAction("java_payload_parse_failed", {
                "origin": origin,
                "error": String(e),
                "rawLength": raw.length
            })
        }
    }

    function beginTracking() {
        root.loading = true
        javaPollTimer.restart()
        root.pollJava()
    }

    function refreshJava() {
        root.logAction("refresh_requested", {})
        root.backend.startDetectJava()
        root.beginTracking()
    }

    function pollJava() {
        var raw = root.backend.pollJavaTask()
        if (!raw || raw.length === 0)
            return
        try {
            var obj = JSON.parse(raw)
            root.loading = obj.active === true
            root.taskTitle = String(obj.title || "")
            root.taskMessage = String(obj.message || "")
            if (obj.runtimes !== undefined && obj.active !== true) {
                root.javaItems = obj.runtimes || []
                root.disabledItems = obj.disabled || []
            }
            if (!root.loading)
                javaPollTimer.stop()
        } catch (e) {
            root.loading = false
            javaPollTimer.stop()
            root.logAction("java_task_parse_failed", {
                "error": String(e),
                "rawLength": raw.length
            })
        }
    }

    function confirmRemove(path, managed) {
        root.pendingPath = path
        root.pendingManaged = managed
        removeConfirmDialog.open()
    }

    function executePendingRemove() {
        if (root.pendingPath.length === 0)
            return
        if (root.pendingManaged)
            root.backend.uninstallManagedJava(root.pendingPath)
        else
            root.backend.disableJava(root.pendingPath)
        root.beginTracking()
        root.pendingPath = ""
    }

    function localUrl(value) {
        return String(value || "")
    }

    Component.onCompleted: {
        root.logAction("panel_completed", {})
        root.applyJavaPayload(root.backend.detectedJavaJson, "initial_property")
        root.refreshJava()
    }

    Connections {
        target: root.backend
        ignoreUnknownSignals: true

        function onDetectedJavaJsonChanged() {
            root.applyJavaPayload(root.backend.detectedJavaJson, "backend_signal")
        }
    }

    Timer {
        id: javaPollTimer
        interval: 200
        repeat: true
        running: false
        onTriggered: root.pollJava()
    }

    FileDialog {
        id: javaExecutableDialog
        title: "选择 Java 可执行文件"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Java 可执行文件 (java java.exe)", "所有文件 (*)"]
        onAccepted: {
            root.backend.addJavaPath(root.localUrl(selectedFile))
            root.beginTracking()
        }
    }

    FolderDialog {
        id: javaHomeDialog
        title: "选择 Java 主目录"
        onAccepted: {
            root.backend.addJavaPath(root.localUrl(selectedFolder))
            root.beginTracking()
        }
    }

    FileDialog {
        id: javaArchiveDialog
        title: "选择 Java 压缩包"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Java 压缩包 (*.zip *.tar.gz *.tgz *.tar.xz)", "所有文件 (*)"]
        onAccepted: {
            root.backend.installJavaArchive(root.localUrl(selectedFile))
            root.beginTracking()
        }
    }

    Dialog {
        id: addJavaDialog
        parent: Overlay.overlay
        modal: true
        title: "添加 Java"
        width: 360
        standardButtons: Dialog.Close

        ColumnLayout {
            width: parent.width
            spacing: 8

            Button {
                Layout.fillWidth: true
                text: "选择 Java 可执行文件"
                onClicked: {
                    addJavaDialog.close()
                    javaExecutableDialog.open()
                }
            }
            Button {
                Layout.fillWidth: true
                text: "选择 Java 主目录"
                onClicked: {
                    addJavaDialog.close()
                    javaHomeDialog.open()
                }
            }
            Button {
                Layout.fillWidth: true
                text: "从本地压缩包安装"
                onClicked: {
                    addJavaDialog.close()
                    javaArchiveDialog.open()
                }
            }
        }
    }

    Dialog {
        id: downloadJavaDialog
        parent: Overlay.overlay
        modal: true
        title: "下载 Java"
        width: 400
        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: 10

            Label { text: "发行版" }
            ComboBox {
                id: distributionCombo
                Layout.fillWidth: true
                model: ["temurin", "zulu", "liberica", "corretto", "microsoft"]
            }

            Label { text: "主版本" }
            ComboBox {
                id: majorCombo
                Layout.fillWidth: true
                model: ["8", "11", "17", "21", "25", "26"]
                currentIndex: 3
            }

            Label { text: "包类型" }
            ComboBox {
                id: packageCombo
                Layout.fillWidth: true
                model: ["JRE", "JDK"]
            }
        }

        onAccepted: {
            root.backend.downloadJava(distributionCombo.currentText,
                                      majorCombo.currentText,
                                      packageCombo.currentText.toLowerCase())
            root.beginTracking()
        }
    }

    Dialog {
        id: removeConfirmDialog
        parent: Overlay.overlay
        modal: true
        title: root.pendingManaged ? "卸载 Java" : "禁用 Java"
        standardButtons: Dialog.Ok | Dialog.Cancel

        Label {
            width: 420
            wrapMode: Text.WordWrap
            text: root.pendingManaged
                  ? "该 Java 由启动器管理。确认后将删除整个安装目录。\n\n" + root.pendingPath
                  : "系统或用户 Java 不会被删除，只会加入禁用列表。可在“已禁用”中恢复。\n\n" + root.pendingPath
        }

        onAccepted: root.executePendingRemove()
        onRejected: root.pendingPath = ""
    }

    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        radiusValue: 4

        Item {
            width: parent ? parent.width : 800
            height: 48

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Hmcl.ToolbarButton {
                    style: root.style
                    text: root.showDisabled ? "返回" : "刷新"
                    iconKind: root.showDisabled ? "ARROW_BACK" : "REFRESH"
                    onClicked: {
                        if (root.showDisabled)
                            root.showDisabled = false
                        else
                            root.refreshJava()
                    }
                }
                Hmcl.ToolbarButton {
                    visible: !root.showDisabled
                    style: root.style
                    text: "下载"
                    iconKind: "DOWNLOAD"
                    onClicked: downloadJavaDialog.open()
                }
                Hmcl.ToolbarButton {
                    visible: !root.showDisabled
                    style: root.style
                    text: "添加"
                    iconKind: "ADD"
                    onClicked: addJavaDialog.open()
                }
                Hmcl.ToolbarButton {
                    visible: !root.showDisabled
                    style: root.style
                    text: "已禁用" + (root.disabledItems.length > 0 ? " (" + root.disabledItems.length + ")" : "")
                    iconKind: "FORMAT_LIST_BULLETED"
                    onClicked: root.showDisabled = true
                }
            }
        }

        Item {
            width: parent ? parent.width : 800
            height: Math.max(220, contentColumn.implicitHeight)

            Column {
                id: contentColumn
                width: parent.width
                visible: !root.loading

                Repeater {
                    model: root.showDisabled ? root.disabledItems : root.javaItems

                    delegate: Item {
                        id: rowDelegate
                        required property var modelData
                        width: contentColumn.width
                        height: root.showDisabled ? 56 : 64

                        HmclJavaCell {
                            anchors.fill: parent
                            visible: !root.showDisabled
                            style: root.style
                            version: String(rowDelegate.modelData.version || "")
                            major: Number(rowDelegate.modelData.major || -1)
                            vendor: String(rowDelegate.modelData.vendor || rowDelegate.modelData.vendorHint || "")
                            architecture: String(rowDelegate.modelData.architecture || "")
                            path: String(rowDelegate.modelData.path || "")
                            home: String(rowDelegate.modelData.home || "")
                            managed: rowDelegate.modelData.managed === true
                            isJdk: rowDelegate.modelData.isJdk === true
                            onReveal: function(path) { root.backend.revealJava(path) }
                            onRemoveRequested: function(path, managed) { root.confirmRemove(path, managed) }
                        }

                        Item {
                            anchors.fill: parent
                            visible: root.showDisabled

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: root.style.cBorder
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: String(rowDelegate.modelData.path || "")
                                        color: root.style.cTextOnSurface
                                        font.pixelSize: 12
                                        elide: Text.ElideMiddle
                                    }
                                    Text {
                                        text: rowDelegate.modelData.exists === true ? "已禁用" : "文件已不存在"
                                        color: root.style.cTextOnSurfaceVariant
                                        font.pixelSize: 11
                                    }
                                }

                                Hmcl.ToolbarButton {
                                    style: root.style
                                    iconKind: "FOLDER_OPEN"
                                    enabledButton: rowDelegate.modelData.exists === true
                                    onClicked: root.backend.revealJava(String(rowDelegate.modelData.realPath || rowDelegate.modelData.path || ""))
                                }

                                Hmcl.ToolbarButton {
                                    style: root.style
                                    iconKind: rowDelegate.modelData.exists === true ? "REFRESH" : "DELETE_FOREVER"
                                    onClicked: {
                                        var path = String(rowDelegate.modelData.path || "")
                                        if (rowDelegate.modelData.exists === true)
                                            root.backend.restoreJava(path)
                                        else
                                            root.backend.removeDisabledJava(path)
                                        root.beginTracking()
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 96
                    visible: (root.showDisabled ? root.disabledItems.length : root.javaItems.length) === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.showDisabled ? "没有被禁用的 Java" : "未检测到可用 Java"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                }
            }

            Hmcl.SpinnerPane {
                anchors.centerIn: parent
                width: 64
                height: 64
                style: root.style
                running: root.loading
                visible: root.loading
            }

            DropArea {
                id: javaDropArea
                anchors.fill: parent
                enabled: !root.loading && !root.showDisabled
                z: 20

                onDropped: function(drop) {
                    if (!drop.urls || drop.urls.length === 0)
                        return
                    var value = String(drop.urls[0])
                    var lower = value.toLowerCase()
                    if (lower.endsWith(".zip") || lower.endsWith(".tar.gz")
                            || lower.endsWith(".tgz") || lower.endsWith(".tar.xz"))
                        root.backend.installJavaArchive(value)
                    else
                        root.backend.addJavaPath(value)
                    root.logAction("java_drop_received", {"archive": lower.indexOf(".tar") >= 0 || lower.endsWith(".zip")})
                    root.beginTracking()
                    drop.acceptProposedAction()
                }

                Rectangle {
                    anchors.fill: parent
                    visible: javaDropArea.containsDrag
                    color: "#22000000"
                    border.width: 2
                    border.color: root.style.cButtonSelected
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "拖放 Java 主目录、可执行文件或压缩包"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 14
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 42
                visible: root.loading
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.taskTitle
                    color: root.style.cTextOnSurface
                    font.pixelSize: 13
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.taskMessage
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                }
            }
        }
    }

}
