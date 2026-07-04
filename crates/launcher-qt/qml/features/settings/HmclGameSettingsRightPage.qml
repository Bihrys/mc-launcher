import QtQuick
import "../../Hmcl/controls" as Hmcl

Column {
    id: root
    property var style
    property var backend
    property var settingsPage
    width: parent ? parent.width : 800
    spacing: 10

    function st(key, fallback) { return settingsPage ? settingsPage.settingText(key, fallback) : String(fallback || "") }
    function sb(key, fallback) { return settingsPage ? settingsPage.settingBool(key, fallback) : !!fallback }
    function set(key, value) { if (settingsPage) settingsPage.setSetting(key, String(value)) }
    function setb(key, value) { if (settingsPage) settingsPage.setBool(key, value) }

    HmclSettingTitle { style: root.style; title: "全局游戏设置预设" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclButtonLine { style: root.style; title: "全局游戏设置"; subtitle: "作为所有实例的默认游戏设置。"; buttonText: "打开目录"; onAction: root.backend.openLauncherSpecialFolder("minecraft") }
        HmclSelectLine { style: root.style; title: "默认隔离"; subtitle: "设置新建游戏实例的默认隔离方式。"; value: root.st("defaultIsolation", "modded"); options: [{"text":"从不隔离","value":"never"},{"text":"总是隔离","value":"always"},{"text":"仅 Mod 游戏隔离","value":"modded"}]; onSelected: function(v) { root.set("defaultIsolation", v) } }
    }

    HmclSettingTitle { style: root.style; title: "游戏" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "Java 路径"
            hasSubtitle: true
            subtitle: javaDescription()
            trailingText: javaDescription()

            HmclRadioGroupLine { style: root.style; title: "Java"; value: root.st("javaType", "auto"); options: [{"text":"自动选择","value":"auto"},{"text":"指定版本","value":"version"},{"text":"自定义","value":"custom"}]; onSelected: function(v) { root.set("javaType", v) } }
            HmclTextLine { style: root.style; title: "Java 版本"; valueText: root.st("customJavaVersion", "17"); enabledRow: root.st("javaType", "auto") === "version"; onAccepted: function(v) { root.set("customJavaVersion", v) } }
            HmclTextLine { style: root.style; title: "自定义 Java 路径"; valueText: root.st("javaPath", ""); enabledRow: root.st("javaType", "auto") === "custom"; onAccepted: function(v) { root.set("javaPath", v) } }
            HmclButtonLine { style: root.style; title: "检测本机 Java"; buttonText: "刷新"; onAction: root.backend.startDetectJava() }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "内存"
            hasSubtitle: true
            subtitle: root.sb("autoMemory", true) ? "自动分配" : "手动分配 " + root.st("maxMemoryMb", "2048") + " MiB"
            trailingText: subtitle

            HmclRadioGroupLine { style: root.style; title: "内存分配"; value: root.sb("autoMemory", true) ? "auto" : "manual"; options: [{"text":"自动分配","value":"auto"},{"text":"手动分配","value":"manual"}]; onSelected: function(v) { root.setb("autoMemory", v === "auto") } }
            HmclSliderLine { style: root.style; title: "最大内存"; enabledRow: !root.sb("autoMemory", true); fromValue: 512; toValue: 32768; valueNumber: Number(root.st("maxMemoryMb", "2048")); suffix: " MiB"; onMovedValue: function(v) { root.set("maxMemoryMb", Math.round(v)) } }
            HmclTextLine { style: root.style; title: "最小内存"; valueText: root.st("minMemoryMb", "256"); enabledRow: !root.sb("autoMemory", true); onAccepted: function(v) { root.set("minMemoryMb", v) } }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "游戏窗口"
            hasSubtitle: true
            subtitle: windowDescription()
            trailingText: windowDescription()

            HmclRadioGroupLine { style: root.style; title: "窗口模式"; value: root.st("windowType", "windowed"); options: [{"text":"窗口化","value":"windowed"},{"text":"全屏","value":"fullscreen"},{"text":"最大化","value":"maximized"}]; onSelected: function(v) { root.set("windowType", v); root.setb("fullscreen", v === "fullscreen") } }
            HmclTextLine { style: root.style; title: "窗口大小"; subtitle: "格式示例：854x480"; valueText: root.st("gameResolution", root.st("gameWidth", "854") + "x" + root.st("gameHeight", "480")); enabledRow: root.st("windowType", "windowed") === "windowed"; onAccepted: function(v) { root.set("gameResolution", v); var p=String(v).split("x"); if (p.length===2) { root.set("gameWidth", p[0]); root.set("gameHeight", p[1]) } } }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "快速加入游戏"
            hasSubtitle: true
            subtitle: quickDescription()
            trailingText: quickDescription()

            HmclRadioGroupLine { style: root.style; title: "快速加入"; value: root.st("quickPlayType", "none"); options: [{"text":"无","value":"none"},{"text":"多人游戏","value":"multiplayer"},{"text":"单人游戏","value":"singleplayer"},{"text":"Realms","value":"realms"}]; onSelected: function(v) { root.set("quickPlayType", v) } }
            HmclTextLine { style: root.style; title: "多人游戏地址"; valueText: root.st("quickPlayServer", ""); enabledRow: root.st("quickPlayType", "none") === "multiplayer"; onAccepted: function(v) { root.set("quickPlayServer", v) } }
            HmclTextLine { style: root.style; title: "单人游戏存档"; valueText: root.st("quickPlaySingleplayer", ""); enabledRow: root.st("quickPlayType", "none") === "singleplayer"; onAccepted: function(v) { root.set("quickPlaySingleplayer", v) } }
        }
    }

    HmclSettingTitle { style: root.style; title: "启动器" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclSelectLine { style: root.style; title: "启动器可见性"; value: root.st("launcherVisibility", "hide"); options: [{"text":"启动游戏后隐藏启动器","value":"hide"},{"text":"启动游戏后保持可见","value":"keep"},{"text":"启动游戏后关闭启动器","value":"close"}]; onSelected: function(v) { root.set("launcherVisibility", v); if (settingsPage) settingsPage.launcherVisibilitySelected(v) } }
        HmclToggleLine { style: root.style; title: "允许自动添加认证代理"; subtitle: "启动需要 authlib-injector 的游戏时自动加入 Java Agent。"; checkedValue: root.sb("allowAutoAgent", true); onChangedValue: function(v) { root.setb("allowAutoAgent", v) } }
        HmclToggleLine { style: root.style; title: "禁用自动修改游戏选项"; checkedValue: root.sb("disableAutoGameOptions", false); onChangedValue: function(v) { root.setb("disableAutoGameOptions", v) } }
        HmclToggleLine { style: root.style; title: "显示日志窗口"; checkedValue: root.sb("showLogs", false); onChangedValue: function(v) { root.setb("showLogs", v) } }
        HmclToggleLine { style: root.style; title: "启用调试日志输出"; checkedValue: root.sb("enableDebugLogOutput", false); onChangedValue: function(v) { root.setb("enableDebugLogOutput", v) } }
        HmclToggleLine { style: root.style; title: "不检查游戏完整性"; checkedValue: root.sb("notCheckGame", false); onChangedValue: function(v) { root.setb("notCheckGame", v) } }
        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "启动选项"
            hasSubtitle: true
            subtitle: "设置运行目录、游戏参数、环境变量和进程优先级。"
            HmclTextLine { style: root.style; title: "运行目录"; valueText: root.st("runningDir", ""); onAccepted: function(v) { root.set("runningDir", v) } }
            HmclTextLine { style: root.style; title: "Minecraft 参数"; valueText: root.st("gameArguments", ""); onAccepted: function(v) { root.set("gameArguments", v) } }
            HmclTextLine { style: root.style; title: "环境变量"; subtitle: "多个变量用分号分隔。"; valueText: root.st("environmentVariables", ""); onAccepted: function(v) { root.set("environmentVariables", v) } }
            HmclSelectLine { style: root.style; title: "进程优先级"; value: root.st("processPriority", "normal"); options: [{"text":"低","value":"low"},{"text":"普通","value":"normal"},{"text":"高","value":"high"}]; onSelected: function(v) { root.set("processPriority", v) } }
        }
    }

    HmclSettingTitle { style: root.style; title: "高级 JVM" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclToggleLine { style: root.style; title: "不添加默认 JVM 参数"; checkedValue: root.sb("noJVMOptions", false); onChangedValue: function(v) { root.setb("noJVMOptions", v) } }
        HmclToggleLine { style: root.style; title: "不添加优化 JVM 参数"; enabledRow: !root.sb("noJVMOptions", false); checkedValue: root.sb("noOptimizingJVMOptions", false); onChangedValue: function(v) { root.setb("noOptimizingJVMOptions", v) } }
        HmclToggleLine { style: root.style; title: "不检查 JVM 有效性"; checkedValue: root.sb("notCheckJVM", false); onChangedValue: function(v) { root.setb("notCheckJVM", v) } }
        HmclTextLine { style: root.style; title: "JVM 参数"; valueText: root.st("jvmArgs", ""); onAccepted: function(v) { root.set("jvmArgs", v) } }
        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "过时的 JVM 内存设置"
            hasSubtitle: true
            subtitle: "仅兼容旧版本 Minecraft 或旧 Java。"
            HmclTextLine { style: root.style; title: "最小内存"; valueText: root.st("minMemoryMb", "256"); onAccepted: function(v) { root.set("minMemoryMb", v) } }
            HmclTextLine { style: root.style; title: "永久代 / 元空间"; valueText: root.st("permSize", ""); onAccepted: function(v) { root.set("permSize", v) } }
        }
    }

    HmclSettingTitle { style: root.style; title: "自定义命令" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclTextLine { style: root.style; title: "启动前执行命令"; valueText: root.st("preLaunchCommand", ""); onAccepted: function(v) { root.set("preLaunchCommand", v) } }
        HmclTextLine { style: root.style; title: "包装命令"; valueText: root.st("commandWrapper", ""); onAccepted: function(v) { root.set("commandWrapper", v) } }
        HmclTextLine { style: root.style; title: "游戏结束后执行命令"; valueText: root.st("postExitCommand", ""); onAccepted: function(v) { root.set("postExitCommand", v) } }
    }

    HmclSettingTitle { style: root.style; title: "图形" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclSelectLine { style: root.style; title: "图形后端"; value: root.st("graphicsBackend", "default"); options: [{"text":"默认","value":"default"},{"text":"OpenGL","value":"opengl"},{"text":"Vulkan","value":"vulkan"}]; onSelected: function(v) { root.set("graphicsBackend", v) } }
        HmclSelectLine { style: root.style; title: "OpenGL 渲染器"; value: root.st("openGLRenderer", "default"); options: [{"text":"默认","value":"default"},{"text":"系统默认","value":"system"},{"text":"软件渲染","value":"software"}]; onSelected: function(v) { root.set("openGLRenderer", v) } }
    }

    function javaDescription() {
        var type = root.st("javaType", "auto")
        if (type === "custom") return root.st("javaPath", "自定义")
        if (type === "version") return "Java " + root.st("customJavaVersion", "17")
        return "自动选择"
    }

    function windowDescription() {
        var type = root.st("windowType", "windowed")
        if (type === "fullscreen") return "全屏"
        if (type === "maximized") return "最大化"
        return root.st("gameResolution", root.st("gameWidth", "854") + "x" + root.st("gameHeight", "480"))
    }

    function quickDescription() {
        var type = root.st("quickPlayType", "none")
        if (type === "multiplayer") return root.st("quickPlayServer", "多人游戏")
        if (type === "singleplayer") return root.st("quickPlaySingleplayer", "单人游戏")
        if (type === "realms") return "Realms"
        return "无"
    }
}
