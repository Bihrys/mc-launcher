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

    property string currentPage: "main"
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

    Component.onCompleted: {
        root.backend.refreshAccounts()
        root.backend.refreshInstalledVersions()
        root.applyLauncherSettings(root.backend.refreshLauncherSettings())
        root.pollLaunchTask()
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

    onCurrentPageChanged: {
        if (root.currentPage === "settings") {
            root.prepareSettingsPage()
        }
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TitleBar {
            Layout.fillWidth: true
            appWindow: root.appWindow
            style: style
        }

        Item {
            id: navigatorHost

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            HmclDecoratorPageLayer {
                id: mainPageLayer

                anchors.fill: parent
                style: style
                active: root.currentPage === "main"
                leftWidth: style.sidebarWidthValue

                leftComponent: Component {
                    Sidebar {
                        anchors.fill: parent
                        style: root.appStyle
                        backend: root.backend
                        currentPage: root.currentPage

                        onNavigate: function(page) {
                            root.currentPage = page
                        }

                        onNavigateSettingsSection: function(section) {
                            root.requestedSettingsSection = section
                            root.prepareSettingsPage()
                            root.currentPage = "settings"
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
                                root.currentPage = "versions"
                            }
                        }
                    }
                }
            }

            HmclDecoratorPageLayer {
                id: accountPageLayer

                anchors.fill: parent
                style: style
                active: root.currentPage === "account"
                leftWidth: 0

                centerComponent: Component {
                    BackPageShell {
                        anchors.fill: parent
                        style: root.appStyle

                        onBackRequested: {
                            root.currentPage = "main"
                        }

                        contentComponent: Component {
                            AccountPage {
                                anchors.fill: parent
                                style: root.appStyle
                                backend: root.backend
                            }
                        }
                    }
                }
            }

            HmclDecoratorPageLayer {
                id: downloadPageLayer

                anchors.fill: parent
                style: style
                active: root.currentPage === "download"
                leftWidth: 0

                centerComponent: Component {
                    BackPageShell {
                        anchors.fill: parent
                        style: root.appStyle

                        onBackRequested: {
                            root.currentPage = "main"
                        }

                        contentComponent: Component {
                            DownloadPage {
                                anchors.fill: parent
                                style: root.appStyle
                                backend: root.backend
                            }
                        }
                    }
                }
            }

            HmclDecoratorPageLayer {
                id: versionsPageLayer

                anchors.fill: parent
                style: style
                active: root.currentPage === "versions"
                leftWidth: 0

                centerComponent: Component {
                    BackPageShell {
                        anchors.fill: parent
                        style: root.appStyle

                        onBackRequested: {
                            root.currentPage = "main"
                        }

                        contentComponent: Component {
                            VersionPage {
                                anchors.fill: parent
                                style: root.appStyle
                                backend: root.backend
                            }
                        }
                    }
                }
            }

            HmclPageLayer {
                id: settingsLayer

                anchors.fill: parent
                style: style
                mode: "fade"
                active: root.currentPage === "settings"

                Loader {
                    id: settingsPageLoader

                    anchors.fill: parent
                    active: root.settingsPageLoaded
                    asynchronous: true
                    sourceComponent: settingsPageComponent
                }
            }

            Component {
                id: settingsPageComponent

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
                        root.currentPage = "main"
                    }
                }
            }

            HmclDecoratorPageLayer {
                id: javaPageLayer

                anchors.fill: parent
                style: style
                active: root.currentPage === "java"
                leftWidth: 0

                centerComponent: Component {
                    BackPageShell {
                        anchors.fill: parent
                        style: root.appStyle

                        onBackRequested: {
                            root.currentPage = "main"
                        }

                        contentComponent: Component {
                            JavaPage {
                                anchors.fill: parent
                                style: root.appStyle
                                backend: root.backend
                            }
                        }
                    }
                }
            }

            HmclDecoratorPageLayer {
                id: placeholderPageLayer

                anchors.fill: parent
                style: style
                active: root.isPlaceholderPage(root.currentPage)
                leftWidth: 0

                centerComponent: Component {
                    BackPageShell {
                        anchors.fill: parent
                        style: root.appStyle

                        onBackRequested: {
                            root.currentPage = "main"
                        }

                        contentComponent: Component {
                            PlaceholderPage {
                                anchors.fill: parent
                                style: root.appStyle
                                titleText: root.getPageTitle(root.currentPage)
                            }
                        }
                    }
                }
            }
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

    function startLaunch() {
        if (root.backend.selectedGameVersion.length === 0) {
            root.currentPage = "download"
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

        // 关键：启动器刚打开时会读取旧 launch-task.json。
        // 旧状态不能再次触发 hide/close/reopen，否则会出现“重启后仍然隐藏”。
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
                // HMCL:
                // HIDE_AND_REOPEN 才是真的隐藏并等待游戏退出后恢复。
                // HIDE 不应该变成永远隐藏的僵尸启动器。
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
        // HMCL 有 Controllers.prepareDownloadPage()。
        // 当前 DownloadPage 仍是直接创建页面，这里保留接口，后续可改 Loader。
    }

    function prepareVersionPage() {
        // HMCL 有 Controllers.prepareVersionPage()。
        // 当前 VersionPage 仍是直接创建页面，这里保留接口，后续可改 Loader。
    }

    function prepareSettingsPage() {
        // HMCL: prepareSettingsPage() 只在 settingsPage == null 时创建。
        // Qt/QML 对应：让 Loader active=true；创建后缓存，不再销毁。
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

        // HMCL: .task-executor-dialog-layout
        // -fx-background-radius: 4px;
        // -fx-background-color: -monet-surface-container-high;
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

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 0

                    Text {
                        id: hmclDialogTitle

                        width: parent.width
                        height: 18
                        text: "启动游戏"
                        color: card.style.cTextOnSurface
                        font.pixelSize: 14
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    ListView {
                        id: launchTaskList

                        width: parent.width
                        height: parent.height - hmclDialogTitle.height
                        y: hmclDialogTitle.height + 12
                        spacing: 0
                        clip: true
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        model: card.buildRows()

                        delegate: Item {
                            id: row

                            width: launchTaskList.width
                            height: modelData.kind === "stage" ? 26 : 42

                            Item {
                                id: stageIconArea

                                visible: modelData.kind === "stage"
                                width: 14
                                height: 14
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                Canvas {
                                    id: stageIconCanvas
                                    anchors.fill: parent

                                    property string iconStatus: modelData.status || "waiting"
                                    property color iconColor: card.stageColor(iconStatus)

                                    onIconStatusChanged: requestPaint()
                                    onIconColorChanged: requestPaint()
                                    Component.onCompleted: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.strokeStyle = iconColor
                                        ctx.fillStyle = iconColor
                                        ctx.lineWidth = 1.6
                                        ctx.lineCap = "round"
                                        ctx.lineJoin = "round"

                                        if (iconStatus === "running") {
                                            ctx.beginPath()
                                            ctx.moveTo(4.5, 3.2)
                                            ctx.lineTo(10.2, 7)
                                            ctx.lineTo(4.5, 10.8)
                                            ctx.closePath()
                                            ctx.fill()
                                        } else if (iconStatus === "success") {
                                            ctx.beginPath()
                                            ctx.moveTo(3.0, 7.2)
                                            ctx.lineTo(5.9, 10.0)
                                            ctx.lineTo(11.2, 4.0)
                                            ctx.stroke()
                                        } else if (iconStatus === "failed") {
                                            ctx.beginPath()
                                            ctx.moveTo(4.0, 4.0)
                                            ctx.lineTo(10.0, 10.0)
                                            ctx.moveTo(10.0, 4.0)
                                            ctx.lineTo(4.0, 10.0)
                                            ctx.stroke()
                                        } else {
                                            ctx.beginPath()
                                            ctx.arc(3.5, 7, 1.1, 0, Math.PI * 2)
                                            ctx.arc(7.0, 7, 1.1, 0, Math.PI * 2)
                                            ctx.arc(10.5, 7, 1.1, 0, Math.PI * 2)
                                            ctx.fill()
                                        }
                                    }
                                }
                            }

                            Text {
                                id: rowTitle

                                x: modelData.kind === "stage" ? 26 : 26
                                y: 0
                                width: modelData.kind === "stage"
                                       ? parent.width - 26
                                       : parent.width - 26 - rowMessage.width - 8
                                height: modelData.kind === "stage" ? 22 : 18
                                text: modelData.title || ""
                                color: card.style.cTextOnSurface
                                font.pixelSize: 13
                                font.bold: false
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            Text {
                                id: rowMessage

                                visible: modelData.kind === "task"
                                anchors.right: parent.right
                                y: 0
                                width: Math.min(180, parent.width * 0.42)
                                height: 18
                                text: modelData.message || ""
                                color: card.style.cTextOnSurfaceVariant
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            ThinProgressBar {
                                visible: modelData.kind === "task"
                                x: 26
                                y: 24
                                width: parent.width - 26
                                height: 3
                                value: Number(modelData.progress)
                                indeterminate: Number(modelData.progress) < 0
                                barColor: card.style.cButtonSelected
                                trackColor: card.style.cSurfaceContainer
                            }
                        }
                    }
                }
            }

            // HMCL bottom BorderPane: padding 0 8 8 8
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
                        color: actionMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                    }

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: card.status.active ? "取消" : "关闭"
                        color: card.style.cTextOnSurfaceVariant
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        enabled: card.actionEnabled()
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (card.status.active) {
                                card.cancelRequested()
                            } else {
                                card.closeRequested()
                            }
                        }
                    }
                }
            }
        }

        function buildRows() {
            var rows = []
            var stages = card.status.stages || []
            var tasks = card.status.tasks || []

            for (var i = 0; i < stages.length; i++) {
                var stage = stages[i]
                rows.push({
                    "kind": "stage",
                    "key": stage.key || "",
                    "title": stage.title || "",
                    "status": stage.status || "waiting",
                    "message": "",
                    "progress": 0
                })

                for (var j = 0; j < tasks.length; j++) {
                    var task = tasks[j]
                    if ((task.stage || "") === (stage.key || "")) {
                        rows.push({
                            "kind": "task",
                            "key": task.stage || "",
                            "title": task.title || "",
                            "status": task.failed ? "failed" : task.cancelled ? "failed" : task.active ? "running" : "success",
                            "message": task.message || "",
                            "progress": Number(task.progress)
                        })
                    }
                }
            }

            if (rows.length === 0) {
                rows.push({
                    "kind": "stage",
                    "key": "launch.state.java",
                    "title": "检测 Java 版本",
                    "status": "waiting",
                    "message": "",
                    "progress": 0
                })
                rows.push({
                    "kind": "stage",
                    "key": "launch.state.dependencies",
                    "title": "处理游戏依赖",
                    "status": "waiting",
                    "message": "",
                    "progress": 0
                })
                rows.push({
                    "kind": "stage",
                    "key": "launch.state.logging_in",
                    "title": "登录",
                    "status": "waiting",
                    "message": "",
                    "progress": 0
                })
                rows.push({
                    "kind": "stage",
                    "key": "launch.state.waiting_launching",
                    "title": "等待游戏启动",
                    "status": "waiting",
                    "message": "",
                    "progress": 0
                })
            }

            return rows
        }

        function stageColor(status) {
            switch (status) {
            case "running":
                return card.style.cTextOnSurface
            case "success":
                return card.style.cButtonSelected
            case "failed":
                return "#d93025"
            default:
                return card.style.cTextOnSurfaceVariant
            }
        }

        function bottomText() {
            if (card.status.status === "cancelled") {
                return "启动已取消"
            }

            if (card.status.status === "cancelling") {
                return "正在取消启动"
            }

            if (card.status.status === "failed") {
                return "启动失败"
            }

            if (card.status.status === "gameRunning") {
                return "游戏运行中"
            }

            if (card.status.status === "gameExited") {
                return "游戏已退出"
            }

            if (card.status.active) {
                return card.status.speedText || "请耐心等待"
            }

            return "启动任务结束"
        }

        function actionEnabled() {
            if (card.status.active) {
                return !!card.status.canCancel
            }

            return true
        }
    }

    component ThinProgressBar: Item {
        id: thinBar

        property real value: 0
        property bool indeterminate: false
        property color barColor: "#6750a4"
        property color trackColor: "#eee"
        property real phase: 0

        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 2
            radius: 1
            color: thinBar.trackColor
            opacity: 0.95
        }

        Rectangle {
            height: 2
            radius: 1
            y: Math.round((thinBar.height - height) / 2)
            color: thinBar.barColor
            opacity: 0.95

            x: thinBar.indeterminate
               ? -thinBar.width * 0.32 + thinBar.phase * thinBar.width * 1.32
               : 0
            width: thinBar.indeterminate
                   ? Math.max(42, thinBar.width * 0.32)
                   : Math.max(0, Math.min(1, thinBar.value)) * thinBar.width
        }

        NumberAnimation on phase {
            running: thinBar.visible && thinBar.indeterminate
            loops: Animation.Infinite
            from: 0
            to: 1
            duration: 950
        }
    }
}
