import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl
import "../../Hmcl/icons" as Icons

Column {
    id: root
    property var style
    property var backend
    property var settingsPage
    width: parent ? parent.width : 800
    spacing: 10

    property var javaData: ({"runtimes": []})
    property var memoryData: ({"total_gib": 31.2, "used_gib": 12.9})

    Component.onCompleted: {
        root.refreshMemoryStatus()
        root.refreshJavaList()
    }

    Timer {
        id: javaPollTimer
        interval: 300
        repeat: true
        onTriggered: {
            if (!root.backend || !root.backend.pollJavaTask) {
                stop()
                return
            }
            var status = root.parseJson(root.backend.pollJavaTask(), {"active": false, "runtimes": []})
            if (status.runtimes !== undefined)
                root.javaData = {"runtimes": status.runtimes}
            if (!status.active)
                stop()
        }
    }

    Timer {
        id: memoryRefreshTimer
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.refreshMemoryStatus()
    }

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    function st(key, fallback) { return settingsPage ? settingsPage.settingText(key, fallback) : String(fallback || "") }
    function sb(key, fallback) { return settingsPage ? settingsPage.settingBool(key, fallback) : !!fallback }
    function set(key, value) { if (settingsPage) settingsPage.setSetting(key, String(value)) }
    function setb(key, value) { if (settingsPage) settingsPage.setBool(key, value) }

    function parseJson(text, fallback) {
        try { return JSON.parse(text || "{}") } catch (e) { return fallback }
    }

    function refreshJavaList() {
        if (!backend) return
        root.javaData = parseJson(backend.detectedJavaJson, {"runtimes": []})
        if (backend.startDetectJava) {
            backend.startDetectJava()
            javaPollTimer.restart()
        }
    }

    function refreshMemoryStatus() {
        if (!backend || !backend.refreshSystemMemory)
            return
        root.memoryData = parseJson(backend.refreshSystemMemory(), root.memoryData)
    }

    function javaDescription() {
        var type = root.st("javaType", "auto")
        if (type === "custom") return root.st("javaPath", "自定义")
        if (type === "version") return "指定 Java " + root.st("customJavaVersion", "17")
        if (type === "detected") return root.st("detectedJavaPath", "已检测 Java")
        return "自动选择合适的 Java"
    }

    function isolationDescription() {
        var value = root.st("defaultIsolation", "default")
        if (value === "independent" || value === "always") return "各实例独立"
        if (value === "custom") return "自定义"
        return "默认（\".minecraft/\"）"
    }

    function visibilityDescription() {
        var value = root.st("launcherVisibility", "hide")
        if (value === "close") return "游戏启动后结束启动器"
        if (value === "keep") return "保持启动器可见"
        if (value === "hide_and_reopen") return "隐藏启动器并在游戏结束后重新打开"
        return "游戏启动后隐藏启动器"
    }

    function priorityDescription() {
        var value = root.st("processPriority", "normal")
        if (value === "low") return "低"
        if (value === "below_normal") return "较低"
        if (value === "above_normal") return "较高"
        if (value === "high") return "高"
        return "中"
    }

    function gameResolutionText() {
        if (root.sb("fullscreen", false)) return "全屏"
        return root.st("gameResolution", root.st("gameWidth", "854") + "x" + root.st("gameHeight", "480"))
    }

    function resolutionIndex(value) {
        var list = ["854x480", "1280x720", "1366x768", "1600x900", "1920x1080"]
        for (var i = 0; i < list.length; ++i)
            if (list[i] === value) return i
        return 0
    }

    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        Hmcl.ComponentSublist {
            id: javaSublist
            width: parent.width
            style: root.style
            title: "游戏 Java"
            hasSubtitle: true
            subtitle: "自动选择合适的 Java"
            trailingText: root.javaDescription()

            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "自动选择合适的 Java"
                checked: root.st("javaType", "auto") === "auto"
                onClicked: { root.set("javaType", "auto"); root.set("javaAuto", "true") }
            }

            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "指定 Java 版本"
                checked: root.st("javaType", "auto") === "version"
                onClicked: { root.set("javaType", "version"); root.set("javaAuto", "false") }
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 32
                    radius: 3
                    color: root.styleValue("cSurfaceContainerHigh", "#ECE9F1")
                    TextInput {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: root.st("javaType", "auto") === "version"
                        text: root.st("customJavaVersion", "17")
                        color: root.styleValue("cTextOnSurface", "#1B1B21")
                        font.pixelSize: 12
                        selectByMouse: true
                        onEditingFinished: root.set("customJavaVersion", text)
                    }
                }
            }

            Repeater {
                model: root.javaData.runtimes || []
                delegate: HmclRadioOptionLine {
                    required property var modelData
                    width: parent.width
                    style: root.style
                    title: (modelData.version && modelData.version.length > 0 ? modelData.version : (modelData.major && modelData.major.length > 0 ? modelData.major : "Java")) + " (64 位)"
                    rightText: modelData.path || ""
                    checked: root.st("javaType", "auto") === "detected" && root.st("detectedJavaPath", "") === (modelData.path || "")
                    onClicked: {
                        root.set("javaType", "detected")
                        root.set("javaAuto", "false")
                        root.set("detectedJavaPath", modelData.path || "")
                        root.set("javaPath", modelData.path || "")
                    }
                }
            }

            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "自定义"
                checked: root.st("javaType", "auto") === "custom"
                onClicked: { root.set("javaType", "custom"); root.set("javaAuto", "false") }
                HmclFileTextBox {
                    style: root.style
                    width: 180
                    enabledBox: root.st("javaType", "auto") === "custom"
                    textValue: root.st("javaPath", "")
                    onAccepted: function(v) { root.set("javaPath", v) }
                    onBrowse: root.backend.openLauncherSpecialFolder("minecraft")
                }
            }
        }

        Hmcl.ComponentSublist {
            id: isolationSublist
            width: parent.width
            style: root.style
            title: "版本隔离（建议使用模组时选择“各实例独立”。改后需移动世界、模组等相关游戏文件）"
            trailingText: root.isolationDescription()

            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "默认 (\".minecraft/\")"
                checked: root.st("defaultIsolation", "default") === "default" || root.st("defaultIsolation", "default") === "never" || root.st("defaultIsolation", "default") === "modded"
                onClicked: root.set("defaultIsolation", "default")
            }
            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "各实例独立 (存放在 \".minecraft/versions/<实例名>/\"，除 assets、libraries 外)"
                checked: root.st("defaultIsolation", "default") === "independent" || root.st("defaultIsolation", "default") === "always"
                onClicked: root.set("defaultIsolation", "independent")
            }
            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "自定义"
                checked: root.st("defaultIsolation", "default") === "custom"
                onClicked: root.set("defaultIsolation", "custom")
                HmclFileTextBox {
                    style: root.style
                    width: 180
                    enabledBox: root.st("defaultIsolation", "default") === "custom"
                    textValue: root.st("gameDir", "")
                    onAccepted: function(v) { root.set("gameDir", v) }
                    onBrowse: root.backend.openLauncherSpecialFolder("minecraft")
                }
            }
        }

        HmclMemorySettingsBlock {
            width: parent.width
            style: root.style
            autoMemory: root.sb("autoMemory", true)
            maxMemoryMb: root.sb("autoMemory", true) ? 7936 : Number(root.st("maxMemoryMb", "7936"))
            minMemoryMb: Number(root.st("minMemoryMb", "256"))
            usedGiB: Number(root.memoryData.used_gib || 12.9)
            totalGiB: Number(root.memoryData.total_gib || 31.2)
            onAutoMemoryChangedByUser: function(v) { root.setb("autoMemory", v) }
            onMaxMemoryChangedByUser: function(v) { root.set("maxMemoryMb", v) }
        }

        HmclSelectLine {
            style: root.style
            title: "启动器可见性"
            value: root.st("launcherVisibility", "hide")
            options: [
                {"text":"游戏启动后结束启动器","value":"close"},
                {"text":"游戏启动后隐藏启动器","value":"hide"},
                {"text":"保持启动器可见","value":"keep"},
                {"text":"隐藏启动器并在游戏结束后重新打开","value":"hide_and_reopen"}
            ]
            onSelected: function(v) { root.set("launcherVisibility", v); if (settingsPage) settingsPage.launcherVisibilitySelected(v) }
        }

        HmclSettingLine {
            width: parent.width
            style: root.style
            title: "游戏窗口分辨率"
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 300
                spacing: 12
                ComboBox {
                    id: resolutionCombo
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 36
                    editable: true
                    enabled: !root.sb("fullscreen", false)
                    model: ["854x480", "1280x720", "1366x768", "1600x900", "1920x1080"]
                    currentIndex: root.resolutionIndex(root.st("gameResolution", "854x480"))
                    editText: root.st("gameResolution", "854x480")
                    onAccepted: { root.set("gameResolution", editText); var p=String(editText).split("x"); if (p.length===2) { root.set("gameWidth", p[0]); root.set("gameHeight", p[1]) } }
                    onActivated: function(i) { root.set("gameResolution", model[i]); var p=String(model[i]).split("x"); if (p.length===2) { root.set("gameWidth", p[0]); root.set("gameHeight", p[1]) } }
                }
                HmclCheckBox {
                    style: root.style
                    checked: root.sb("fullscreen", false)
                    onToggled: function(v) { root.setb("fullscreen", v); root.set("windowType", v ? "fullscreen" : "windowed") }
                }
                Text { text: "全屏"; font.pixelSize: 13; color: root.styleValue("cTextOnSurface", "#1B1B21") }
            }
        }

        HmclToggleLine { style: root.style; title: "查看日志"; checkedValue: root.sb("showLogs", false); onChangedValue: function(v) { root.setb("showLogs", v) } }
        HmclToggleLine { style: root.style; title: "输出调试日志"; checkedValue: root.sb("enableDebugLogOutput", false); onChangedValue: function(v) { root.setb("enableDebugLogOutput", v) } }

        HmclSelectLine {
            style: root.style
            title: "进程优先级"
            value: root.st("processPriority", "normal")
            options: [
                {"text":"低","value":"low"},
                {"text":"较低","value":"below_normal"},
                {"text":"中","value":"normal"},
                {"text":"较高","value":"above_normal"},
                {"text":"高","value":"high"}
            ]
            onSelected: function(v) { root.set("processPriority", v) }
        }

        HmclTextLine { style: root.style; title: "服务器地址"; placeholderText: "默认，启动游戏后可以直接进入对应服务器"; valueText: root.st("quickPlayServer", ""); onAccepted: function(v) { root.set("quickPlayServer", v); root.set("quickPlayType", v.length > 0 ? "multiplayer" : "none") } }

        HmclSettingLine {
            width: parent.width
            style: root.style
            title: "高级设置"
            Icons.SvgIcon {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                icon: "ARROW_FORWARD"
                iconSize: 20
                iconColor: root.styleValue("cTextOnSurfaceVariant", "#454651")
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (settingsPage) settingsPage.currentSection = "globalAdvanced"
            }
        }
    }
}
