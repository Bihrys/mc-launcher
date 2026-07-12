import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components"
import "features/versions"
import "features/settings"
import "features/java"
import "features/download"
import "features/account"
import "features/main"
import "features/launch"

Item {
    id: root
    objectName: "rootShell"

    required property var appWindow
    required property var backend
    required property var fpsMonitor

    readonly property string currentPage: decoratorNavigator.currentPageKey
    property string requestedSettingsSection: "global"
    property string currentSettingsSection: "global"
    property var activeDownloadPage: null
    property bool settingsPageLoaded: false
    property string activeInstanceVersion: ""
    readonly property var appStyle: style
    readonly property real uiScale: Math.max(0.78, Math.min(1.18, Math.min(root.width / 1280, root.height / 720)))
    property string launcherTheme: appSettings.launcherTheme
    property string launcherThemeColor: appSettings.launcherThemeColor
    property string launcherVisibility: appSettings.launcherVisibility
    property bool animationsEnabled: true
    property string launcherBackgroundType: "default"
    property string launcherBackgroundImage: ""
    property string launcherBackgroundImageUrl: ""
    property string launcherBackgroundPaint: ""
    property string launcherBuiltinBackgroundId: "2021-08-26"
    property real launcherBackgroundOpacity: 1.0
    property bool titleBarTransparent: false
    property bool externalBackgroundFailed: false

    property var launchTaskStatus: ({
        "id": "",
        "active": false,
        "percent": 0,
        "title": "空闲",
        "message": "还没有启动任务。",
        "status": "idle",
        "visibility": "hide",
        "gameStarted": false,
        "shouldHide": false,
        "shouldClose": false,
        "shouldReopen": false,
        "pid": 0,
        "canCancel": false,
        "cancelled": false,
        "speedText": "请耐心等待",
        "currentStage": "",
        "crash": ({}),
        "stages": [],
        "tasks": []
    })

    property bool launchDialogOpen: false
    property string launchErrorHandledId: ""
    property string launchCrashHandledId: ""

    // HMCL-style global task executor. Every download entry point feeds this
    // one host so navigation never destroys an active task dialog.
    property var transferTaskStatus: ({
        "id": "",
        "active": false,
        "percent": 0,
        "title": "下载任务",
        "message": "尚未开始。",
        "status": "idle",
        "speed": 0,
        "speedText": "",
        "downloadedBytes": 0,
        "totalBytes": 0,
        "finishedFiles": 0,
        "totalFiles": 0,
        "canCancel": false,
        "stages": [],
        "files": []
    })
    property string transferTaskKind: ""
    property bool transferDialogOpen: false

    property string launchWindowActionHandledId: ""
    property string launchReopenHandledId: ""
    property bool launchActionArmed: false

    focus: true

    function logAction(category, action, details) {
        if (!root.backend)
            return
        root.backend.logUiAction(category, action, JSON.stringify(details || {}))
    }

    Component.onCompleted: {
        root.logAction("ui.lifecycle", "root_shell_completed", {
            "width": root.width,
            "height": root.height,
            "initialPage": "main"
        })
        decoratorNavigator.init("main", mainPageComponent, mainState)

        root.backend.refreshAccounts()
        root.backend.refreshInstalledVersions()
        root.backend.refreshInstances()
        root.applyLauncherSettings(root.backend.refreshLauncherSettings())
        root.pollLaunchTask()
        root.forceActiveFocus()
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            root.logAction("ui.navigation", "back_key_released", {
                "key": event.key,
                "currentPage": root.currentPage
            })
            if (root.goBack()) {
                event.accepted = true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 5000
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        hoverEnabled: false

        onClicked: function(mouse) {
            if (mouse.button === Qt.BackButton || mouse.button === Qt.ForwardButton) {
                root.goBack()
                mouse.accepted = true
            }
        }
    }

    Settings {
        id: appSettings

        category: "appearance"
        property string launcherTheme: "light"
        property string launcherThemeColor: "default"
        property string launcherVisibility: "hide"
    }


    function builtinBackgroundSource(id) {
        switch (String(id || "2021-08-26")) {
        case "2016-02-25":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/wallpapers/2016-02-25.jpg"
        case "2015-06-22":
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/wallpapers/2015-06-22.jpg"
        case "2021-08-26":
        default:
            return "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/wallpapers/2021-08-26.jpg"
        }
    }

    function localBackgroundUrl(path) {
        var value = String(path || "")
        if (value.length === 0)
            return ""
        if (value.indexOf("file:") === 0)
            return value
        return encodeURI("file://" + value)
    }

    function externalBackgroundSource() {
        if (root.launcherBackgroundType === "custom")
            return root.localBackgroundUrl(root.launcherBackgroundImage)
        if (root.launcherBackgroundType === "network")
            return root.launcherBackgroundImageUrl
        return ""
    }

    function effectiveThemeColorFromSettings(data) {
        var type = data.themeColorType !== undefined && data.themeColorType !== null ? String(data.themeColorType) : "default"
        if (type === "custom") {
            var custom = data.customThemeColor !== undefined && data.customThemeColor !== null ? String(data.customThemeColor) : "#5C6BC0"
            return custom.length > 0 ? custom : "#5C6BC0"
        }
        if (data.themeColor !== undefined && data.themeColor !== null)
            return String(data.themeColor)
        return "default"
    }

    onLauncherThemeChanged: {
        appSettings.launcherTheme = root.launcherTheme
        root.logAction("ui.settings", "launcher_theme_changed", {"value": root.launcherTheme})
    }

    onLauncherThemeColorChanged: {
        appSettings.launcherThemeColor = root.launcherThemeColor
        root.logAction("ui.settings", "launcher_theme_color_changed", {"value": root.launcherThemeColor})
    }

    onLauncherVisibilityChanged: {
        appSettings.launcherVisibility = root.launcherVisibility
        root.logAction("ui.settings", "launcher_visibility_changed", {"value": root.launcherVisibility})
    }

    onCurrentPageChanged: root.logAction("ui.navigation", "current_page_changed", {
        "page": root.currentPage,
        "canGoBack": decoratorNavigator.canGoBack
    })
    onCurrentSettingsSectionChanged: root.logAction("ui.navigation", "settings_section_changed", {
        "section": root.currentSettingsSection
    })
    onActiveInstanceVersionChanged: root.logAction("ui.navigation", "active_instance_changed", {
        "versionId": root.activeInstanceVersion
    })
    onLaunchDialogOpenChanged: root.logAction("ui.launch", "launch_dialog_changed", {
        "open": root.launchDialogOpen,
        "status": root.launchTaskStatus.status || ""
    })
    onLauncherBackgroundTypeChanged: {
        root.externalBackgroundFailed = false
        root.logAction("ui.settings", "background_type_changed", {
            "value": root.launcherBackgroundType
        })
    }
    onLauncherBuiltinBackgroundIdChanged: root.logAction("ui.settings", "builtin_background_changed", {
        "value": root.launcherBuiltinBackgroundId
    })
    onLauncherBackgroundImageChanged: root.externalBackgroundFailed = false
    onLauncherBackgroundImageUrlChanged: root.externalBackgroundFailed = false
    onLauncherBackgroundOpacityChanged: root.logAction("ui.settings", "background_opacity_changed", {
        "value": root.launcherBackgroundOpacity
    })
    onTitleBarTransparentChanged: root.logAction("ui.settings", "title_bar_transparency_changed", {
        "value": root.titleBarTransparent
    })

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    Style {
        id: style
        themeMode: root.launcherTheme
        themeColor: root.launcherThemeColor
        systemDark: root.isSystemDark(systemPalette.window)
        animationsEnabled: root.animationsEnabled
    }

    Connections {
        target: root.backend

        function onLauncherSettingsJsonChanged() {
            root.applyLauncherSettings(root.backend.launcherSettingsJson)
        }
    }

    Timer {
        id: launchTaskPoller
        interval: 250
        repeat: true
        running: true
        onTriggered: root.pollLaunchTask()
    }

    Timer {
        id: transferTaskPoller
        interval: 200
        repeat: true
        running: root.transferDialogOpen || !!root.transferTaskStatus.active
        onTriggered: root.pollTransferTask()
    }

    Rectangle {
        id: baseGradientBackground
        anchors.fill: parent
        visible: !(root.launcherBackgroundType === "paint" && root.launcherBackgroundPaint.length > 0)
        gradient: Gradient {
            GradientStop { position: 0.0; color: style.cBgStart }
            GradientStop { position: 1.0; color: style.cBgEnd }
        }
    }

    Rectangle {
        id: paintBackground
        anchors.fill: parent
        visible: root.launcherBackgroundType === "paint" && root.launcherBackgroundPaint.length > 0
        color: root.launcherBackgroundPaint.length > 0 ? root.launcherBackgroundPaint : style.cBgStart
        opacity: Math.max(0.0, Math.min(1.0, root.launcherBackgroundOpacity))
    }

    Image {
        id: builtinBackgroundImage
        anchors.fill: parent
        // DEFAULT uses the theme background. Theme packs are not implemented yet,
        // so this is HMCL's built-in fallback. CUSTOM/NETWORK keep the fallback
        // behind the image while it is loading or if loading fails.
        visible: root.launcherBackgroundType === "default"
                 || root.launcherBackgroundType === "builtin"
                 || ((root.launcherBackgroundType === "custom" || root.launcherBackgroundType === "network")
                     && (root.externalBackgroundSource().length === 0
                         || root.externalBackgroundFailed
                         || externalBackgroundImage.status !== Image.Ready))
        source: root.launcherBackgroundType === "builtin"
                ? root.builtinBackgroundSource(root.launcherBuiltinBackgroundId)
                : root.builtinBackgroundSource("2021-08-26")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: Math.max(0.0, Math.min(1.0, root.launcherBackgroundOpacity))
    }

    Rectangle {
        anchors.fill: parent
        visible: root.launcherBackgroundType === "theme_color"
        color: style.cBgEnd
        opacity: Math.max(0.0, Math.min(1.0, root.launcherBackgroundOpacity))
    }

    Image {
        id: externalBackgroundImage
        anchors.fill: parent
        readonly property string resolvedSource: root.externalBackgroundSource()
        visible: resolvedSource.length > 0 && !root.externalBackgroundFailed
        source: resolvedSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: Math.max(0.0, Math.min(1.0, root.launcherBackgroundOpacity))
        onStatusChanged: {
            if (status === Image.Error) {
                root.externalBackgroundFailed = true
                root.logAction("ui.settings", "background_image_load_failed", {
                    "type": root.launcherBackgroundType,
                    "sourceLength": resolvedSource.length
                })
            } else if (status === Image.Ready) {
                root.externalBackgroundFailed = false
                root.logAction("ui.settings", "background_image_ready", {
                    "type": root.launcherBackgroundType,
                    "sourceLength": resolvedSource.length,
                    "sourceWidth": sourceSize.width,
                    "sourceHeight": sourceSize.height
                })
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        // HMCL Themes.createBackgroundWithOpacity() 只改变壁纸自身透明度，
        // 不在整层内容上叠加高不透明白色遮罩。
        color: style.cSurfaceTransparent
    }

    PageState {
        id: mainState
        key: "main"
        title: ""
        showBrand: true
        backable: false
        refreshable: false
        animate: true
        leftPaneWidth: style.sidebarWidthValue
    }

    PageState {
        id: accountState
        key: "account"
        title: "账户管理"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }

    PageState {
        id: downloadState
        key: "download"
        title: root.activeDownloadPage ? root.activeDownloadPage.pageTitle : "下载"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }

    PageState {
        id: versionsState
        key: "versions"
        title: "实例列表"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }


    PageState {
        id: instanceState
        key: "instance"
        title: "实例管理"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }

    PageState {
        id: settingsState
        key: "settings"
        title: "设置"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }

    PageState {
        id: settingsAdvancedState
        key: "settingsAdvanced"
        title: "高级设置"
        showBrand: false
        backable: true
        homeable: true
        refreshable: false
        animate: true
    }

    PageState {
        id: javaState
        key: "java"
        title: "Java 管理"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }

    PageState {
        id: placeholderState
        key: "placeholder"
        title: "页面"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TitleBar {
            Layout.fillWidth: true
            Layout.preferredHeight: style.titleBarHeightValue
            appWindow: root.appWindow
            style: style
            fpsMonitor: root.fpsMonitor
            pageState: decoratorNavigator.currentState
            stateSerial: decoratorNavigator.stateSerial
            navigationDirection: decoratorNavigator.navigationDirection
            navigatorCanBack: decoratorNavigator.canGoBack
            titleTransparent: root.titleBarTransparent

            onBackRequested: {
                root.goBack()
            }

            onCloseRequested: {
                root.goBack()
            }

            onHomeRequested: {
                root.goHome()
            }

            onRefreshRequested: {
                root.refreshCurrentPage()
            }
        }

        HmclNavigator {
            id: decoratorNavigator

            Layout.fillWidth: true
            Layout.fillHeight: true
            style: style
        }
    }

    Rectangle {
        id: transferDialogOverlay

        anchors.fill: parent
        z: 1200
        visible: opacity > 0
        opacity: root.transferDialogOpen ? 1 : 0
        color: "#28000000"

        Behavior on opacity {
            NumberAnimation {
                duration: root.appStyle.animationsEnabled ? 160 : 0
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.transferDialogOpen
            onClicked: {
                if (!root.transferTaskStatus.active)
                    root.transferDialogOpen = false
            }
        }

        Item {
            id: transferDialogCard
            anchors.centerIn: parent
            width: Math.min(root.width - 64, 500)
            height: Math.min(root.height - 64, 300)
            opacity: root.transferDialogOpen ? 1 : 0
            scale: root.transferDialogOpen ? 1 : 0.97

            Behavior on opacity {
                NumberAnimation { duration: root.appStyle.animationsEnabled ? 160 : 0; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: root.appStyle.animationsEnabled ? 180 : 0; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: -2
                anchors.topMargin: 3
                anchors.bottomMargin: -3
                radius: 4
                color: Qt.rgba(0, 0, 0, root.appStyle.darkMode ? 0.42 : 0.28)
            }

            TaskExecutorDialogPane {
                anchors.fill: parent
                style: root.appStyle
                status: root.transferTaskStatus
                onCancelRequested: root.cancelTransferTask()
                onCloseRequested: root.transferDialogOpen = false
            }
        }
    }

    Rectangle {
        id: launchDialogOverlay

        anchors.fill: parent
        z: 1300
        visible: opacity > 0
        opacity: root.launchDialogOpen ? 1 : 0
        color: "#28000000"

        Behavior on opacity {
            NumberAnimation {
                duration: root.appStyle.animationsEnabled ? 160 : 0
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.launchDialogOpen
            onClicked: {
                if (!root.launchTaskStatus.active)
                    root.launchDialogOpen = false
            }
        }

        Item {
            id: launchDialogCard
            anchors.centerIn: parent
            width: Math.min(root.width - 64, 500)
            height: Math.min(root.height - 64, 300)
            opacity: root.launchDialogOpen ? 1 : 0
            scale: root.launchDialogOpen ? 1 : 0.97

            Behavior on opacity {
                NumberAnimation {
                    duration: root.appStyle.animationsEnabled ? 160 : 0
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.appStyle.animationsEnabled ? 180 : 0
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: -2
                anchors.topMargin: 3
                anchors.bottomMargin: -3
                radius: 4
                color: Qt.rgba(0, 0, 0,
                               root.appStyle.darkMode ? 0.42 : 0.28)
            }

            TaskExecutorDialogPane {
                anchors.fill: parent
                style: root.appStyle
                status: root.launchTaskStatus
                showTerminalMessage: false
                onCancelRequested: {
                    root.backend.cancelLaunchTask()
                    root.pollLaunchTask()
                }
                onCloseRequested: root.launchDialogOpen = false
            }
        }
    }


    HmclLaunchErrorWindow {
        id: launchErrorWindow
        style: root.appStyle
        backend: root.backend
        parentWindow: root.appWindow
        onDismissed: function(taskId) {
            root.launchErrorHandledId = taskId
        }
    }

    HmclGameCrashWindow {
        id: launchCrashWindow
        style: root.appStyle
        backend: root.backend
        parentWindow: root.appWindow
        onDismissed: function(taskId) {
            root.launchCrashHandledId = taskId
        }
    }

    Component {
        id: mainPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: root.appStyle.sidebarWidthValue

            leftComponent: Component {
                Sidebar {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    currentPage: root.currentPage

                    onNavigate: function(page) {
                        root.navigate(page)
                    }

                    onNavigateSettingsSection: function(section) {
                        root.navigateSettingsSection(section)
                    }

                    onPrepareAccount: root.prepareAccountPage()
                    onPrepareSettings: root.prepareSettingsPage()
                    onPrepareDownload: root.prepareDownloadPage()
                    onPrepareVersion: root.prepareVersionPage()
                    onOpenSelectedInstance: function(versionId) {
                        root.navigateInstance(versionId)
                    }
                }
            }

            centerComponent: Component {
                Item {
                    id: mainCenter
                    anchors.fill: parent

                    HmclMainPage {
                        id: mainPageInstance
                        anchors.fill: parent
                        style: root.appStyle
                        backend: root.backend
                    }

                    SplitLaunchButton {
                        id: splitLaunch
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 20
                        anchors.bottomMargin: 20
                        style: root.appStyle
                        title: root.backend.selectedGameVersion.length > 0 ? "启动游戏" : "开始游戏"
                        subtitle: root.backend.selectedGameVersion.length > 0
                                  ? root.backend.selectedGameVersion
                                  : ""

                        onLaunchClicked: {
                            root.startLaunch()
                        }

                        // 菜单键弹出实例快速切换（对齐 HMCL GameListPopupMenu，
                        // 锚定在按钮左上角向上弹出）。
                        onMenuClicked: {
                            var pos = splitLaunch.mapToItem(mainCenter, 0, 0)
                            mainPageInstance.openQuickSwitch(pos.x + splitLaunch.width, pos.y)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: accountPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                HmclAccountPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                }
            }
        }
    }

    Component {
        id: downloadPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                HmclDownloadPage {
                    id: downloadPageInstance
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    taskDialogHost: root

                    Component.onCompleted: {
                        root.activeDownloadPage = downloadPageInstance
                    }

                    Component.onDestruction: {
                        if (root.activeDownloadPage === downloadPageInstance) {
                            root.activeDownloadPage = null
                        }
                    }
                }
            }
        }
    }

    Component {
        id: versionsPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                HmclGameListPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    onOpenInstance: function(versionId) {
                        root.navigateInstance(versionId)
                    }
                }
            }
        }
    }


    Component {
        id: instancePageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                HmclVersionPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    versionId: root.activeInstanceVersion
                }
            }
        }
    }

    Component {
        id: settingsPageComponent

        // 对齐 HMCL LauncherSettingsPage.java：DecoratorAnimatedPage.setLeft(sideBar), setCenter(transitionPane)。
        // 这样进入设置页时，NAVIGATION 动画会让左侧栏从 -30px、右侧内容从 +30px 分别进入。
        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 200

            leftComponent: Component {
                HmclSettingsSideBar {
                    anchors.fill: parent
                    style: root.appStyle
                    currentSection: root.currentSettingsSection
                    onSectionSelected: function(section) {
                        root.currentSettingsSection = section
                    }
                }
            }

            centerComponent: Component {
                HmclSettingsPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    currentSection: root.currentSettingsSection
                    themeMode: root.launcherTheme
                    themeColor: root.launcherThemeColor
                    launcherVisibility: root.launcherVisibility

                    onThemeSelected: function(mode) {
                        root.launcherTheme = mode
                    }

                    onThemeColorSelected: function(color) {
                        root.launcherThemeColor = color
                    }

                    onLauncherVisibilitySelected: function(mode) {
                        root.launcherVisibility = mode
                    }

                    onRequestAdvancedSettings: root.navigate("settingsAdvanced")
                }
            }
        }
    }

    Component {
        id: settingsAdvancedPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                HmclSettingsPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    currentSection: "globalAdvanced"
                    themeMode: root.launcherTheme
                    themeColor: root.launcherThemeColor
                    launcherVisibility: root.launcherVisibility

                    onThemeSelected: function(mode) { root.launcherTheme = mode }
                    onThemeColorSelected: function(color) { root.launcherThemeColor = color }
                    onLauncherVisibilitySelected: function(mode) { root.launcherVisibility = mode }
                }
            }
        }
    }

    Component {
        id: javaPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                HmclJavaPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    taskDialogHost: root
                }
            }
        }
    }

    Component {
        id: placeholderPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                HmclPlaceholderPage {
                    anchors.fill: parent
                    style: root.appStyle
                    titleText: root.getPageTitle(root.currentPage)
                }
            }
        }
    }

    function navigate(page) {
        root.logAction("ui.navigation", "navigate_requested", {
            "from": root.currentPage,
            "to": page
        })
        if (page === "main") {
            root.goHome()
            return
        }

        if (page === "settings") {
            root.prepareSettingsPage()
        }

        decoratorNavigator.navigate(page, root.componentForPage(page), root.stateForPage(page))
        root.forceActiveFocus()
    }


    function navigateInstance(versionId) {
        var targetVersion = versionId && versionId.length > 0 ? versionId : root.backend.selectedGameVersion
        root.logAction("ui.navigation", "navigate_instance_requested", {
            "from": root.currentPage,
            "requestedVersionId": versionId || "",
            "targetVersionId": targetVersion || ""
        })

        if (!targetVersion || targetVersion.length === 0) {
            root.navigate("versions")
            return
        }

        root.activeInstanceVersion = targetVersion
        instanceState.title = targetVersion
        decoratorNavigator.navigate("instance", instancePageComponent, instanceState)
        root.forceActiveFocus()
    }

    function navigateSettingsSection(section) {
        root.logAction("ui.navigation", "navigate_settings_section_requested", {
            "fromPage": root.currentPage,
            "fromSection": root.currentSettingsSection,
            "toSection": section
        })
        root.requestedSettingsSection = section
        root.currentSettingsSection = section
        root.prepareSettingsPage()

        if (root.currentPage !== "settings") {
            root.navigate("settings")
        }
    }

    function goBack() {
        root.logAction("ui.navigation", "go_back_requested", {
            "currentPage": root.currentPage,
            "canGoBack": decoratorNavigator.canGoBack
        })
        if (root.currentPage === "download"
                && root.activeDownloadPage
                && typeof root.activeDownloadPage.handleBack === "function"
                && root.activeDownloadPage.handleBack()) {
            root.forceActiveFocus()
            return true
        }

        var result = decoratorNavigator.close()
        root.logAction("ui.navigation", "go_back_result", {
            "result": result,
            "currentPage": root.currentPage
        })
        root.forceActiveFocus()
        return result
    }

    function goHome() {
        root.logAction("ui.navigation", "go_home_requested", {"from": root.currentPage})
        decoratorNavigator.clear()
        root.forceActiveFocus()
    }

    function refreshCurrentPage() {
        root.logAction("ui.navigation", "refresh_current_page", {"page": root.currentPage})
        switch (root.currentPage) {
        case "download":
            if (root.activeDownloadPage
                    && typeof root.activeDownloadPage.refreshCurrentPage === "function") {
                root.activeDownloadPage.refreshCurrentPage()
            }
            break
        case "versions":
            root.backend.refreshInstances()
            root.backend.refreshInstalledVersions()
            break
        case "instance":
            if (root.activeInstanceVersion.length > 0) {
                root.backend.refreshInstanceDetail(root.activeInstanceVersion)
            }
            break
        case "account":
            root.backend.refreshAccounts()
            break
        case "settings":
            break
        default:
            break
        }
    }

    function componentForPage(page) {
        switch (page) {
        case "main":
            return mainPageComponent
        case "account":
            return accountPageComponent
        case "download":
            return downloadPageComponent
        case "versions":
            return versionsPageComponent
        case "instance":
            return instancePageComponent
        case "settings":
            return settingsPageComponent
        case "settingsAdvanced":
            return settingsAdvancedPageComponent
        case "java":
            return javaPageComponent
        default:
            return placeholderPageComponent
        }
    }

    function stateForPage(page) {
        switch (page) {
        case "main":
            return mainState
        case "account":
            return accountState
        case "download":
            return downloadState
        case "versions":
            return versionsState
        case "instance":
            return instanceState
        case "settings":
            return settingsState
        case "settingsAdvanced":
            return settingsAdvancedState
        case "java":
            return javaState
        default:
            placeholderState.key = page
            placeholderState.title = root.getPageTitle(page)
            return placeholderState
        }
    }

    function openTransferTask(kind) {
        root.transferTaskKind = String(kind || "")
        root.transferDialogOpen = true
        root.pollTransferTask()
    }

    function pollTransferTask() {
        if (!root.backend || root.transferTaskKind.length === 0)
            return

        var raw = root.transferTaskKind === "java"
                ? root.backend.pollJavaTask()
                : root.backend.pollDownloadTask()
        if (!raw || raw.length === 0)
            return

        try {
            root.transferTaskStatus = JSON.parse(raw)
            if (root.transferTaskStatus.active)
                root.transferDialogOpen = true
        } catch (e) {
            root.logAction("ui.error", "transfer_task_parse_failed", {
                "kind": root.transferTaskKind,
                "error": String(e),
                "rawLength": raw ? raw.length : 0
            })
        }
    }

    function cancelTransferTask() {
        if (root.transferTaskKind === "java")
            root.backend.cancelJavaTask()
        else
            root.backend.cancelDownloadTask()
        root.pollTransferTask()
    }

    function startLaunch() {
        root.logAction("ui.launch", "start_launch_requested", {
            "selectedGameVersion": root.backend.selectedGameVersion,
            "visibility": root.launcherVisibility
        })
        if (root.backend.selectedGameVersion.length === 0) {
            root.navigate("download")
            return
        }

        if (launchErrorWindow.visible)
            launchErrorWindow.close()
        if (launchCrashWindow.visible)
            launchCrashWindow.close()

        root.launchDialogOpen = true
        root.launchWindowActionHandledId = ""
        root.launchReopenHandledId = ""
        root.launchErrorHandledId = ""
        root.launchCrashHandledId = ""
        root.launchActionArmed = true
        root.backend.startLaunchSelectedVersion(root.launcherVisibility)
        root.pollLaunchTask()
    }

    function pollLaunchTask() {
        var raw = root.backend.pollLaunchTask()

        if (!raw || raw.length === 0) {
            return
        }

        try {
            root.launchTaskStatus = JSON.parse(raw)

            // HMCL closes TaskExecutorDialogPane as soon as the launch task
            // stops. Startup errors use a MessageDialogPane, while a running
            // game's abnormal exit opens GameCrashWindow separately.
            root.launchDialogOpen = root.launchTaskStatus.active === true
            root.applyLaunchWindowAction()

            var taskId = String(root.launchTaskStatus.id || "")
            var state = String(root.launchTaskStatus.status || "")
            if (!root.launchTaskStatus.active && taskId.length > 0) {
                if (state === "failed" && root.launchErrorHandledId !== taskId) {
                    root.launchErrorHandledId = taskId
                    launchErrorWindow.showError(root.launchTaskStatus)
                } else if (state === "gameCrashed" && root.launchCrashHandledId !== taskId) {
                    root.launchCrashHandledId = taskId
                    launchCrashWindow.showCrash(root.launchTaskStatus)
                }
            }
        } catch (e) {
            root.logAction("ui.error", "launch_task_parse_failed", {
                "error": String(e),
                "rawLength": raw ? raw.length : 0
            })
            console.log("Failed to parse launch task status", e)
        }
    }

    function applyLaunchWindowAction() {
        var status = root.launchTaskStatus
        var id = status.id || ""

        if (id.length === 0) {
            return
        }

        if (!root.launchActionArmed) {
            return
        }

        if (status.gameStarted && root.launchWindowActionHandledId !== id) {
            root.logAction("ui.launch", "game_started_window_action", {
                "id": id,
                "visibility": status.visibility || "",
                "shouldHide": status.shouldHide === true,
                "shouldClose": status.shouldClose === true
            })
            root.launchWindowActionHandledId = id
            root.launchDialogOpen = false

            if (status.shouldClose) {
                root.launchActionArmed = false
                root.appWindow.close()
                Qt.quit()
                return
            }

            if (status.shouldHide) {
                // HMCL LauncherVisibility.HIDE keeps the launcher process alive
                // and only hides the stage. Closing the application here
                // destroys the monitored QProcess and terminates the game.
                root.appWindow.hide()
                return
            }
        }

        if (status.shouldReopen && root.launchReopenHandledId !== id) {
            root.logAction("ui.launch", "launcher_reopen_requested", {"id": id})
            root.launchReopenHandledId = id
            root.launchDialogOpen = false
            root.launchActionArmed = false
            root.appWindow.show()
            root.appWindow.raise()
            root.appWindow.requestActivate()
        }

        if ((status.status === "failed" || status.status === "cancelled"
                || status.status === "gameCrashed")
                && !status.shouldHide
                && !status.shouldClose
                && !status.shouldReopen) {
            root.launchActionArmed = false
        }
    }

    function launchVisibilityLabel(mode) {
        switch (mode) {
        case "close":
            return "游戏启动后关闭启动器"
        case "hide":
            return "游戏启动后隐藏启动器"
        case "keep":
            return "保持启动器可见"
        case "hide_and_reopen":
            return "隐藏启动器，并在游戏退出后重新打开"
        default:
            return "游戏启动后隐藏启动器"
        }
    }

    function applyLauncherSettings(raw) {
        if (!raw || raw.length === 0) {
            return
        }

        try {
            var data = JSON.parse(raw)
            if (data.themeMode !== undefined && data.themeMode !== null) {
                root.launcherTheme = String(data.themeMode)
            }
            root.launcherThemeColor = root.effectiveThemeColorFromSettings(data)
            if (data.launcherVisibility !== undefined && data.launcherVisibility !== null) {
                root.launcherVisibility = String(data.launcherVisibility)
            }
            if (data.backgroundType !== undefined && data.backgroundType !== null) {
                root.launcherBackgroundType = String(data.backgroundType)
            }
            if (data.builtinBackgroundId !== undefined && data.builtinBackgroundId !== null) {
                root.launcherBuiltinBackgroundId = String(data.builtinBackgroundId)
            }
            if (data.customBackgroundImagePath !== undefined && data.customBackgroundImagePath !== null) {
                root.launcherBackgroundImage = String(data.customBackgroundImagePath)
            } else if (data.backgroundImage !== undefined && data.backgroundImage !== null) {
                root.launcherBackgroundImage = String(data.backgroundImage)
            }
            if (data.networkBackgroundImageUrl !== undefined && data.networkBackgroundImageUrl !== null) {
                root.launcherBackgroundImageUrl = String(data.networkBackgroundImageUrl)
            } else if (data.backgroundImageUrl !== undefined && data.backgroundImageUrl !== null) {
                root.launcherBackgroundImageUrl = String(data.backgroundImageUrl)
            }
            if (data.customBackgroundPaint !== undefined && data.customBackgroundPaint !== null) {
                root.launcherBackgroundPaint = String(data.customBackgroundPaint)
            } else if (data.backgroundPaint !== undefined && data.backgroundPaint !== null) {
                root.launcherBackgroundPaint = String(data.backgroundPaint)
            }
            if (data.backgroundOpacity !== undefined && data.backgroundOpacity !== null) {
                root.launcherBackgroundOpacity = Number(data.backgroundOpacity)
            }
            if (data.titleTransparent !== undefined && data.titleTransparent !== null) {
                root.titleBarTransparent = data.titleTransparent === true || String(data.titleTransparent) === "true"
            }
            root.animationsEnabled = !(data.turnOffAnimations === true || String(data.turnOffAnimations) === "true" || data.animationDisabled === true || String(data.animationDisabled) === "true")
        } catch (e) {
            root.logAction("ui.error", "launcher_settings_parse_failed", {
                "error": String(e),
                "rawLength": raw ? raw.length : 0
            })
            console.log("Failed to parse launcher settings", e)
        }
    }

    function prepareAccountPage() {
        // HMCL 的账户页绑定全局 Accounts 列表；这里不在 hover 中同步刷新。
        // 账户 JSON 在启动时已加载，AccountPage 进入时直接读取 backend.accountsJson。
    }

    function prepareDownloadPage() {
    }

    function prepareVersionPage() {
    }

    function prepareSettingsPage() {
        if (!root.settingsPageLoaded) {
            root.settingsPageLoaded = true
        }
    }

    function isSystemDark(colorValue) {
        var brightness = colorValue.r * 0.299 + colorValue.g * 0.587 + colorValue.b * 0.114
        return brightness < 0.5
    }

    function isPlaceholderPage(page) {
        return page !== "main"
                && page !== "account"
                && page !== "download"
                && page !== "versions"
                && page !== "instance"
                && page !== "settings"
                && page !== "java"
    }

    function getPageTitle(page) {
        switch (page) {
        case "account":
            return "账户管理"
        case "versions":
            return "实例管理"
        case "instance":
            return root.activeInstanceVersion.length > 0 ? root.activeInstanceVersion : "实例管理"
        case "download":
            return "下载"
        case "settings":
            return "启动器设置"
        case "java":
            return "Java 管理"
        case "feedback":
            return "反馈"
        case "terracotta":
            return "Terracotta"
        default:
            return "页面"
        }
    }

}
