import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl

Column {
    id: root
    property var style
    property var backend
    property var settingsPage
    property var javaItems: []
    property bool loading: false
    width: parent ? parent.width : 800
    spacing: 10

    function logAction(action, details) {
        if (root.backend)
            root.backend.logUiAction("ui.settings.java", action, JSON.stringify(details || {}))
    }

    Component.onCompleted: {
        root.logAction("panel_completed", {})
        refreshJava()
    }

    Timer {
        id: javaPollTimer
        interval: 250
        repeat: true
        running: false
        onTriggered: root.pollJava()
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
                Hmcl.ToolbarButton { style: root.style; text: "刷新"; iconKind: "REFRESH"; onClicked: root.refreshJava() }
                Hmcl.ToolbarButton { style: root.style; text: "下载"; iconKind: "DOWNLOAD"; onClicked: root.backend.downloadJava("temurin", "21", "jre") }
                Hmcl.ToolbarButton { style: root.style; text: "添加（待开发）"; iconKind: "ADD"; enabledButton: false; onClicked: root.backend.openLauncherSpecialFolder("data") }
                Hmcl.ToolbarButton { style: root.style; text: "已禁用（待开发）"; iconKind: "FORMAT_LIST_BULLETED"; enabledButton: false; onClicked: root.backend.openLauncherSpecialFolder("config") }
            }
        }

        Item {
            width: parent ? parent.width : 800
            height: Math.max(240, javaList.contentHeight)

            ListView {
                id: javaList
                anchors.fill: parent
                interactive: false
                clip: true
                model: root.javaItems
                delegate: HmclJavaCell {
                    width: ListView.view.width
                    style: root.style
                    version: modelData.version || ""
                    major: modelData.major || ""
                    vendor: modelData.vendor || ""
                    path: modelData.path || ""
                    onReveal: function(p) { root.backend.openFolder(p) }
                    onRemove: function(p) { root.backend.updateLauncherSetting("disabledJavaLast", p) }
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
        }
    }

    function refreshJava() {
        root.loading = true
        root.backend.startDetectJava()
        javaPollTimer.start()
    }

    function pollJava() {
        var raw = root.backend.pollJavaTask()
        try {
            var obj = JSON.parse(raw || "{}")
            root.loading = obj.active === true
            if (obj.runtimes !== undefined)
                root.javaItems = obj.runtimes
            if (!root.loading)
                javaPollTimer.stop()
        } catch (e) {
            root.logAction("java_task_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0})
            root.loading = false
            javaPollTimer.stop()
        }
    }
}
