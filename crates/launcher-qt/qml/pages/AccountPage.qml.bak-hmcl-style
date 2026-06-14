import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    property string loginMode: "offline"

    property string offlineName: "Steve"
    property string microsoftClientId: ""
    property string yggdrasilServer: "https://example.com/api/yggdrasil"
    property string yggdrasilUsername: ""
    property string yggdrasilPassword: ""

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        anchors.bottomMargin: 96
        spacing: 18

        Text {
            text: "账户管理"
            color: root.style.cTextOnSurface
            font.pixelSize: 24
            font.bold: true
        }

        Rectangle {
            width: Math.min(parent.width, 820)
            height: 390
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Column {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "添加账户"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: "支持离线账户、Microsoft 浏览器登录和第三方 Yggdrasil/authlib-injector 服务器。"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    spacing: 8

                    ChoiceButton {
                        style: root.style
                        text: "离线"
                        selected: root.loginMode === "offline"
                        onClicked: root.loginMode = "offline"
                    }

                    ChoiceButton {
                        style: root.style
                        text: "微软"
                        selected: root.loginMode === "microsoft"
                        onClicked: root.loginMode = "microsoft"
                    }

                    ChoiceButton {
                        style: root.style
                        text: "第三方服务器"
                        selected: root.loginMode === "yggdrasil"
                        onClicked: root.loginMode = "yggdrasil"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.style.radiusValue
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1

                    Item {
                        anchors.fill: parent
                        anchors.margins: 16
                        visible: root.loginMode === "offline"

                        Column {
                            width: parent.width
                            spacing: 12

                            Text {
                                text: "离线账户"
                                color: root.style.cTextOnSurface
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: "离线账户不会进行正版验证，适合本地测试、离线游戏或第三方环境。"
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            FieldBox {
                                style: root.style
                                label: "玩家名"
                                textValue: root.offlineName
                                placeholderText: "Steve"
                                onEdited: function(value) {
                                    root.offlineName = value
                                }
                            }

                            ActionButton {
                                style: root.style
                                text: "添加离线账户"
                                primary: true
                                onClicked: root.backend.loginOffline(root.offlineName)
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 16
                        visible: root.loginMode === "microsoft"

                        Column {
                            width: parent.width
                            spacing: 12

                            Text {
                                text: "Microsoft 账户"
                                color: root.style.cTextOnSurface
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: "点击后会打开系统浏览器登录 Microsoft。授权完成后浏览器会跳回本地启动器回调地址。需要你自己的 Azure Public Client ID，不能复用 HMCL 官方 ID。"
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            FieldBox {
                                style: root.style
                                label: "Microsoft Client ID"
                                textValue: root.microsoftClientId
                                placeholderText: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                                onEdited: function(value) {
                                    root.microsoftClientId = value
                                }
                            }

                            ActionButton {
                                style: root.style
                                text: "打开浏览器登录 Microsoft"
                                primary: true
                                onClicked: root.backend.loginMicrosoftBrowser(root.microsoftClientId)
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 16
                        visible: root.loginMode === "yggdrasil"

                        Column {
                            width: parent.width
                            spacing: 12

                            Text {
                                text: "第三方服务器账户"
                                color: root.style.cTextOnSurface
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: "适用于 LittleSkin、Blessing Skin 或其他 authlib-injector/Yggdrasil 兼容服务器。"
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            FieldBox {
                                style: root.style
                                label: "服务器 API 根地址"
                                textValue: root.yggdrasilServer
                                placeholderText: "https://example.com/api/yggdrasil"
                                onEdited: function(value) {
                                    root.yggdrasilServer = value
                                }
                            }

                            FieldBox {
                                style: root.style
                                label: "用户名 / 邮箱"
                                textValue: root.yggdrasilUsername
                                placeholderText: "name@example.com"
                                onEdited: function(value) {
                                    root.yggdrasilUsername = value
                                }
                            }

                            FieldBox {
                                style: root.style
                                label: "密码"
                                textValue: root.yggdrasilPassword
                                placeholderText: "Password"
                                password: true
                                onEdited: function(value) {
                                    root.yggdrasilPassword = value
                                }
                            }

                            ActionButton {
                                style: root.style
                                text: "登录第三方服务器"
                                primary: true
                                onClicked: root.backend.loginYggdrasil(
                                    root.yggdrasilServer,
                                    root.yggdrasilUsername,
                                    root.yggdrasilPassword
                                )
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: Math.min(parent.width, 820)
            height: Math.max(170, parent.height - 480)
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainer
            border.color: root.style.cBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "输出"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 14
                    font.bold: true
                }

                TextArea {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readOnly: true
                    wrapMode: TextEdit.Wrap
                    text: root.backend.output
                    placeholderText: "登录结果会显示在这里。账户会保存到 ~/.config/mc-launcher/accounts.json"
                }
            }
        }
    }

    component FieldBox: Item {
        id: field

        required property var style
        property string label: ""
        property string textValue: ""
        property string placeholderText: ""
        property bool password: false

        signal edited(string value)

        width: parent ? parent.width : 420
        height: 58

        Column {
            anchors.fill: parent
            spacing: 5

            Text {
                text: field.label
                color: field.style.cTextOnSurfaceVariant
                font.pixelSize: 12
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 36
                radius: 8
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

    component ChoiceButton: Rectangle {
        id: button

        required property var style
        property string text: ""
        property bool selected: false

        signal clicked()

        width: Math.max(74, label.implicitWidth + 24)
        height: 34
        radius: 17

        color: selected
               ? style.cButtonSelected
               : mouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: selected ? 0 : 1
        border.color: style.cBorder

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.selected ? button.style.cButtonSelectedText : button.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: button.selected
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: button

        required property var style
        property string text: ""
        property bool primary: false

        signal clicked()

        width: Math.max(160, label.implicitWidth + 28)
        height: 38
        radius: 19

        color: primary
               ? mouse.containsMouse ? style.cLaunchButtonHover : style.cLaunchButton
               : mouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: primary ? 0 : 1
        border.color: style.cBorder

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? button.style.cLaunchButtonText : button.style.cTextOnSurface
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
