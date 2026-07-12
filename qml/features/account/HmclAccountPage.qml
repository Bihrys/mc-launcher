import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../../components"
import "dialogs"

Item {
    id: root
    objectName: "accountPage"

    required property var style
    required property var backend

    property string dialogMode: ""
    property string offlineName: "Steve"
    property string offlineAvatarUrl: ""
    property bool microsoftDialogOpen: false
    property string yggdrasilServer: ""
    property string yggdrasilUsername: ""
    property string yggdrasilPassword: ""
    property bool yggdrasilLoginBusy: false
    property string yggdrasilServerName: ""
    property var yggdrasilServerLinks: ({})
    property bool yggdrasilServerNonEmailLogin: false

    property string addServerName: ""
    property string addServerUrl: ""
    property bool offlineSkinDialogOpen: false
    property int offlineSkinAccountIndex: -1
    property string offlineSkinUsername: ""
    property string offlineSkinUuid: ""
    property string offlineSkinAvatarUrl: ""
    property bool classicLoginDialogOpen: false
    property int classicLoginAccountIndex: -1
    property string classicLoginUsername: ""
    property string classicLoginServerUrl: ""
    property string classicLoginLoginName: ""

    property int deleteIndex: -1
    property bool accountMenuOpen: false
    property int accountMenuIndex: -1
    property string accountMenuUsername: ""
    property string accountMenuUuid: ""
    property string accountMenuIdentifier: ""
    property string accountMenuAvatarUrl: ""
    property string accountMenuDisplayKind: ""
    property real accountMenuX: 0
    property real accountMenuY: 0
    property string accountErrorText: ""
    property int refreshingAccountIndex: -1
    property int taskAccountIndex: -1
    property string taskKind: ""
    property int pendingSkinUploadIndex: -1
    property string pendingSkinUploadModel: "classic"
    property var accountRefreshStatus: ({ "active": false })

    property bool yggdrasilProfileDialogOpen: false
    property string yggdrasilProfileServer: ""
    property string yggdrasilProfileUsername: ""
    property int selectedYggdrasilProfileIndex: -1

    ListModel {
        id: accountsModel
    }

    ListModel {
        id: authServersModel

        ListElement {
            name: "LittleSkin"
            url: "https://littleskin.cn/api/yggdrasil"
            host: "littleskin.cn"
            homepage: "https://littleskin.cn/"
            register: "https://littleskin.cn/auth/register"
            nonEmailLogin: false
        }
    }

    ListModel {
        id: yggdrasilProfileModel
    }

    function logAction(action, details) {
        if (!root.backend)
            return
        root.backend.logUiAction("ui.account", action, JSON.stringify(details || {}))
    }

    onDialogModeChanged: root.logAction("dialog_mode_changed", {"mode": root.dialogMode})
    onAccountMenuOpenChanged: root.logAction("account_menu_changed", {
        "open": root.accountMenuOpen,
        "index": root.accountMenuIndex,
        "displayKind": root.accountMenuDisplayKind
    })
    onYggdrasilLoginBusyChanged: root.logAction("yggdrasil_busy_changed", {
        "busy": root.yggdrasilLoginBusy
    })
    onYggdrasilProfileDialogOpenChanged: root.logAction("profile_dialog_changed", {
        "open": root.yggdrasilProfileDialogOpen,
        "profileCount": yggdrasilProfileModel.count
    })
    onDeleteIndexChanged: root.logAction("delete_target_changed", {"index": root.deleteIndex})

    Component.onCompleted: {
        root.logAction("page_completed", {})
        root.reloadAuthServers()
        root.updateOfflinePreview()

        if (root.backend.accountsJson && root.backend.accountsJson.length > 0) {
            root.reloadAccountsFromJson(root.backend.accountsJson)
        } else {
            initialAccountLoadTimer.restart()
        }
    }

    Component.onDestruction: root.logAction("page_destroyed", {
        "dialogMode": root.dialogMode,
        "accountMenuOpen": root.accountMenuOpen,
        "accountCount": accountsModel.count
    })

    Connections {
        target: root.backend

        function onAccountsJsonChanged() {
            root.reloadAccountsFromJson(root.backend.accountsJson)
        }

        function onPendingYggdrasilProfilesJsonChanged() {
            root.loadPendingYggdrasilProfiles()
        }

        function onAuthServersJsonChanged() {
            root.reloadAuthServersFromJson(root.backend.authServersJson)
        }
    }

    Timer {
        id: yggdrasilLoginPoller

        interval: 80
        repeat: true
        running: false

        onTriggered: root.pollYggdrasilLogin()
    }

    Timer {
        id: accountRefreshPoller

        interval: 80
        repeat: true
        running: false

        onTriggered: root.pollAccountRefresh()
    }

    Timer {
        id: initialAccountLoadTimer

        interval: root.style.motionShort4
        repeat: false
        running: false

        onTriggered: root.reloadAccounts()
    }

    FileDialog {
        id: skinUploadDialog

        title: "选择皮肤文件"
        nameFilters: ["Minecraft skin (*.png)", "PNG images (*.png)"]

        onAccepted: {
            if (root.pendingSkinUploadIndex >= 0) {
                root.startSkinUpload(root.pendingSkinUploadIndex, selectedFile, root.pendingSkinUploadModel)
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.preferredWidth: 200
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        width: 200
                        spacing: 0

                        Item {
                            width: 1
                            height: 12
                        }

                        HmclClassTitle {
                            style: root.style
                            title: "创建账户"
                        }

                        HmclNavMethodItem {
                            style: root.style
                            title: "Microsoft"
                            iconKind: "MICROSOFT"
                            onClicked: root.openMicrosoftDialog()
                        }

                        HmclNavMethodItem {
                            style: root.style
                            title: "离线账户"
                            iconKind: "PERSON"
                            onClicked: root.openDialog("offline")
                        }

                        Repeater {
                            model: authServersModel

                            delegate: Item {
                                required property int index
                                required property string name
                                required property string url
                                required property string host
                                required property string homepage
                                required property string register
                                required property bool nonEmailLogin
                                property var pageRoot: root

                                width: 200
                                height: host.length > 0 ? 58 : 52

                                HmclNavMethodItem {
                                    anchors.fill: parent
                                    style: parent.pageRoot.style
                                    title: parent.name
                                    subtitle: parent.host
                                    iconKind: "DRESSER"
                                    rightIconKind: "CLOSE"

                                    onClicked: {
                                        parent.pageRoot.yggdrasilServer = parent.url
                                        parent.pageRoot.yggdrasilServerName = parent.name
                                        parent.pageRoot.yggdrasilServerLinks = {
                                            "homepage": parent.homepage,
                                            "register": parent.register
                                        }
                                        parent.pageRoot.yggdrasilServerNonEmailLogin = parent.nonEmailLogin
                                        parent.pageRoot.openDialog("yggdrasil")
                                    }

                                    onRightClicked: {
                                        if (parent.index >= 0) {
                                            parent.pageRoot.reloadAuthServersFromJson(
                                                parent.pageRoot.backend.deleteAuthServer(String(parent.index))
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                HmclNavMethodItem {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    style: root.style
                    title: "添加认证服务器"
                    subtitle: "authlib-injector"
                    iconKind: "ADD_CIRCLE"
                    onClicked: {
                        root.addServerName = ""
                        root.addServerUrl = ""
                        root.openDialog("addServer")
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                }
            }
        }

        ScrollView {
            id: accountsScroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                id: accountListColumn

                width: accountsScroll.availableWidth
                spacing: 10

                Item {
                    width: 1
                    height: 10
                }

                Text {
                    visible: accountsModel.count === 0
                    width: parent.width
                    text: "还没有账户。请从左侧选择一种方式添加账户。"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 80
                }

                Repeater {
                    model: accountsModel

                    delegate: Item {
                        id: accountDelegate

                        required property int index
                        required property string username
                        required property string uuid
                        required property string kind
                        required property string displayKind
                        required property string serverUrl
                        required property string loginName
                        required property string avatarUrl
                        required property string identifier
                        required property bool selected
                        property var pageRoot: root

                        width: accountListColumn.width
                        height: 48

                        AccountCard {
                            id: accountCard
                            anchors.fill: parent
                            style: accountDelegate.pageRoot.style
                            accountIndex: accountDelegate.index
                            username: accountDelegate.username
                            uuid: accountDelegate.uuid
                            displayKind: accountDelegate.displayKind
                            serverUrl: accountDelegate.serverUrl
                            avatarUrl: accountDelegate.avatarUrl
                            identifier: accountDelegate.identifier
                            selected: accountDelegate.selected
                            refreshing: accountDelegate.pageRoot.taskAccountIndex === accountDelegate.index
                                        && accountDelegate.pageRoot.taskKind === "refresh"
                            uploading: accountDelegate.pageRoot.taskAccountIndex === accountDelegate.index
                                      && accountDelegate.pageRoot.taskKind === "upload"
                            moving: accountDelegate.pageRoot.taskAccountIndex === accountDelegate.index
                                    && accountDelegate.pageRoot.taskKind === "move"

                            onSelectRequested: {
                                accountDelegate.pageRoot.markSelectedAccount(accountCard.accountIndex)
                                accountDelegate.pageRoot.backend.switchAccountByIdentifier(
                                    accountCard.identifier,
                                    accountCard.username,
                                    accountCard.displayKind,
                                    accountCard.avatarUrl
                                )
                            }

                            onContextMenuRequested: function(localX, localY) {
                                var point = accountCard.mapToItem(accountDelegate.pageRoot, localX, localY)
                                accountDelegate.pageRoot.openAccountMenu(
                                    accountCard.accountIndex,
                                    accountCard.username,
                                    accountCard.uuid,
                                    accountCard.identifier,
                                    accountCard.avatarUrl,
                                    accountCard.displayKind,
                                    point.x,
                                    point.y
                                )
                            }

                            onDeleteRequested: {
                                accountDelegate.pageRoot.deleteIndex = accountCard.accountIndex
                            }

                            onRefreshRequested: {
                                accountDelegate.pageRoot.startAccountRefresh(accountCard.accountIndex)
                            }

                            onCopyUuidRequested: {
                                accountDelegate.pageRoot.copyText(accountCard.uuid)
                            }

                            onMoveRequested: {
                                accountDelegate.pageRoot.startAccountMigration(accountCard.accountIndex)
                            }

                            onUploadSkinRequested: {
                                accountDelegate.pageRoot.openSkinUpload(accountCard.accountIndex)
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 24
                }
            }
        }
    }

    Item {
        id: accountContextMenuLayer

        anchors.fill: parent
        z: 900
        visible: root.accountMenuOpen && !root.microsoftDialogOpen

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.closeAccountMenu()
        }

        Rectangle {
            id: accountContextMenu

            x: Math.max(8, Math.min(root.accountMenuX, root.width - width - 8))
            y: Math.max(8, Math.min(root.accountMenuY, root.height - height - 8))
            width: 220
            height: menuColumn.implicitHeight + 8
            radius: 4
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0

                AccountMenuItem {
                    style: root.style
                    text: "设为当前账户"
                    iconKind: "CHECK"
                    onClicked: {
                        root.markSelectedAccount(root.accountMenuIndex)
                        root.backend.switchAccountByIdentifier(
                            root.accountMenuIdentifier,
                            root.accountMenuUsername,
                            root.accountMenuDisplayKind,
                            root.accountMenuAvatarUrl
                        )
                        root.closeAccountMenu()
                    }
                }

                AccountMenuItem {
                    style: root.style
                    text: "刷新账户"
                    iconKind: "REFRESH"
                    onClicked: {
                        root.startAccountRefresh(root.accountMenuIndex)
                        root.closeAccountMenu()
                    }
                }

                AccountMenuItem {
                    style: root.style
                    text: "复制 UUID"
                    iconKind: "CONTENT_COPY"
                    onClicked: {
                        root.copyText(root.accountMenuUuid)
                        root.closeAccountMenu()
                    }
                }

                AccountMenuItem {
                    style: root.style
                    text: "上传皮肤"
                    iconKind: "CHECKROOM"
                    onClicked: {
                        root.openSkinUpload(root.accountMenuIndex)
                        root.closeAccountMenu()
                    }
                }

                AccountMenuItem {
                    style: root.style
                    text: "账户存储迁移"
                    iconKind: "OUTPUT"
                    onClicked: {
                        root.startAccountMigration(root.accountMenuIndex)
                        root.closeAccountMenu()
                    }
                }

                AccountMenuItem {
                    style: root.style
                    text: "清理头像缓存"
                    iconKind: "DELETE_FOREVER"
                    onClicked: {
                        root.startAvatarCacheCleanup()
                        root.closeAccountMenu()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.style.cBorder
                }

                AccountMenuItem {
                    style: root.style
                    text: "删除账户"
                    iconKind: "DELETE_FOREVER"
                    danger: true
                    onClicked: {
                        root.deleteIndex = root.accountMenuIndex
                        root.closeAccountMenu()
                    }
                }
            }
        }
    }

    MicrosoftAccountLoginPane {
        id: microsoftLoginPane
        anchors.fill: parent
        z: 1020
        visible: root.microsoftDialogOpen && root.deleteIndex < 0
        style: root.style
        backend: root.backend

        onCompleted: {
            root.reloadAccounts()
            root.microsoftDialogOpen = false
        }
        onCanceled: root.microsoftDialogOpen = false
    }

    CreateAccountPane {
        id: createAccountPane
        anchors.fill: parent
        z: 1000
        visible: root.deleteIndex < 0
                 && (root.dialogMode === "offline"
                     || root.dialogMode === "yggdrasil")
        style: root.style
        backend: root.backend
        mode: root.dialogMode
        serverName: root.yggdrasilServerName
        serverUrl: root.yggdrasilServer
        serverLinks: root.yggdrasilServerLinks
        nonEmailLogin: root.yggdrasilServerNonEmailLogin
        busy: root.yggdrasilLoginBusy

        onOfflineAccepted: function(username, uuid) {
            root.backend.loginOfflineWithUuid(username, uuid)
            root.reloadAccounts()
            root.closeDialog()
        }

        onYggdrasilAccepted: function(serverUrl, username, password) {
            if (root.yggdrasilLoginBusy)
                return
            root.yggdrasilServer = serverUrl
            root.yggdrasilUsername = username
            root.yggdrasilPassword = password
            root.yggdrasilLoginBusy = true
            createAccountPane.errorText = ""
            root.backend.loginYggdrasil(serverUrl, username, password)
            yggdrasilLoginPoller.restart()
        }

        onCanceled: root.closeDialog()
    }

    AddAuthlibInjectorServerPane {
        id: addAuthServerPane
        anchors.fill: parent
        z: 1010
        visible: root.deleteIndex < 0 && root.dialogMode === "addServer"
        style: root.style
        backend: root.backend
        onCompleted: function(name, url) {
            root.reloadAuthServersFromJson(root.backend.addAuthServer(name, url))
            root.yggdrasilServer = url
            root.yggdrasilServerName = name
            root.closeDialog()
        }
        onCanceled: root.closeDialog()
    }

    OfflineAccountSkinPane {
        id: offlineSkinPane
        anchors.fill: parent
        z: 1150
        visible: root.offlineSkinDialogOpen
        style: root.style
        backend: root.backend
        onAccepted: function(index, fileUrl, capeFileUrl, model, cslApi, skinType) {
            root.reloadAccountsFromJson(root.backend.setOfflineSkin(String(index), fileUrl, capeFileUrl, model, cslApi, skinType))
            root.offlineSkinDialogOpen = false
        }
        onCanceled: root.offlineSkinDialogOpen = false
    }

    ClassicAccountLoginDialog {
        id: classicLoginPane
        anchors.fill: parent
        z: 1160
        visible: root.classicLoginDialogOpen
        style: root.style
        onAccepted: function(password) {
            if (root.taskAccountIndex >= 0 || root.classicLoginAccountIndex < 0)
                return
            classicLoginPane.busy = true
            classicLoginPane.errorText = ""
            root.taskAccountIndex = root.classicLoginAccountIndex
            root.taskKind = "reauthenticate"
            root.refreshingAccountIndex = root.classicLoginAccountIndex
            root.accountRefreshStatus = {
                "active": true,
                "index": root.classicLoginAccountIndex,
                "title": "正在重新登录"
            }
            root.backend.reauthenticateYggdrasil(String(root.classicLoginAccountIndex), password)
            accountRefreshPoller.restart()
        }
        onCanceled: {
            if (!classicLoginPane.busy)
                root.classicLoginDialogOpen = false
        }
    }

Rectangle {
        id: deleteOverlay

        anchors.fill: parent
        visible: root.deleteIndex >= 0
        z: 1100
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 420)
            height: 168
            radius: 4
            color: root.style.cSurface
            border.color: root.style.cBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 17
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "删除账户"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: "确定要删除这个账户吗？"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    DialogButton {
                        style: root.style
                        text: "取消"
                        onClicked: root.deleteIndex = -1
                    }

                    DialogButton {
                        style: root.style
                        text: "删除"
                        primary: true
                        onClicked: {
                            root.backend.deleteAccount(String(root.deleteIndex))
                            root.deleteIndex = -1
                            root.reloadAccounts()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: yggdrasilProfileOverlay

        anchors.fill: parent
        z: 1200
        visible: root.yggdrasilProfileDialogOpen
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(root.width - 64, 520)
            height: Math.min(root.height - 64, 420)
            radius: 4
            color: root.style.cSurface
            border.color: root.style.cBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 17
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "选择角色"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "第三方账户 " + root.yggdrasilProfileUsername + " 返回了多个角色。"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                ListView {
                    id: profileList

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: yggdrasilProfileModel
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        id: profileDelegate

                        required property int index
                        required property string name
                        required property string uuid
                        required property string avatarUrl

                        width: profileList.width
                        height: 62

                        readonly property bool checked: root.selectedYggdrasilProfileIndex === index

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: profileMouse.containsMouse || profileDelegate.checked
                                   ? root.style.cNavHover
                                   : root.style.cSurfaceContainer
                            border.color: profileDelegate.checked ? root.style.cButtonSelected : root.style.cBorder
                            border.width: 1
                        }

                        MouseArea {
                            id: profileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.selectedYggdrasilProfileIndex = profileDelegate.index
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 28
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: "transparent"
                                    border.color: profileDelegate.checked
                                                  ? root.style.cButtonSelected
                                                  : root.style.cTextOnSurfaceVariant
                                    border.width: 2

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8
                                        height: 8
                                        radius: 4
                                        visible: profileDelegate.checked
                                        color: root.style.cButtonSelected
                                    }
                                }
                            }

                            AvatarBox {
                                style: root.style
                                source: profileDelegate.avatarUrl
                                fallbackText: profileDelegate.name.length > 0
                                              ? profileDelegate.name.substring(0, 1).toUpperCase()
                                              : "?"
                                size: 32
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: profileDelegate.name
                                    color: root.style.cTextOnSurface
                                    font.pixelSize: 14
                                    font.bold: profileDelegate.checked
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: profileDelegate.uuid
                                    color: root.style.cTextOnSurfaceVariant
                                    font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.selectedYggdrasilProfileIndex >= 0
                              ? "已选择角色，点击确定完成登录。"
                              : "请选择一个角色。"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    DialogButton {
                        style: root.style
                        text: "取消"
                        onClicked: {
                            root.selectedYggdrasilProfileIndex = -1
                            root.yggdrasilProfileDialogOpen = false
                        }
                    }

                    DialogButton {
                        style: root.style
                        text: "确定"
                        primary: true
                        enabled: root.selectedYggdrasilProfileIndex >= 0
                        opacity: enabled ? 1 : 0.45
                        onClicked: {
                            if (root.selectedYggdrasilProfileIndex >= 0) {
                                root.backend.selectYggdrasilProfile(String(root.selectedYggdrasilProfileIndex))
                                root.selectedYggdrasilProfileIndex = -1
                                root.yggdrasilProfileDialogOpen = false
                                root.reloadAccounts()
                            }
                        }
                    }
                }
            }
        }
    }

    function reloadAuthServers() {
        root.reloadAuthServersFromJson(root.backend.refreshAuthServers())
    }

    function reloadAuthServersFromJson(raw) {
        if (!raw || raw.length === 0) {
            return
        }

        try {
            var payload = JSON.parse(raw)
            authServersModel.clear()

            if (!payload.servers) {
                return
            }

            for (var i = 0; i < payload.servers.length; i++) {
                var server = payload.servers[i]
                authServersModel.append({
                    "name": server.name || "",
                    "url": server.url || "",
                    "host": server.host || root.hostFromUrl(server.url || ""),
                    "homepage": server.links && server.links.homepage ? server.links.homepage : "",
                    "register": server.links && server.links.register ? server.links.register : "",
                    "nonEmailLogin": !!server.nonEmailLogin
                })
            }
        } catch (e) {
            root.logAction("auth_servers_parse_failed", {"error": String(e)}); console.log("Failed to parse auth servers JSON", e)
        }
    }

    function updateOfflinePreview() {
        if (root.offlineName.length > 0) {
            root.offlineAvatarUrl = root.backend.offlineAvatarPreview(root.offlineName)
        } else {
            root.offlineAvatarUrl = ""
        }
    }

    function openAccountMenu(index, username, uuid, identifier, avatarUrl, displayKind, x, y) {
        root.accountMenuIndex = index
        root.accountMenuUsername = username
        root.accountMenuUuid = uuid
        root.accountMenuIdentifier = identifier
        root.accountMenuAvatarUrl = avatarUrl
        root.accountMenuDisplayKind = displayKind
        root.accountMenuX = x
        root.accountMenuY = y
        root.accountMenuOpen = true
    }

    function closeAccountMenu() {
        root.accountMenuOpen = false
        root.accountMenuIndex = -1
    }

    function openMicrosoftDialog() {
        root.closeAccountMenu()
        root.dialogMode = ""
        root.microsoftDialogOpen = true
        microsoftLoginPane.begin()
    }

    function openDialog(mode) {
        root.dialogMode = mode
        root.accountErrorText = ""
        if (mode === "offline" || mode === "yggdrasil") {
            createAccountPane.begin(mode)
        } else if (mode === "addServer") {
            addAuthServerPane.begin()
        }
    }

    function closeDialog() {
        root.dialogMode = ""
        root.yggdrasilLoginBusy = false
        createAccountPane.busy = false
    }

    function dialogTitle() {
        if (root.dialogMode === "offline") return "添加离线账户"
        if (root.dialogMode === "yggdrasil") return "添加第三方服务器账户"
        if (root.dialogMode === "addServer") return "添加认证服务器"
        return ""
    }

    function dialogSubtitle() {
        if (root.dialogMode === "offline") return "创建一个本地离线账户。"
        if (root.dialogMode === "yggdrasil") return "适用于 LittleSkin、Blessing Skin 或其他 Yggdrasil/authlib-injector 兼容服务器。"
        if (root.dialogMode === "addServer") return "添加后会出现在左侧创建账户列表中。"
        return ""
    }

    function dialogAcceptText() {
        if (root.dialogMode === "addServer") return "添加"
        return "确定"
    }

    function acceptDialog() {
        if (root.dialogMode === "offline") {
            root.backend.loginOffline(root.offlineName)
            root.reloadAccounts()
            root.closeDialog()
            return
        }

        if (root.dialogMode === "yggdrasil") {
            if (root.yggdrasilLoginBusy) {
                return
            }

            root.yggdrasilLoginBusy = true
            root.backend.loginYggdrasil(root.yggdrasilServer, root.yggdrasilUsername, root.yggdrasilPassword)
            yggdrasilLoginPoller.restart()
            return
        }

        if (root.dialogMode === "addServer") {
            var name = root.addServerName.trim()
            var url = root.addServerUrl.trim()

            if (name.length === 0) {
                name = url
            }

            if (url.length > 0) {
                root.reloadAuthServersFromJson(root.backend.addAuthServer(name, url))
                root.yggdrasilServer = url
                root.closeDialog()
            }

            return
        }
    }

    function markSelectedAccount(index) {
        for (var i = 0; i < accountsModel.count; i++) {
            accountsModel.setProperty(i, "selected", i === index)
        }
    }

    function startAccountRefresh(index) {
        if (root.taskAccountIndex >= 0 || index < 0 || index >= accountsModel.count) {
            return
        }

        var account = accountsModel.get(index)
        root.classicLoginAccountIndex = index
        root.classicLoginUsername = account.username || ""
        root.classicLoginServerUrl = account.serverUrl || ""
        root.classicLoginLoginName = account.loginName || account.username || ""

        root.taskAccountIndex = index
        root.taskKind = "refresh"
        root.refreshingAccountIndex = index
        root.accountRefreshStatus = {
            "active": true,
            "index": index,
            "title": "正在刷新账户"
        }

        root.backend.startRefreshAccount(String(index))
        accountRefreshPoller.restart()
    }

    function openSkinUpload(index) {
        if (root.taskAccountIndex >= 0 || index < 0 || index >= accountsModel.count) {
            return
        }
        var account = accountsModel.get(index)
        if (account.kind === "offline") {
            root.offlineSkinAccountIndex = index
            root.offlineSkinUsername = account.username || ""
            root.offlineSkinUuid = account.uuid || ""
            root.offlineSkinAvatarUrl = account.avatarUrl || ""
            offlineSkinPane.begin(index, root.offlineSkinUsername,
                                  root.offlineSkinUuid, root.offlineSkinAvatarUrl,
                                  account.skinType || "default", account.skinModel || "wide",
                                  account.skinPath || "", account.capePath || "",
                                  account.skinCslApi || "")
            root.offlineSkinDialogOpen = true
            return
        }

        root.pendingSkinUploadIndex = index
        root.pendingSkinUploadModel = "classic"
        skinUploadDialog.open()
    }

    function startSkinUpload(index, fileUrl, model) {
        if (root.taskAccountIndex >= 0) {
            return
        }

        root.taskAccountIndex = index
        root.taskKind = "upload"
        root.backend.startUploadSkin(String(index), String(fileUrl), model)
        accountRefreshPoller.restart()
    }

    function startAccountMigration(index) {
        if (root.taskAccountIndex >= 0) {
            return
        }

        root.taskAccountIndex = index
        root.taskKind = "move"
        root.backend.startMigrateAccount(String(index), "toggle")
        accountRefreshPoller.restart()
    }

    function startAvatarCacheCleanup() {
        if (root.taskAccountIndex >= 0) {
            return
        }

        root.taskAccountIndex = -2
        root.taskKind = "cleanup"
        root.backend.startCleanupAvatarCache()
        accountRefreshPoller.restart()
    }

    function pollAccountRefresh() {
        var raw = root.backend.pollRefreshAccountTask()

        try {
            var status = JSON.parse(raw)
            root.accountRefreshStatus = status

            if (status.accountsJson && status.accountsJson.length > 0) {
                root.reloadAccountsFromJson(status.accountsJson)
            }

            if (!status.active) {
                var completedKind = root.taskKind
                var completedIndex = root.taskAccountIndex
                accountRefreshPoller.stop()
                root.refreshingAccountIndex = -1
                root.taskAccountIndex = -1
                root.taskKind = ""
                root.pendingSkinUploadIndex = -1

                if (completedKind === "refresh" && status.requiresMicrosoftLogin) {
                    root.openMicrosoftDialog()
                    microsoftLoginPane.errorText = status.message || "Microsoft 登录状态已失效，请重新登录。"
                    microsoftLoginPane.stateName = "failed"
                    return
                }

                if (completedKind === "refresh" && status.requiresPassword) {
                    if (completedIndex >= 0 && completedIndex < accountsModel.count) {
                        var account = accountsModel.get(completedIndex)
                        root.classicLoginAccountIndex = completedIndex
                        root.classicLoginUsername = account.username || ""
                        root.classicLoginServerUrl = account.serverUrl || ""
                        root.classicLoginLoginName = account.loginName || account.username || ""
                    }
                    classicLoginPane.begin(root.classicLoginLoginName)
                    classicLoginPane.errorText = status.message || "登录状态已失效，请重新输入密码。"
                    classicLoginPane.busy = false
                    root.classicLoginDialogOpen = true
                    return
                }

                if (completedKind === "reauthenticate") {
                    classicLoginPane.busy = false
                    if (status.success) {
                        root.classicLoginDialogOpen = false
                        root.reloadAccounts()
                    } else {
                        classicLoginPane.errorText = status.message || "第三方认证失败。"
                    }
                }
            }
        } catch (e) {
            accountRefreshPoller.stop()
            root.refreshingAccountIndex = -1
            root.taskAccountIndex = -1
            root.taskKind = ""
            root.pendingSkinUploadIndex = -1
            classicLoginPane.busy = false
            root.logAction("account_refresh_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0}); console.log("Failed to parse account refresh task", e)
        }
    }

    function pollYggdrasilLogin() {
        var raw = root.backend.pollYggdrasilLoginTask()

        if (!raw || raw.length === 0) {
            return
        }

        try {
            var status = JSON.parse(raw)

            if (status.active) {
                return
            }

            yggdrasilLoginPoller.stop()
            root.yggdrasilLoginBusy = false

            if (status.requiresProfileSelection) {
                root.loadPendingYggdrasilProfiles()
                root.closeDialog()
                root.classicLoginDialogOpen = false
                return
            }

            if (status.success) {
                root.reloadAccounts()
                root.closeDialog()
                root.classicLoginDialogOpen = false
            }

            if (!status.success) {
                // 失败时保留弹窗，和 HMCL 一样在原对话框显示本地化错误。
                var message = status.message || root.backend.output || "第三方认证失败。"
                createAccountPane.errorText = message
                classicLoginPane.errorText = message
                classicLoginPane.busy = false
                return
            }

            root.closeDialog()
        } catch (e) {
            yggdrasilLoginPoller.stop()
            root.yggdrasilLoginBusy = false
            root.logAction("yggdrasil_task_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0}); console.log("Failed to parse yggdrasil login task", e)
        }
    }

    function reloadAccounts() {
        var raw = root.backend.refreshAccounts()
        root.reloadAccountsFromJson(raw)
    }

    function reloadAccountsFromJson(raw) {
        accountsModel.clear()

        if (!raw || raw.length === 0) {
            return
        }

        try {
            var payload = JSON.parse(raw)

            if (!payload.accounts) {
                return
            }

            for (var i = 0; i < payload.accounts.length; i++) {
                var account = payload.accounts[i]
                accountsModel.append({
                    "username": account.username || "",
                    "uuid": account.uuid || "",
                    "kind": account.kind || "",
                    "displayKind": account.displayKind || "",
                    "serverUrl": account.serverUrl || "",
                    "loginName": account.loginName || account.username || "",
                    "avatarUrl": account.avatarUrl || "",
                    "skinType": account.skinType || "default",
                    "skinModel": account.skinModel || "wide",
                    "skinPath": account.skinPath || "",
                    "capePath": account.capePath || "",
                    "skinCslApi": account.skinCslApi || "",
                    "note": account.note || "",
                    "identifier": account.identifier || "",
                    "selected": !!account.selected
                })
            }
        } catch (e) {
            root.logAction("accounts_parse_failed", {"error": String(e), "rawLength": raw ? raw.length : 0}); console.log("Failed to parse accounts JSON", e)
        }
    }

    function loadPendingYggdrasilProfiles() {
        var raw = root.backend.pendingYggdrasilProfilesJson

        root.selectedYggdrasilProfileIndex = -1
        yggdrasilProfileModel.clear()

        if (!raw || raw.length === 0) {
            root.yggdrasilProfileDialogOpen = false
            return
        }

        try {
            var payload = JSON.parse(raw)
            root.yggdrasilProfileServer = payload.serverUrl || ""
            root.yggdrasilProfileUsername = payload.username || ""

            if (!payload.profiles || payload.profiles.length <= 1) {
                root.yggdrasilProfileDialogOpen = false
                return
            }

            for (var i = 0; i < payload.profiles.length; i++) {
                var profile = payload.profiles[i]
                yggdrasilProfileModel.append({
                    "name": profile.name || "",
                    "uuid": profile.id || "",
                    "avatarUrl": profile.avatarUrl || ""
                })
            }

            root.yggdrasilProfileDialogOpen = yggdrasilProfileModel.count > 1
        } catch (e) {
            root.logAction("profiles_parse_failed", {"error": String(e)}); console.log("Failed to parse pending yggdrasil profiles", e)
            root.yggdrasilProfileDialogOpen = false
        }
    }

    function hostFromUrl(url) {
        try {
            var parts = url.split("/")
            if (parts.length >= 3) {
                return parts[2]
            }
        } catch (e) {
        }
        return url
    }

    function copyText(value) {
        // Qt QML 没有跨平台稳定剪贴板 API；这里先选中输出语义。
        // 后端剪贴板会下一步接到 Rust/系统命令层。
        root.logAction("uuid_clicked", {"uuid": value}); console.log("UUID:", value)
    }

    function showUnsupportedHint(name) {
        root.logAction("unimplemented_action", {"name": name}); console.log(name + " 当前后端还没有实现。")
    }

    component AccountMenuItem: Item {
        id: menuItem

        required property var style
        property string text: ""
        property string iconKind: ""
        property bool danger: false

        signal clicked()

        width: parent ? parent.width : 210
        height: 34

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: mouse.containsMouse
                   ? Qt.rgba(menuItem.style.cTextOnSurface.r,
                             menuItem.style.cTextOnSurface.g,
                             menuItem.style.cTextOnSurface.b,
                             0.06)
                   : "transparent"
        }

        HmclSvgIcon {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            icon: menuItem.iconKind
            iconSize: 18
            iconColor: menuItem.danger ? "#d32f2f" : menuItem.style.cTextOnSurfaceVariant
            animationsEnabled: menuItem.style.animationsEnabled
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 38
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.text
            color: menuItem.danger ? "#d32f2f" : menuItem.style.cTextOnSurface
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuItem.clicked()
        }
    }

    component HmclClassTitle: Item {
        id: titleItem

        required property var style
        property string title: ""

        width: parent ? parent.width : 200
        height: 34

        Column {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 0

            Text {
                width: parent.width
                height: 16
                text: titleItem.title
                color: titleItem.style.cTextOnSurface
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: titleItem.style.cTextOnSurfaceVariant
            }
        }
    }

    component HmclNavMethodItem: Item {
        id: item

        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconKind: ""
        property string rightIconKind: ""

        signal clicked()
        signal rightClicked()

        width: parent ? parent.width : 200
        height: subtitle.length > 0 ? 58 : 52
        clip: true

        HmclRipple {
            id: ripple
            anchors.fill: parent
            hovered: mouseArea.containsMouse
            hoverColor: item.style.cTextOnSurface
            hoverOpacity: 0.04
            rippleColor: item.style.cTextOnSurfaceVariant
            rippleOpacity: 0.10
            animationsEnabled: item.style.animationsEnabled
            hoverDuration: item.style.motionShort4
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: function(event) {
                ripple.press(event.x, event.y)
            }

            onClicked: item.clicked()
        }

        HmclSvgIcon {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            icon: item.iconKind
            iconSize: 24
            iconColor: item.style.cTextOnSurface
            animationsEnabled: item.style.animationsEnabled
            animationDuration: item.style.motionShort4
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: rightButton.visible ? rightButton.left : parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: item.title
                color: item.style.cTextOnSurface
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: item.subtitle.length > 0
                text: item.subtitle
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Item {
            id: rightButton

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            visible: item.rightIconKind.length > 0

            HmclSvgIcon {
                anchors.centerIn: parent
                icon: item.rightIconKind
                iconSize: 18
                iconColor: item.style.cTextOnSurfaceVariant
                animationsEnabled: item.style.animationsEnabled
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: item.rightClicked()
            }
        }
    }

    component AccountCard: Rectangle {
        id: card

        required property var style
        property int accountIndex: -1
        property string username: ""
        property string uuid: ""
        property string displayKind: ""
        property string serverUrl: ""
        property string avatarUrl: ""
        property string identifier: ""
        property bool selected: false
        property bool refreshing: false
        property bool uploading: false
        property bool moving: false

        signal selectRequested()
        signal contextMenuRequested(real localX, real localY)
        signal deleteRequested()
        signal refreshRequested()
        signal copyUuidRequested()
        signal moveRequested()
        signal uploadSkinRequested()

        height: 48
        radius: 4
        color: card.selected ? style.cNavSelected
                             : (cardMouse.containsMouse ? style.cSurfaceContainerHigh
                                                        : style.cSurfaceContainer)
        border.color: "transparent"
        Behavior on color {
            ColorAnimation { duration: card.style.animationsEnabled ? card.style.motionShort4 : 0 }
        }
        border.width: 0

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    card.contextMenuRequested(mouse.x, mouse.y)
                } else {
                    card.selectRequested()
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 0
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 8

            Item {
                Layout.preferredWidth: 28
                Layout.fillHeight: true

                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"
                    border.color: card.selected ? card.style.cButtonSelected : card.style.cTextOnSurfaceVariant
                    border.width: 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        visible: card.selected
                        color: card.style.cButtonSelected
                    }
                }
            }

            AvatarBox {
                style: card.style
                source: card.avatarUrl
                fallbackText: card.username.length > 0 ? card.username.substring(0, 1).toUpperCase() : "?"
                size: 32
            }

            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    width: parent.width
                    text: card.username
                    color: card.style.cTextOnSurface
                    font.pixelSize: 15
                    font.bold: false
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: card.displayKind + (card.serverUrl.length > 0 ? ", 认证服务器: " + card.serverUrl : "")
                    color: card.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Row {
                Layout.preferredWidth: 150
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                IconButton {
                    style: card.style
                    iconKind: "OUTPUT"
                    tooltip: card.moving ? "迁移中" : "迁移账户存储"
                    loading: card.moving
                    enabled: !card.moving
                    onClicked: card.moveRequested()
                }

                IconButton {
                    style: card.style
                    iconKind: "REFRESH"
                    tooltip: card.refreshing ? "刷新中" : "刷新"
                    loading: card.refreshing
                    enabled: !card.refreshing
                    onClicked: card.refreshRequested()
                }

                IconButton {
                    style: card.style
                    iconKind: "CHECKROOM"
                    tooltip: card.uploading ? "上传中" : "上传皮肤"
                    loading: card.uploading
                    enabled: !card.uploading
                    onClicked: card.uploadSkinRequested()
                }

                IconButton {
                    style: card.style
                    iconKind: "CONTENT_COPY"
                    tooltip: "复制 UUID"
                    onClicked: card.copyUuidRequested()
                }

                IconButton {
                    style: card.style
                    iconKind: "DELETE_FOREVER"
                    tooltip: "删除"
                    onClicked: card.deleteRequested()
                }
            }
        }
    }

    component AvatarBox: Rectangle {
        id: avatar

        required property var style
        property string source: ""
        property string fallbackText: "?"
        property int size: 32

        Layout.preferredWidth: size
        Layout.preferredHeight: size
        width: size
        height: size
        radius: 4
        color: style.cButtonSurface
        border.color: style.cBorder
        border.width: 1
        clip: true

        Image {
            id: avatarImage
            anchors.fill: parent
            source: avatar.source
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            visible: avatar.source.length > 0 && status === Image.Ready
            cache: true
            smooth: false
        }

        Text {
            anchors.centerIn: parent
            visible: !avatarImage.visible
            text: avatar.fallbackText
            color: avatar.style.cTextOnSurfaceVariant
            font.pixelSize: avatar.size >= 40 ? 20 : 15
            font.bold: true
        }
    }

    component IconButton: Item {
        id: button

        required property var style
        property string iconKind: ""
        property string tooltip: ""

        // HMCL SpinnerPane：loading 时内容替换成小 spinner。
        // 不是让 REFRESH 图标旋转。
        property bool loading: false

        signal clicked()

        width: 30
        height: 30
        enabled: !loading

        Rectangle {
            anchors.fill: parent
            radius: 15
            color: button.enabled && mouse.containsMouse
                   ? Qt.rgba(button.style.cTextOnSurface.r,
                             button.style.cTextOnSurface.g,
                             button.style.cTextOnSurface.b,
                             0.06)
                   : "transparent"
        }

        HmclSvgIcon {
            id: iconGlyph

            anchors.centerIn: parent
            icon: button.iconKind
            iconSize: 18
            iconColor: button.style.cTextOnSurfaceVariant
            animationsEnabled: button.style.animationsEnabled
            visible: !button.loading
            opacity: button.enabled ? 1 : 0.45
        }

        HmclSmallSpinner {
            anchors.centerIn: parent
            visible: button.loading
            running: button.loading && button.visible
            style: button.style
            size: 18
            strokeWidth: 3
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: button.clicked()
        }

        ToolTip.visible: mouse.containsMouse && button.tooltip.length > 0
        ToolTip.text: button.tooltip
        ToolTip.delay: 350
    }

    component HmclSmallSpinner: Item {
        id: spinner

        required property var style
        property int size: 18
        property real strokeWidth: 3
        property bool running: false

        width: size
        height: size
        visible: running

        Canvas {
            id: spinnerCanvas

            anchors.fill: parent
            antialiasing: true
            rotation: 0

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var pad = spinner.strokeWidth / 2 + 1
                var r = Math.min(width, height) / 2 - pad
                var cx = width / 2
                var cy = height / 2

                ctx.lineWidth = spinner.strokeWidth
                ctx.lineCap = "round"
                ctx.strokeStyle = spinner.style.cButtonSelected

                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI * 0.20, Math.PI * 1.20, false)
                ctx.stroke()
            }

            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        RotationAnimator {
            target: spinnerCanvas
            running: spinner.running && spinner.style.animationsEnabled
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 850
        }

        onRunningChanged: {
            if (!running) {
                spinnerCanvas.rotation = 0
            }
        }
    }

    component AccountField: Item {
        id: field

        required property var style
        property string label: ""
        property string textValue: ""
        property string placeholderText: ""
        property bool password: false

        signal edited(string value)

        height: 60

        ColumnLayout {
            anchors.fill: parent
            spacing: 5

            Text {
                text: field.label
                color: field.style.cTextOnSurfaceVariant
                font.pixelSize: 12
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 4
                color: field.style.cButtonSurface
                border.color: input.activeFocus ? field.style.cButtonSelected : field.style.cBorder
                border.width: 1

                TextField {
                    id: input

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: field.textValue
                    placeholderText: field.placeholderText
                    echoMode: field.password ? TextInput.Password : TextInput.Normal
                    color: field.style.cTextOnSurface
                    placeholderTextColor: field.style.cTextOnSurfaceVariant
                    background: Item {}
                    selectByMouse: true

                    onTextChanged: field.edited(text)
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: button

        required property var style
        property string text: ""
        property bool primary: false

        signal clicked()

        width: Math.max(76, label.implicitWidth + 28)
        height: 36
        radius: 4
        color: primary
               ? style.cButtonSelected
               : mouse.containsMouse ? style.cButtonHover : "transparent"
        border.width: primary ? 0 : 1
        border.color: style.cBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? button.style.cButtonSelectedText : button.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: button.primary
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
