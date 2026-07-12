import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../components"

// Qt Quick port of HMCL CreateAccountPane. The content spacing and width follow
// AccountDetailsInputPane (560 px, 22 px row gap, 15 px column gap).
Item {
    id: root

    required property var style
    required property var backend

    property string mode: "offline" // offline | yggdrasil
    property string serverName: ""
    property string serverUrl: ""
    property var serverLinks: ({})
    property bool nonEmailLogin: false
    property bool busy: false
    property string errorText: ""

    property string offlineName: "Steve"
    property string offlineUuid: ""
    property bool offlineAdvanced: false
    property string offlineAvatarUrl: ""

    property string yggdrasilUsername: ""
    property string yggdrasilPassword: ""
    signal offlineAccepted(string username, string uuid)
    signal yggdrasilAccepted(string serverUrl, string username, string password)
    signal canceled()

    function begin(newMode) {
        mode = newMode
        errorText = ""
        busy = false
        if (mode === "offline") {
            offlineName = "Steve"
            offlineUuid = ""
            offlineAdvanced = false
            updateOfflineAvatar()
        } else if (mode === "yggdrasil") {
            yggdrasilUsername = ""
            yggdrasilPassword = ""
        }
    }

    function updateOfflineAvatar() {
        offlineAvatarUrl = backend.offlineAvatarPreview(offlineName)
    }

    function accept() {
        errorText = ""
        if (mode === "offline") {
            if (offlineName.trim().length === 0) {
                errorText = "玩家名不能为空。"
                return
            }
            offlineAccepted(offlineName.trim(), offlineAdvanced ? offlineUuid.trim() : "")
        } else if (mode === "yggdrasil") {
            if (yggdrasilUsername.trim().length === 0 || yggdrasilPassword.length === 0) {
                errorText = "用户名和密码不能为空。"
                return
            }
            yggdrasilAccepted(serverUrl, yggdrasilUsername.trim(), yggdrasilPassword)
        }
    }

    Rectangle { anchors.fill: parent; color: "#80000000" }
    MouseArea { anchors.fill: parent }

    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: Math.min(root.width - 64, 560)
        height: Math.min(root.height - 48,
                         root.mode === "offline" ? (root.offlineAdvanced ? 430 : 322) : 348)
        radius: 4
        color: root.style.cSurface
        border.color: root.style.cBorder
        border.width: 1
        clip: true
        scale: root.visible ? 1 : 0.97
        opacity: root.visible ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: root.style.animationsEnabled ? root.style.motionShort4 : 0
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 24
            anchors.bottomMargin: 16
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: root.mode === "offline" ? "添加离线账户" : "添加第三方账户"
                color: root.style.cTextOnSurface
                font.pixelSize: 20
                font.bold: true
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.mode === "offline" ? 0 : 1

                ColumnLayout {
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: 10
                        AvatarBox {
                            style: root.style
                            source: root.offlineAvatarUrl
                            fallbackText: root.offlineName.length > 0 ? root.offlineName.substring(0, 1).toUpperCase() : "?"
                            size: 44
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: "离线账户"; color: root.style.cTextOnSurface; font.pixelSize: 13; font.bold: true }
                            Text { text: "头像由离线 UUID 按 HMCL 规则从 Minecraft 默认皮肤生成。"; color: root.style.cTextOnSurfaceVariant; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }

                    FormRow {
                        style: root.style
                        label: "玩家名"
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "仅建议使用英文字母、数字和下划线"
                            text: root.offlineName
                            selectByMouse: true
                            onTextEdited: {
                                root.offlineName = text
                                root.updateOfflineAvatar()
                            }
                            onAccepted: root.accept()
                        }
                    }

                    Text {
                        text: "购买 Minecraft"
                        color: root.style.cButtonSelected
                        font.pixelSize: 12
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.backend.openUrl("https://www.minecraft.net/store/minecraft-java-bedrock-edition-pc") }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            HmclSvgIcon {
                                icon: root.offlineAdvanced ? "ARROW_DROP_UP" : "ARROW_DROP_DOWN"
                                iconSize: 18
                                iconColor: root.style.cTextOnSurfaceVariant
                                animationsEnabled: root.style.animationsEnabled
                            }
                            Text { text: "高级设置"; color: root.style.cTextOnSurface; font.pixelSize: 12 }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.offlineAdvanced = !root.offlineAdvanced }
                    }

                    FormRow {
                        visible: root.offlineAdvanced
                        style: root.style
                        label: "UUID"
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "留空时根据玩家名自动生成"
                            text: root.offlineUuid
                            selectByMouse: true
                            onTextEdited: root.offlineUuid = text
                            onAccepted: root.accept()
                        }
                    }

                    Rectangle {
                        visible: root.offlineAdvanced
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: 4
                        color: root.style.cSurfaceContainer
                        border.color: root.style.cBorder
                        Text {
                            anchors.fill: parent
                            anchors.margins: 9
                            text: "更改 UUID 会改变默认皮肤，并可能导致已有单人世界中的玩家数据无法对应。"
                            color: "#b26a00"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    spacing: 15

                    FormRow {
                        style: root.style
                        label: "认证服务器"
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: root.serverName.length > 0 ? root.serverName : root.serverUrl
                                color: root.style.cTextOnSurface
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: root.serverLinks && root.serverLinks.homepage
                                text: "主页"
                                color: root.style.cButtonSelected
                                font.pixelSize: 11
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.backend.openUrl(root.serverLinks.homepage) }
                            }
                            Text {
                                visible: root.serverLinks && root.serverLinks.register
                                text: "注册"
                                color: root.style.cButtonSelected
                                font.pixelSize: 11
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.backend.openUrl(root.serverLinks.register) }
                            }
                        }
                    }

                    FormRow {
                        style: root.style
                        label: "用户名"
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: root.nonEmailLogin ? "用户名或邮箱" : "邮箱"
                            text: root.yggdrasilUsername
                            selectByMouse: true
                            enabled: !root.busy
                            onTextEdited: root.yggdrasilUsername = text
                        }
                    }

                    FormRow {
                        style: root.style
                        label: "密码"
                        TextField {
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            text: root.yggdrasilPassword
                            selectByMouse: true
                            enabled: !root.busy
                            onTextEdited: root.yggdrasilPassword = text
                            onAccepted: root.accept()
                        }
                    }

                    Rectangle {
                        visible: root.errorText.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 4
                        color: root.style.cSurfaceContainer
                        border.color: "#d32f2f"
                        Text { anchors.fill: parent; anchors.margins: 9; text: root.errorText; color: "#d32f2f"; font.pixelSize: 11; wrapMode: Text.WordWrap }
                    }
                    Item { Layout.fillHeight: true }
                }

            }

            Text {
                visible: root.errorText.length > 0 && root.mode !== "yggdrasil"
                Layout.fillWidth: true
                text: root.errorText
                color: "#d32f2f"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                PaneButton { style: root.style; text: root.busy ? "正在登录" : "登录"; primary: true; enabled: !root.busy; onClicked: root.accept() }
                PaneButton { style: root.style; text: "取消"; onClicked: root.canceled() }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 3
            visible: root.busy
            color: root.style.cButtonSelected
        }
    }

    component FormRow: RowLayout {
        id: row
        required property var style
        property string label: ""
        spacing: 15
        Text { Layout.preferredWidth: 100; text: row.label; color: row.style.cTextOnSurface; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
    }

    component AvatarBox: Rectangle {
        id: avatar
        required property var style
        property string source: ""
        property string fallbackText: "?"
        property int size: 44
        Layout.preferredWidth: size
        Layout.preferredHeight: size
        width: size
        height: size
        radius: 4
        color: style.cButtonSurface
        border.color: style.cBorder
        border.width: 1
        clip: true
        Image { id: image; anchors.fill: parent; source: avatar.source; asynchronous: true; smooth: false; mipmap: false; cache: false; visible: status === Image.Ready }
        Text { anchors.centerIn: parent; visible: !image.visible; text: avatar.fallbackText; color: avatar.style.cTextOnSurfaceVariant; font.pixelSize: 18; font.bold: true }
    }

    component PaneButton: Rectangle {
        id: button
        required property var style
        property string text: ""
        property bool primary: false
        signal clicked()
        implicitWidth: Math.max(72, label.implicitWidth + 24)
        implicitHeight: 34
        radius: 3
        color: primary ? style.cButtonSelected : (mouse.containsMouse ? style.cNavHover : "transparent")
        opacity: enabled ? 1 : 0.45
        Text { id: label; anchors.centerIn: parent; text: button.text; color: button.primary ? "white" : button.style.cTextOnSurface; font.pixelSize: 12 }
        MouseArea { id: mouse; anchors.fill: parent; enabled: button.enabled; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: button.clicked() }
    }
}
