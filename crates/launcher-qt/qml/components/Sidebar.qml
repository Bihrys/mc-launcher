import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property var style
    required property var backend
    property string currentPage: "main"

    signal navigate(string page)
    signal prepareSettings()

    width: style.sidebarWidthValue
    color: style.cSurfaceTransparent

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true
        contentWidth: availableWidth

        Column {
            width: root.width - 20
            spacing: 6

            Rectangle {
                width: parent.width
                height: 82
                radius: root.style.radiusValue
                color: root.style.cSurfaceContainer
                border.color: root.style.cBorder
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        width: 52
                        height: 52
                        radius: 8
                        color: root.style.cButtonSurface
                        border.color: root.style.cBorder
                        border.width: 1
                        clip: true

                        Image {
                            id: accountAvatarImage
                            anchors.fill: parent
                            anchors.margins: 2
                            source: root.backend.currentAccountAvatarUrl
                            fillMode: Image.PreserveAspectFit
                            visible: root.backend.currentAccountAvatarUrl.length > 0 && status !== Image.Error
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.backend.currentAccountName.length > 0
                                  ? root.backend.currentAccountName.substring(0, 1).toUpperCase()
                                  : "?"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 24
                            font.bold: true
                            visible: !accountAvatarImage.visible
                        }
                    }

                    Column {
                        width: parent.width - 72
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            text: root.backend.currentAccountName.length > 0
                                  ? root.backend.currentAccountName
                                  : "未登录"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.backend.currentAccountKind.length > 0
                                  ? root.backend.currentAccountKind
                                  : "添加账户后显示头像"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            SectionTitle {
                style: root.style
                title: "ACCOUNT"
            }

            NavItem {
                style: root.style
                title: "账户管理"
                subtitle: "离线 / 微软 / 第三方"
                page: "account"
                currentPage: root.currentPage
                onClicked: function(page) {
                    root.navigate(page)
                }
            }

            SectionTitle {
                style: root.style
                title: "VERSION"
            }

            NavItem {
                style: root.style
                title: "当前游戏"
                subtitle: root.backend.selectedGameVersion.length > 0 ? root.backend.selectedGameVersion : "未选择版本"
                page: "main"
                currentPage: root.currentPage
                onClicked: function(page) {
                    root.navigate(page)
                }
            }

            NavItem {
                style: root.style
                title: "版本管理"
                page: "versions"
                currentPage: root.currentPage
                onClicked: function(page) {
                    root.navigate(page)
                }
            }

            NavItem {
                style: root.style
                title: "下载"
                subtitle: "原版 / Fabric / Quilt / Forge"
                page: "download"
                currentPage: root.currentPage
                onClicked: function(page) {
                    root.navigate(page)
                }
            }

            SectionTitle {
                style: root.style
                title: "SETTINGS"
            }

            NavItem {
                style: root.style
                title: "设置"
                subtitle: "全局 / Java / 通用 / 下载 / 帮助 / 关于"
                page: "settings"
                currentPage: root.currentPage
                onEntered: function(page) {
                    root.prepareSettings()
                }
                onClicked: function(page) {
                    root.navigate(page)
                }
            }
        }
    }
}
