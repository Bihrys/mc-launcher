import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property var style
    required property var backend

    property string currentSection: "global"
    property var settingsData: ({})
    property string themeMode: "light"
    property string themeColor: "default"
    property string launcherVisibility: "hide"
    property bool pageActive: false

    // HMCL TabHeader.select(): ContainerAnimations.SLIDE_UP_FADE_IN + Motion.MEDIUM4(400ms)
    // + Motion.EASE_IN_OUT_CUBIC_EMPHASIZED(ThreePointCubic).
    property real transitionDuration: 400
    property real transitionOffset: 50
    property real transitionStartMs: 0

    signal themeSelected(string mode)
    signal themeColorSelected(string color)
    signal launcherVisibilitySelected(string mode)

    Component.onCompleted: {
        root.reloadSettings()
        root.switchRightSection(false)
        root.pageActive = true
    }

    onCurrentSectionChanged: {
        if (root.pageActive)
            root.switchRightSection(true)
    }

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    function reloadSettings() {
        var raw = root.backend.refreshLauncherSettings()
        try {
            root.settingsData = JSON.parse(raw || "{}")
        } catch (e) {
            root.settingsData = {}
        }
        root.themeMode = root.settingText("themeMode", "light")
        root.themeColor = root.settingText("themeColor", "default")
        root.launcherVisibility = root.settingText("launcherVisibility", "hide")
    }

    function setSetting(key, value) {
        var next = {}
        for (var k in root.settingsData)
            next[k] = root.settingsData[k]
        next[key] = value
        root.settingsData = next
        root.backend.updateLauncherSetting(key, String(value))
    }

    function settingText(key, fallback) {
        var value = root.settingsData[key]
        if (value === undefined || value === null || String(value).length === 0)
            return fallback === undefined ? "" : String(fallback)
        return String(value)
    }

    function settingBool(key, fallback) {
        var value = root.settingsData[key]
        if (value === undefined || value === null)
            return fallback === undefined ? false : fallback
        return value === true || value === "true"
    }

    function setBool(key, value) {
        root.setSetting(key, value ? "true" : "false")
    }

    function setThemeMode(value) {
        root.themeMode = value
        root.setSetting("themeMode", value)
        root.themeSelected(value)
    }

    function setThemeColor(value) {
        root.themeColor = value
        root.setSetting("themeColor", value)
        root.themeColorSelected(value)
    }

    function sectionComponentFor(section) {
        switch (section) {
        case "global": return globalSectionComponent
        case "java": return javaSectionComponent
        case "general": return generalSectionComponent
        case "appearance": return appearanceSectionComponent
        case "download": return downloadSectionComponent
        case "help": return helpSectionComponent
        case "feedback": return feedbackSectionComponent
        case "about": return aboutSectionComponent
        default: return generalSectionComponent
        }
    }

    function switchRightSection(animated) {
        var target = root.sectionComponentFor(root.currentSection)
        if (currentLoader === undefined)
            return

        if (!animated || currentLoader.sourceComponent === null) {
            transitionTimer.stop()
            previousLoader.sourceComponent = null
            previousLoader.opacity = 0
            currentLoader.opacity = 1
            currentLoader.y = 10
            currentLoader.sourceComponent = target
            return
        }

        if (currentLoader.sourceComponent === target)
            return

        transitionTimer.stop()
        previousLoader.sourceComponent = currentLoader.sourceComponent
        previousLoader.opacity = 1
        previousLoader.y = 10

        currentLoader.sourceComponent = target
        currentLoader.opacity = 0
        root.transitionOffset = Math.max(50, rightPane.height * 0.20)
        currentLoader.y = 10 + root.transitionOffset
        root.transitionStartMs = Date.now()
        transitionTimer.start()
    }

    function cubicValue(t, p1, p2) {
        var u = 1.0 - t
        return 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t
    }

    function cubicBezierYForX(x, x1, y1, x2, y2) {
        var lo = 0.0
        var hi = 1.0
        var mid = 0.0
        for (var i = 0; i < 28; ++i) {
            mid = (lo + hi) * 0.5
            var bx = cubicValue(mid, x1, x2)
            if (bx < x)
                lo = mid
            else
                hi = mid
        }
        return cubicValue((lo + hi) * 0.5, y1, y2)
    }

    function hmclEmphasizedEase(t) {
        t = Math.max(0, Math.min(1, t))
        var midX = 0.166666
        var midY = 0.4
        if (t < midX) {
            var sx = midX
            var sy = midY
            return cubicBezierYForX(t / sx, 0.05 / sx, 0.0 / sy, 0.133333 / sx, 0.06 / sy) * sy
        }
        var sx2 = 1.0 - midX
        var sy2 = 1.0 - midY
        return cubicBezierYForX((t - midX) / sx2,
                                (0.208333 - midX) / sx2, (0.82 - midY) / sy2,
                                (0.25 - midX) / sx2, (1.0 - midY) / sy2) * sy2 + midY
    }

    function updateTransitionFrame() {
        var p = Math.max(0, Math.min(1, (Date.now() - root.transitionStartMs) / root.transitionDuration))
        var e = root.hmclEmphasizedEase(p)
        currentLoader.opacity = e
        currentLoader.y = 10 + root.transitionOffset * (1.0 - e)

        if (p <= 0.5)
            previousLoader.opacity = 1.0 - root.hmclEmphasizedEase(p / 0.5)
        else
            previousLoader.opacity = 0.0

        if (p >= 1.0) {
            transitionTimer.stop()
            previousLoader.sourceComponent = null
            previousLoader.opacity = 0
            currentLoader.opacity = 1
            currentLoader.y = 10
        }
    }

    Timer {
        id: transitionTimer
        interval: 16
        repeat: true
        onTriggered: root.updateTransitionFrame()
    }

    Item {
        id: rightPane
        anchors.fill: parent
        clip: true

        ScrollView {
            id: scroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth

            Item {
                width: scroll.availableWidth
                height: Math.max(scroll.height,
                                 Math.max(currentLoader.item ? currentLoader.item.implicitHeight + 20 : 1,
                                          previousLoader.item ? previousLoader.item.implicitHeight + 20 : 1))

                Loader {
                    id: previousLoader
                    x: 10
                    y: 10
                    width: Math.max(1, parent.width - 20)
                    opacity: 0
                    visible: sourceComponent !== null && opacity > 0.001
                    z: 1
                }

                Loader {
                    id: currentLoader
                    x: 10
                    y: 10
                    width: Math.max(1, parent.width - 20)
                    opacity: 1
                    visible: sourceComponent !== null
                    z: 2
                }
            }
        }
    }

    Component { id: globalSectionComponent; HmclGameSettingsRightPage { style: root.style; backend: root.backend; settingsPage: root } }
    Component { id: javaSectionComponent; HmclJavaManagementRightPage { style: root.style; backend: root.backend; settingsPage: root } }
    Component { id: generalSectionComponent; HmclLauncherGeneralRightPage { style: root.style; backend: root.backend; settingsPage: root } }
    Component { id: appearanceSectionComponent; HmclPersonalizationRightPage { style: root.style; backend: root.backend; settingsPage: root } }
    Component { id: downloadSectionComponent; HmclDownloadSettingsRightPage { style: root.style; backend: root.backend; settingsPage: root } }
    Component { id: helpSectionComponent; HmclHelpRightPage { style: root.style; backend: root.backend; settingsPage: root } }
    Component { id: feedbackSectionComponent; HmclFeedbackRightPage { style: root.style; backend: root.backend; settingsPage: root } }
    Component { id: aboutSectionComponent; HmclAboutRightPage { style: root.style; backend: root.backend; settingsPage: root } }
}
