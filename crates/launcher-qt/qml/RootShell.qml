import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components"
import "pages"

Item {
    id: root

    required property var appWindow
    required property var backend

    readonly property string currentPage: decoratorNavigator.currentPageKey
    property string requestedSettingsSection: "global"
    property bool settingsPageLoaded: false
    readonly property var appStyle: style
    readonly property real uiScale: Math.max(0.78, Math.min(1.18, Math.min(root.width / 1280, root.height / 720)))
    property string launcherTheme: appSettings.launcherTheme
    property string launcherVisibility: appSettings.launcherVisibility
    property bool animationsEnabled: true

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
        "stages": [],
        "tasks": []
    })

    property bool launchDialogOpen: false
    property string launchWindowActionHandledId: ""
    property string launchReopenHandledId: ""
    property bool launchActionArmed: false

    focus: true

    Component.onCompleted: {
        decoratorNavigator.init("main", mainPageComponent, mainState)

        root.backend.refreshAccounts()
        root.backend.refreshInstalledVersions()
        root.applyLauncherSettings(root.backend.refreshLauncherSettings())
        root.pollLaunchTask()
        root.forceActiveFocus()
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
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
        property string launcherVisibility: "hide"
    }

    onLauncherThemeChanged: {
        appSettings.launcherTheme = root.launcherTheme
    }

    onLauncherVisibilityChanged: {
        appSettings.launcherVisibility = root.launcherVisibility
    }

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    Style {
        id: style
        themeMode: root.launcherTheme
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

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: style.cBgStart
            }

            GradientStop {
                position: 1.0
                color: style.cBgEnd
            }
        }
    }

    Rectangle {
        anchors.fill: parent
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
        title: "下载"
        showBrand: false
        backable: true
        refreshable: false
        animate: true
    }

    PageState {
        id: versionsState
        key: "versions"
        title: "版本管理"
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
            appWindow: root.appWindow
            style: style
            pageState: decoratorNavigator.currentState
            stateSerial: decoratorNavigator.stateSerial
            navigationDirection: decoratorNavigator.navigationDirection
            navigatorCanBack: decoratorNavigator.canGoBack

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
        id: launchDialogOverlay

        anchors.fill: parent
        z: 1100
        visible: root.launchDialogOpen
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (!root.launchTaskStatus.active) {
                    root.launchDialogOpen = false
                }
            }
        }

        LaunchDialogCard {
            anchors.centerIn: parent
            width: Math.min(root.width - 64, 500)
            height: Math.min(root.height - 64, 300)
            style: style
            status: root.launchTaskStatus
            onCloseRequested: root.launchDialogOpen = false
            onCancelRequested: root.backend.cancelLaunchTask()
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

                    onPrepareSettings: root.prepareSettingsPage()
                    onPrepareDownload: root.prepareDownloadPage()
                    onPrepareVersion: root.prepareVersionPage()
                }
            }

            centerComponent: Component {
                Item {
                    anchors.fill: parent

                    MainPage {
                        anchors.fill: parent
                        style: root.appStyle
                        backend: root.backend
                    }

                    SplitLaunchButton {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        style: root.appStyle
                        title: root.backend.selectedGameVersion.length > 0 ? "启动游戏" : "开始游戏"
                        subtitle: root.backend.selectedGameVersion.length > 0
                                  ? root.backend.selectedGameVersion
                                  : ""

                        onLaunchClicked: {
                            root.startLaunch()
                        }

                        onMenuClicked: {
                            root.navigate("versions")
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
                AccountPage {
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
                DownloadPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
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
                VersionPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                }
            }
        }
    }

    Component {
        id: settingsPageComponent

        HmclAnimatedPage {
            anchors.fill: parent
            style: root.appStyle
            leftWidth: 0

            centerComponent: Component {
                SettingsPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
                    themeMode: root.launcherTheme
                    launcherVisibility: root.launcherVisibility
                    requestedSection: root.requestedSettingsSection
                    pageActive: root.currentPage === "settings"

                    onThemeSelected: function(mode) {
                        root.launcherTheme = mode
                    }

                    onLauncherVisibilitySelected: function(mode) {
                        root.launcherVisibility = mode
                    }

                    onBackRequested: {
                        root.goBack()
                    }
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
                JavaPage {
                    anchors.fill: parent
                    style: root.appStyle
                    backend: root.backend
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
                PlaceholderPage {
                    anchors.fill: parent
                    style: root.appStyle
                    titleText: root.getPageTitle(root.currentPage)
                }
            }
        }
    }

    function navigate(page) {
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

    function navigateSettingsSection(section) {
        root.requestedSettingsSection = section
        root.prepareSettingsPage()

        if (root.currentPage === "settings") {
            return
        }

        root.navigate("settings")
    }

    function goBack() {
        var result = decoratorNavigator.close()
        root.forceActiveFocus()
        return result
    }

    function goHome() {
        decoratorNavigator.clear()
        root.forceActiveFocus()
    }

    function refreshCurrentPage() {
        switch (root.currentPage) {
        case "download":
            if (root.backend.refreshDownloadCatalog !== undefined) {
                root.backend.refreshDownloadCatalog()
            }
            break
        case "versions":
            root.backend.refreshInstalledVersions()
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
        case "settings":
            return settingsPageComponent
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
        case "settings":
            return settingsState
        case "java":
            return javaState
        default:
            placeholderState.key = page
            placeholderState.title = root.getPageTitle(page)
            return placeholderState
        }
    }

    function startLaunch() {
        if (root.backend.selectedGameVersion.length === 0) {
            root.navigate("download")
            return
        }

        root.launchDialogOpen = true
        root.launchWindowActionHandledId = ""
        root.launchReopenHandledId = ""
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

            if (root.launchTaskStatus.gameStarted
                    || root.launchTaskStatus.status === "finished"
                    || root.launchTaskStatus.status === "gameRunning"
                    || root.launchTaskStatus.status === "gameExited") {
                root.launchDialogOpen = false
            } else if (root.launchTaskStatus.active || root.launchTaskStatus.status === "failed") {
                root.launchDialogOpen = true
            }

            root.applyLaunchWindowAction()
        } catch (e) {
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
            root.launchWindowActionHandledId = id
            root.launchDialogOpen = false

            if (status.shouldClose) {
                root.launchActionArmed = false
                root.appWindow.close()
                Qt.quit()
                return
            }

            if (status.shouldHide) {
                if (status.visibility === "hide") {
                    root.launchActionArmed = false
                    root.appWindow.close()
                    Qt.quit()
                    return
                }

                root.appWindow.hide()
                return
            }
        }

        if (status.shouldReopen && root.launchReopenHandledId !== id) {
            root.launchReopenHandledId = id
            root.launchDialogOpen = false
            root.launchActionArmed = false
            root.appWindow.show()
            root.appWindow.raise()
            root.appWindow.requestActivate()
        }

        if ((status.status === "failed" || status.status === "cancelled")
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
            if (data.launcherVisibility !== undefined && data.launcherVisibility !== null) {
                root.launcherVisibility = String(data.launcherVisibility)
            }
            root.animationsEnabled = !(data.turnOffAnimations === true || String(data.turnOffAnimations) === "true")
        } catch (e) {
            console.log("Failed to parse launcher settings", e)
        }
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
                && page !== "settings"
                && page !== "java"
    }

    function getPageTitle(page) {
        switch (page) {
        case "account":
            return "账户管理"
        case "versions":
            return "版本管理"
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

    component LaunchDialogCard: Rectangle {
        id: card

        required property var style
        property var status: ({})
        signal closeRequested()
        signal cancelRequested()

        radius: 4
        color: style.cSurfaceContainerHigh
        border.width: 0
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    text: card.status.title || "启动游戏"
                    color: card.style.cTextOnSurface
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 42

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - actionButton.width - 28
                    text: card.bottomText()
                    color: card.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Item {
                    id: actionButton

                    width: Math.max(64, actionLabel.implicitWidth + 25)
                    height: 32
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: card.actionEnabled() ? 1.0 : 0.45

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: actionMouse.containsMouse && card.actionEnabled()
                               ? card.style.cButtonHover
                               : card.style.cButtonSurface
                    }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: card.actionText()
                        color: card.style.cTextOnSurface
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: card.actionEnabled()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (card.status.canCancel === true && card.status.active === true) {
                                card.cancelRequested()
                            } else {
                                card.closeRequested()
                            }
                        }
                    }
                }
            }
        }

        function actionText() {
            if (status.canCancel === true && status.active === true) {
                return "取消"
            }
            return "确定"
        }

        function actionEnabled() {
            return true
        }

        function bottomText() {
            if (status.speedText && status.speedText.length > 0) {
                return status.speedText
            }
            if (status.message && status.message.length > 0) {
                return status.message
            }
            return "请耐心等待"
        }
    }
}
