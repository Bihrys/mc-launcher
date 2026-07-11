import QtQuick
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

    HmclSettingTitle { style: root.style; title: "自定义命令" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclTextLine { style: root.style; developmentPending: true; title: "游戏参数"; placeholderText: "默认"; valueText: root.st("gameArguments", ""); onAccepted: function(v) { root.set("gameArguments", v) } }
        HmclTextLine { style: root.style; developmentPending: true; title: "游戏启动前执行命令"; placeholderText: "将在游戏启动前调用"; valueText: root.st("preLaunchCommand", ""); onAccepted: function(v) { root.set("preLaunchCommand", v) } }
        HmclTextLine { style: root.style; developmentPending: true; title: "包装命令"; placeholderText: "如填写“optirun”后，启动命令将从“java ...”变为“optirun java ...”"; valueText: root.st("commandWrapper", ""); onAccepted: function(v) { root.set("commandWrapper", v) } }
        HmclTextLine { style: root.style; developmentPending: true; title: "游戏结束后执行命令"; placeholderText: "将在游戏结束后调用"; valueText: root.st("postExitCommand", ""); onAccepted: function(v) { root.set("postExitCommand", v) } }

        Rectangle {
            width: parent.width
            implicitHeight: hintColumn.implicitHeight + 20
            height: implicitHeight
            color: "#B7C0FF"
            border.color: "#6574CF"
            border.width: 1
            radius: 4

            Column {
                id: hintColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 4
                Text { text: "ⓘ 提示"; color: "#17316D"; font.pixelSize: 13 }
                Text {
                    width: parent.width
                    color: "#17316D"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    text: "自定义命令被调用时将包含如下的环境变量：\n  · $INST_NAME: 实例名称；\n  · $INST_ID: 实例名称；\n  · $INST_DIR: 当前实例运行路径；\n  · $INST_MC_DIR: 当前游戏文件夹路径；\n  · $INST_JAVA: 游戏运行使用的 Java 路径；\n  · $INST_FORGE: 若安装了 Forge，将会存在本环境变量；\n  · $INST_NEOFORGE: 若安装了 NeoForge，将会存在本环境变量；\n  · $INST_CLEANROOM: 若安装了 Cleanroom，将会存在本环境变量；\n  · $INST_LITELOADER: 若安装了 LiteLoader，将会存在本环境变量；\n  · $INST_OPTIFINE: 若安装了 OptiFine，将会存在本环境变量；\n  · $INST_FABRIC: 若安装了 Fabric，将会存在本环境变量；\n  · $INST_LEGACYFABRIC: 若安装了 Legacy Fabric，将会存在本环境变量；\n  · $INST_QUILT: 若安装了 Quilt，将会存在本环境变量。"
                }
            }
        }
    }

    HmclSettingTitle { style: root.style; title: "Java 虚拟机设置" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclTextLine { style: root.style; developmentPending: true; title: "Java 虚拟机参数"; valueText: root.st("jvmArgs", ""); onAccepted: function(v) { root.set("jvmArgs", v) } }
        HmclTextLine { style: root.style; developmentPending: true; title: "内存永久保存区域"; placeholderText: "单位 MiB"; valueText: root.st("permSize", ""); onAccepted: function(v) { root.set("permSize", v) } }
        HmclTextLine { style: root.style; developmentPending: true; title: "环境变量"; valueText: root.st("environmentVariables", ""); onAccepted: function(v) { root.set("environmentVariables", v) } }
        HmclToggleLine { style: root.style; developmentPending: true; title: "不添加默认 JVM 参数"; checkedValue: root.sb("noJVMOptions", false); onChangedValue: function(v) { root.setb("noJVMOptions", v) } }
        HmclToggleLine { style: root.style; developmentPending: true; title: "不添加默认 JVM 优化参数"; enabledRow: !root.sb("noJVMOptions", false); checkedValue: root.sb("noOptimizingJVMOptions", false); onChangedValue: function(v) { root.setb("noOptimizingJVMOptions", v) } }
        HmclToggleLine { style: root.style; developmentPending: true; title: "不检查 JVM 有效性"; checkedValue: root.sb("notCheckJVM", false); onChangedValue: function(v) { root.setb("notCheckJVM", v) } }

        Rectangle {
            width: parent.width
            implicitHeight: vmHint.implicitHeight + 20
            height: implicitHeight
            color: "#B7C0FF"
            border.color: "#6574CF"
            border.width: 1
            radius: 4

            Text {
                id: vmHint
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                color: "#17316D"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                text: "ⓘ 提示\n· 若在“Java 虚拟机参数”输入的参数与默认参数相同，则不会添加；\n· 若在“Java 虚拟机参数”输入任何 GC 参数，默认参数的 G1 参数会被禁用；\n· 开启下方“不添加默认的 Java 虚拟机参数”可在启动游戏时不添加默认参数。"
            }
        }
    }

    HmclSettingTitle { style: root.style; title: "图形" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclSelectLine { style: root.style; developmentPending: true; title: "图形 API"; value: root.st("graphicsBackend", "default"); options: [{"text":"默认","value":"default"},{"text":"OpenGL","value":"opengl"},{"text":"Vulkan","value":"vulkan"}]; onSelected: function(v) { root.set("graphicsBackend", v) } }
        HmclSelectLine { style: root.style; developmentPending: true; title: "OpenGL 渲染器"; value: root.st("openGLRenderer", "default"); options: [{"text":"默认","value":"default"},{"text":"系统默认","value":"system"},{"text":"软件渲染","value":"software"}]; onSelected: function(v) { root.set("openGLRenderer", v) } }
    }
}
