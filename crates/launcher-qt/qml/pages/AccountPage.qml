import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var style
    required property var backend

    property string dialogMode: ""
    property string offlineName: "Steve"
    property string microsoftClientId: ""
    property string yggdrasilServer: ""
    property string yggdrasilUsername: ""
    property string yggdrasilPassword: ""

    property string addServerName: ""
    property string addServerUrl: ""

    property int deleteIndex: -1
    property int refreshingAccountIndex: -1
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
        }
    }

    ListModel {
        id: yggdrasilProfileModel
    }

    Component.onCompleted: {
        root.reloadAccounts()
    }

    Connections {
        target: root.backend

        function onAccountsJsonChanged() {
            root.reloadAccountsFromJson(root.backend.accountsJson)
        }

        function onPendingYggdrasilProfilesJsonChanged() {
            root.loadPendingYggdrasilProfiles()
        }
    }

    Timer {
        id: accountRefreshPoller

        interval: 80
        repeat: true
        running: false

        onTriggered: root.pollAccountRefresh()
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
                            onClicked: root.openDialog("microsoft")
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

                                width: 200
                                height: host.length > 0 ? 58 : 52

                                HmclNavMethodItem {
                                    anchors.fill: parent
                                    style: root.style
                                    title: parent.name
                                    subtitle: parent.host
                                    iconKind: "DRESSER"
                                    rightIconKind: "CLOSE"

                                    onClicked: {
                                        root.yggdrasilServer = parent.url
                                        root.openDialog("yggdrasil")
                                    }

                                    onRightClicked: {
                                        if (parent.index >= 0) {
                                            authServersModel.remove(parent.index)
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
                        required property int index
                        required property string username
                        required property string uuid
                        required property string displayKind
                        required property string serverUrl
                        required property string avatarUrl
                        required property bool selected

                        width: accountListColumn.width
                        height: 80

                        AccountCard {
                            id: accountCard
                            anchors.fill: parent
                            style: root.style
                            accountIndex: parent.index
                            username: parent.username
                            uuid: parent.uuid
                            displayKind: parent.displayKind
                            serverUrl: parent.serverUrl
                            avatarUrl: parent.avatarUrl
                            selected: parent.selected
                            refreshing: root.refreshingAccountIndex === parent.index

                            onSelectRequested: {
                                root.backend.switchAccount(String(accountCard.accountIndex))
                                root.reloadAccounts()
                            }

                            onDeleteRequested: {
                                root.deleteIndex = accountCard.accountIndex
                            }

                            onRefreshRequested: {
                                root.startAccountRefresh(accountCard.accountIndex)
                            }

                            onCopyUuidRequested: {
                                root.copyText(accountCard.uuid)
                            }

                            onMoveRequested: {
                                root.showUnsupportedHint("账户本地/全局迁移")
                            }

                            onUploadSkinRequested: {
                                root.showUnsupportedHint("上传皮肤")
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

    Rectangle {
        id: accountDialogOverlay

        anchors.fill: parent
        visible: root.dialogMode.length > 0 && root.deleteIndex < 0
        z: 1000
        color: "#80000000"

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 560)
            height: dialogContent.implicitHeight + 34
            radius: 4
            color: root.style.cSurface
            border.color: root.style.cBorder
            border.width: 1
            clip: true

            ColumnLayout {
                id: dialogContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 17
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: root.dialogTitle()
                    color: root.style.cTextOnSurface
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.dialogSubtitle()
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                AccountField {
                    visible: root.dialogMode === "offline"
                    Layout.fillWidth: true
                    style: root.style
                    label: "玩家名"
                    textValue: root.offlineName
                    placeholderText: "Steve"
                    onEdited: function(value) {
                        root.offlineName = value
                    }
                }

                Rectangle {
                    visible: root.dialogMode === "microsoft"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 4
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1

                    Text {
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "当前后端使用浏览器 OAuth。需要你自己的 Azure Public Client ID。"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                AccountField {
                    visible: root.dialogMode === "microsoft"
                    Layout.fillWidth: true
                    style: root.style
                    label: "Microsoft Client ID"
                    textValue: root.microsoftClientId
                    placeholderText: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                    onEdited: function(value) {
                        root.microsoftClientId = value
                    }
                }

                AccountField {
                    visible: root.dialogMode === "yggdrasil"
                    Layout.fillWidth: true
                    style: root.style
                    label: "服务器 API 根地址"
                    textValue: root.yggdrasilServer
                    placeholderText: "https://littleskin.cn/api/yggdrasil"
                    onEdited: function(value) {
                        root.yggdrasilServer = value
                    }
                }

                AccountField {
                    visible: root.dialogMode === "yggdrasil"
                    Layout.fillWidth: true
                    style: root.style
                    label: "用户名 / 邮箱"
                    textValue: root.yggdrasilUsername
                    placeholderText: "name@example.com"
                    onEdited: function(value) {
                        root.yggdrasilUsername = value
                    }
                }

                AccountField {
                    visible: root.dialogMode === "yggdrasil"
                    Layout.fillWidth: true
                    style: root.style
                    label: "密码"
                    textValue: root.yggdrasilPassword
                    placeholderText: "Password"
                    password: true
                    onEdited: function(value) {
                        root.yggdrasilPassword = value
                    }
                }

                AccountField {
                    visible: root.dialogMode === "addServer"
                    Layout.fillWidth: true
                    style: root.style
                    label: "服务器名称"
                    textValue: root.addServerName
                    placeholderText: "LittleSkin"
                    onEdited: function(value) {
                        root.addServerName = value
                    }
                }

                AccountField {
                    visible: root.dialogMode === "addServer"
                    Layout.fillWidth: true
                    style: root.style
                    label: "服务器 API 根地址"
                    textValue: root.addServerUrl
                    placeholderText: "https://example.com/api/yggdrasil"
                    onEdited: function(value) {
                        root.addServerUrl = value
                    }
                }

                Text {
                    visible: root.backend.output.length > 0
                             && (root.dialogMode === "microsoft" || root.dialogMode === "yggdrasil")
                    Layout.fillWidth: true
                    text: root.backend.output
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    DialogButton {
                        style: root.style
                        text: "取消"
                        onClicked: root.closeDialog()
                    }

                    DialogButton {
                        style: root.style
                        text: root.dialogAcceptText()
                        primary: true
                        onClicked: root.acceptDialog()
                    }
                }
            }
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
                                size: 44
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

    function openDialog(mode) {
        root.dialogMode = mode
    }

    function closeDialog() {
        root.dialogMode = ""
    }

    function dialogTitle() {
        if (root.dialogMode === "offline") return "添加离线账户"
        if (root.dialogMode === "microsoft") return "添加 Microsoft 账户"
        if (root.dialogMode === "yggdrasil") return "添加第三方服务器账户"
        if (root.dialogMode === "addServer") return "添加认证服务器"
        return ""
    }

    function dialogSubtitle() {
        if (root.dialogMode === "offline") return "创建一个本地离线账户。"
        if (root.dialogMode === "microsoft") return "打开系统浏览器完成 Microsoft 正版登录。"
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

        if (root.dialogMode === "microsoft") {
            root.backend.loginMicrosoftBrowser(root.microsoftClientId)
            root.reloadAccounts()
            root.closeDialog()
            return
        }

        if (root.dialogMode === "yggdrasil") {
            root.backend.loginYggdrasil(root.yggdrasilServer, root.yggdrasilUsername, root.yggdrasilPassword)
            root.reloadAccounts()
            root.loadPendingYggdrasilProfiles()
            if (!root.yggdrasilProfileDialogOpen) {
                root.closeDialog()
            }
            return
        }

        if (root.dialogMode === "addServer") {
            var name = root.addServerName.trim()
            var url = root.addServerUrl.trim()

            if (name.length === 0) {
                name = url
            }

            if (url.length > 0) {
                authServersModel.append({
                    "name": name,
                    "url": url,
                    "host": root.hostFromUrl(url)
                })
                root.yggdrasilServer = url
                root.closeDialog()
            }

            return
        }
    }

    function startAccountRefresh(index) {
        if (root.refreshingAccountIndex >= 0) {
            return
        }

        root.refreshingAccountIndex = index
        root.accountRefreshStatus = {
            "active": true,
            "index": index,
            "title": "正在刷新账户"
        }

        root.backend.startRefreshAccount(String(index))
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
                accountRefreshPoller.stop()
                root.refreshingAccountIndex = -1
            }
        } catch (e) {
            accountRefreshPoller.stop()
            root.refreshingAccountIndex = -1
            console.log("Failed to parse account refresh task", e)
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
                    "avatarUrl": account.avatarUrl || "",
                    "note": account.note || "",
                    "selected": !!account.selected
                })
            }
        } catch (e) {
            console.log("Failed to parse accounts JSON", e)
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
            console.log("Failed to parse pending yggdrasil profiles", e)
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
        console.log("UUID:", value)
    }

    function showUnsupportedHint(name) {
        console.log(name + " 当前后端还没有实现。")
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
        property bool selected: false
        property bool refreshing: false

        signal selectRequested()
        signal deleteRequested()
        signal refreshRequested()
        signal copyUuidRequested()
        signal moveRequested()
        signal uploadSkinRequested()

        height: 80
        radius: 4
        color: style.cSurfaceContainer
        border.color: selected ? style.cButtonSelected : style.cBorder
        border.width: selected ? 1 : 0

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.selectRequested()
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
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
                    font.pixelSize: 14
                    font.bold: card.selected
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: card.displayKind + (card.serverUrl.length > 0 ? ", 认证服务器: " + card.serverUrl : "")
                    color: card.style.cTextOnSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row {
                Layout.preferredWidth: 176
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                IconButton {
                    style: card.style
                    iconKind: "OUTPUT"
                    tooltip: "迁移账户存储"
                    onClicked: card.moveRequested()
                }

                IconButton {
                    style: card.style
                    iconKind: "REFRESH"
                    tooltip: card.refreshing ? "刷新中" : "刷新"
                    spinning: card.refreshing
                    enabled: !card.refreshing
                    onClicked: card.refreshRequested()
                }

                IconButton {
                    style: card.style
                    iconKind: "CHECKROOM"
                    tooltip: "上传皮肤"
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
            fillMode: Image.PreserveAspectFit
            visible: avatar.source.length > 0 && status !== Image.Error
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
        property bool spinning: false

        signal clicked()

        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
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
            opacity: button.enabled || button.spinning ? 1 : 0.45
            transformOrigin: Item.Center
        }

        RotationAnimator {
            target: iconGlyph
            running: button.spinning && button.visible && button.style.animationsEnabled
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 650
        }

        onSpinningChanged: {
            if (!button.spinning) {
                iconGlyph.rotation = 0
            }
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
