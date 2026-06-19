import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property var style
    required property var backend
    property string currentPage: "main"

    signal navigate(string page)
    signal navigateSettingsSection(string section)
    signal prepareSettings()
    signal prepareDownload()
    signal prepareVersion()

    width: 200
    color: "transparent"

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: hovered ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        property bool hovered: false

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
        }

        Column {
            width: root.width
            spacing: 0

            Item { width: 1; height: 12 }

            HmclClassTitle {
                style: root.style
                title: "账户"
            }

            HmclAccountItem {
                style: root.style
                accountName: root.backend.currentAccountName.length > 0
                             ? root.backend.currentAccountName
                             : "未登录"
                accountType: root.backend.currentAccountKind.length > 0
                             ? root.backend.currentAccountKind
                             : "添加账户"
                avatarUrl: root.backend.currentAccountAvatarUrl
                active: root.currentPage === "account"
                onClicked: root.navigate("account")
            }

            HmclClassTitle {
                style: root.style
                title: "版本"
            }

            HmclListItem {
                style: root.style
                title: root.backend.selectedGameVersion.length > 0
                       ? root.backend.selectedGameVersion
                       : "未选择版本"
                subtitle: root.backend.selectedGameVersion.length > 0
                          ? "当前游戏"
                          : "选择或下载游戏版本"
                iconKind: "game"
                active: root.currentPage === "main"
                onEntered: root.prepareVersion()
                onClicked: {
                    if (root.backend.selectedGameVersion.length > 0) {
                        root.navigate("versions")
                    } else {
                        root.navigate("versions")
                    }
                }
            }

            HmclListItem {
                style: root.style
                title: "版本管理"
                subtitle: ""
                iconKind: "list"
                active: root.currentPage === "versions"
                onEntered: root.prepareVersion()
                onClicked: root.navigate("versions")
            }

            HmclListItem {
                style: root.style
                title: "下载"
                subtitle: ""
                iconKind: "download"
                active: root.currentPage === "download"
                onEntered: root.prepareDownload()
                onClicked: root.navigate("download")
            }

            HmclClassTitle {
                style: root.style
                title: "通用"
            }

            HmclListItem {
                style: root.style
                title: "设置"
                subtitle: ""
                iconKind: "settings"
                active: root.currentPage === "settings"
                onEntered: root.prepareSettings()
                onClicked: {
                    root.prepareSettings()
                    root.navigateSettingsSection("global")
                }
            }

            HmclListItem {
                style: root.style
                title: "Terracotta"
                subtitle: "待开发"
                iconKind: "graph"
                active: root.currentPage === "terracotta"
                onClicked: root.navigate("terracotta")
            }

            HmclListItem {
                style: root.style
                title: "聊天"
                subtitle: "反馈 / 社区"
                iconKind: "chat"
                active: root.currentPage === "feedback"
                onEntered: root.prepareSettings()
                onClicked: {
                    root.prepareSettings()
                    root.navigateSettingsSection("feedback")
                }
            }
        }
    }

    component HmclClassTitle: Item {
        id: titleItem

        required property var style
        property string title: ""

        width: parent ? parent.width : 200
        height: 34

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 4

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 0
                height: 16
                text: titleItem.title
                color: titleItem.style.cTextOnSurface
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: parent.width
                height: 1
                color: titleItem.style.cTextOnSurfaceVariant
                opacity: 0.45
            }
        }
    }

    component HmclAccountItem: Item {
        id: item

        required property var style
        property string accountName: ""
        property string accountType: ""
        property string avatarUrl: ""
        property bool active: false

        signal clicked()

        width: parent ? parent.width : 200
        height: 58

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: item.active
                   ? item.style.cNavSelected
                   : mouse.containsMouse ? item.style.cNavHover : "transparent"
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 4
            color: item.style.cButtonSurface
            border.width: 1
            border.color: item.style.cBorder
            clip: true

            Image {
                id: avatarImage
                anchors.fill: parent
                anchors.margins: 1
                source: item.avatarUrl
                fillMode: Image.PreserveAspectFit
                visible: item.avatarUrl.length > 0 && status !== Image.Error
                cache: true
            }

            Text {
                anchors.centerIn: parent
                visible: !avatarImage.visible
                text: item.accountName.length > 0 ? item.accountName.substring(0, 1).toUpperCase() : "?"
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 16
                font.bold: true
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: item.accountName
                color: item.active ? item.style.cTextOnSurface : item.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: item.active
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: item.accountType
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    component HmclListItem: Item {
        id: item

        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconKind: ""
        property bool active: false

        signal clicked()
        signal entered()

        width: parent ? parent.width : 200
        height: subtitle.length > 0 ? 58 : 52

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: item.active
                   ? item.style.cNavSelected
                   : mouse.containsMouse ? item.style.cNavHover : "transparent"
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: item.entered()
            onClicked: item.clicked()
        }

        Item {
            id: iconHost
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32

            Canvas {
                anchors.centerIn: parent
                width: 20
                height: 20

                property color iconColor: item.style.cTextOnSurface

                onIconColorChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = iconColor
                    ctx.fillStyle = iconColor
                    ctx.lineWidth = 1.7
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    if (item.iconKind === "download") {
                        ctx.beginPath()
                        ctx.moveTo(10, 3)
                        ctx.lineTo(10, 13)
                        ctx.moveTo(5.8, 9)
                        ctx.lineTo(10, 13.2)
                        ctx.lineTo(14.2, 9)
                        ctx.moveTo(4, 17)
                        ctx.lineTo(16, 17)
                        ctx.stroke()
                    } else if (item.iconKind === "settings") {
                        ctx.beginPath()
                        ctx.arc(10, 10, 5.4, 0, Math.PI * 2)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(10, 10, 1.7, 0, Math.PI * 2)
                        ctx.fill()
                        for (var i = 0; i < 8; i++) {
                            var a = i * Math.PI / 4
                            ctx.beginPath()
                            ctx.moveTo(10 + Math.cos(a) * 7.2, 10 + Math.sin(a) * 7.2)
                            ctx.lineTo(10 + Math.cos(a) * 8.6, 10 + Math.sin(a) * 8.6)
                            ctx.stroke()
                        }
                    } else if (item.iconKind === "list") {
                        for (var y = 5; y <= 15; y += 5) {
                            ctx.beginPath()
                            ctx.arc(4, y, 0.9, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.beginPath()
                            ctx.moveTo(7, y)
                            ctx.lineTo(17, y)
                            ctx.stroke()
                        }
                    } else if (item.iconKind === "chat") {
                        ctx.beginPath()
                        ctx.roundedRect(3, 4, 14, 10, 3, 3)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(7, 14)
                        ctx.lineTo(5, 17)
                        ctx.lineTo(10, 14)
                        ctx.stroke()
                    } else if (item.iconKind === "graph") {
                        ctx.beginPath()
                        ctx.moveTo(4, 15)
                        ctx.lineTo(8, 10)
                        ctx.lineTo(11, 12)
                        ctx.lineTo(16, 5)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(4, 15, 1.4, 0, Math.PI * 2)
                        ctx.arc(8, 10, 1.4, 0, Math.PI * 2)
                        ctx.arc(11, 12, 1.4, 0, Math.PI * 2)
                        ctx.arc(16, 5, 1.4, 0, Math.PI * 2)
                        ctx.fill()
                    } else {
                        ctx.beginPath()
                        ctx.rect(4, 4, 12, 12)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(7, 7)
                        ctx.lineTo(13, 7)
                        ctx.moveTo(7, 10)
                        ctx.lineTo(13, 10)
                        ctx.moveTo(7, 13)
                        ctx.lineTo(13, 13)
                        ctx.stroke()
                    }
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: item.title
                color: item.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: item.active
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
    }
}
