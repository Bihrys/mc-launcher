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
    function sourceOptions() { return [{"text":"自动选择","value":"balanced"},{"text":"官方源","value":"official"},{"text":"镜像源（BMCLAPI）","value":"bmclapi"}] }

    HmclSettingTitle { style: root.style; title: "下载源" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclSelectLine { style: root.style; title: "版本列表来源"; subtitle: "用于获取 Minecraft、Forge、Fabric 等版本元数据。"; value: root.st("versionListSource", "balanced"); options: root.sourceOptions(); onSelected: function(v) { root.set("versionListSource", v) } }
        HmclSelectLine { style: root.style; title: "文件下载源"; subtitle: "用于下载游戏文件和安装器；自动选择会按可用性依次回退。"; value: root.st("fileDownloadSource", root.st("downloadSource", "balanced")); options: root.sourceOptions(); onSelected: function(v) { root.set("fileDownloadSource", v); root.set("downloadSource", v) } }
        HmclSelectLine { style: root.style; title: "游戏内容下载源"; developmentPending: true; value: root.st("defaultAddonSource", "modrinth"); options: [{"text":"Modrinth","value":"modrinth"},{"text":"CurseForge","value":"curseforge"}]; onSelected: function(v) { root.set("defaultAddonSource", v) } }
    }

    HmclSettingTitle { style: root.style; title: "下载" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "文件下载缓存目录"
            developmentPending: true
            hasSubtitle: true
            subtitle: cacheDescription()
            trailingText: cacheDescription()
            HmclRadioGroupLine { style: root.style; title: "缓存目录"; value: root.st("commonDirType", "default"); options: [{"text":"默认","value":"default"},{"text":"自定义","value":"custom"}]; onSelected: function(v) { root.set("commonDirType", v) } }
            HmclTextLine { style: root.style; title: "自定义目录"; valueText: root.st("commonDirectory", ""); enabledRow: root.st("commonDirType", "default") === "custom"; onAccepted: function(v) { root.set("commonDirectory", v) } }
            HmclButtonGroupLine { style: root.style; title: "缓存操作"; firstText: "打开目录"; secondText: "清理缓存"; onFirst: root.backend.openLauncherSpecialFolder("cache"); onSecond: root.backend.clearLauncherCache() }
        }
        HmclToggleLine { style: root.style; title: "自动选择下载线程数"; developmentPending: true; checkedValue: root.sb("autoDownloadThreads", true); onChangedValue: function(v) { root.setb("autoDownloadThreads", v); if (v) root.set("downloadThreads", "64") } }
        HmclSliderLine { style: root.style; title: "下载线程数"; developmentPending: true; fromValue: 1; toValue: 256; valueNumber: Number(root.st("downloadThreads", "64")); enabledRow: !root.sb("autoDownloadThreads", true); onMovedValue: function(v) { root.set("downloadThreads", Math.round(v)) } }
        HmclInfoLine { style: root.style; title: "提示"; subtitle: "线程数过高可能导致服务器拒绝连接或网络拥塞。" }
    }

    HmclSettingTitle { style: root.style; title: "代理" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style
        HmclRadioGroupLine { style: root.style; title: "代理"; developmentPending: true; value: root.st("proxyType", "default"); options: [{"text":"使用系统代理","value":"default"},{"text":"不使用代理","value":"none"},{"text":"HTTP","value":"http"},{"text":"SOCKS","value":"socks"}]; onSelected: function(v) { root.set("proxyType", v) } }
        HmclTextLine { style: root.style; title: "主机"; developmentPending: true; valueText: root.st("proxyHost", ""); enabledRow: customProxy(); onAccepted: function(v) { root.set("proxyHost", v) } }
        HmclTextLine { style: root.style; title: "端口"; developmentPending: true; valueText: root.st("proxyPort", "0"); enabledRow: customProxy(); onAccepted: function(v) { root.set("proxyPort", v) } }
        HmclToggleLine { style: root.style; title: "代理服务器需要认证"; developmentPending: true; checkedValue: root.sb("hasProxyAuth", false); enabledRow: customProxy(); onChangedValue: function(v) { root.setb("hasProxyAuth", v) } }
        HmclTextLine { style: root.style; title: "用户名"; developmentPending: true; valueText: root.st("proxyUsername", ""); enabledRow: customProxy() && root.sb("hasProxyAuth", false); onAccepted: function(v) { root.set("proxyUsername", v) } }
        HmclTextLine { style: root.style; title: "密码"; developmentPending: true; password: true; valueText: root.st("proxyPassword", ""); enabledRow: customProxy() && root.sb("hasProxyAuth", false); onAccepted: function(v) { root.set("proxyPassword", v) } }
    }

    function customProxy() {
        var type = root.st("proxyType", "default")
        return type === "http" || type === "socks"
    }

    function cacheDescription() {
        if (root.st("commonDirType", "default") === "custom") return root.st("commonDirectory", "")
        return "默认"
    }
}
