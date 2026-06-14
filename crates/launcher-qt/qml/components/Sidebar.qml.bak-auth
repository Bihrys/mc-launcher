import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property var style
    property string currentPage: "main"

    signal navigate(string page)

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

            SectionTitle {
                style: root.style
                title: "ACCOUNT"
            }

            NavItem {
                style: root.style
                title: "离线账户"
                subtitle: "Steve"
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
                subtitle: "未选择版本"
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
                title: "启动器设置"
                page: "settings"
                currentPage: root.currentPage
                onClicked: function(page) {
                    root.navigate(page)
                }
            }

            NavItem {
                style: root.style
                title: "Java 管理"
                page: "java"
                currentPage: root.currentPage
                onClicked: function(page) {
                    root.navigate(page)
                }
            }

            NavItem {
                style: root.style
                title: "反馈"
                page: "feedback"
                currentPage: root.currentPage
                onClicked: function(page) {
                    root.navigate(page)
                }
            }
        }
    }
}
