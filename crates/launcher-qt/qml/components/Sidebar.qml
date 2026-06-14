import QtQuick
import QtQuick.Controls
import "../components"

Rectangle {
    id: root

    required property var style
    required property var backend

    property string currentPage: "main"

    signal navigate(string page)

    width: style.sidebarWidth
    color: style.surfaceTransparent

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        clip: true
        contentWidth: availableWidth

        Column {
            width: root.width - 20
            spacing: 6

            SectionTitle {
                text: "ACCOUNT"
                style: root.style
            }

            NavItem {
                title: "离线账户"
                subtitle: "Steve"
                selected: root.currentPage === "account"
                style: root.style
                onClicked: root.navigate("account")
            }

            SectionTitle {
                text: "VERSION"
                style: root.style
            }

            NavItem {
                title: "当前游戏"
                subtitle: "未选择版本"
                selected: root.currentPage === "main"
                style: root.style
                onClicked: root.navigate("main")
            }

            NavItem {
                title: "版本管理"
                selected: root.currentPage === "versions"
                style: root.style
                onClicked: root.navigate("versions")
            }

            NavItem {
                title: "下载"
                selected: root.currentPage === "download"
                style: root.style
                onClicked: root.navigate("download")
            }

            SectionTitle {
                text: "SETTINGS"
                style: root.style
            }

            NavItem {
                title: "启动器设置"
                selected: root.currentPage === "settings"
                style: root.style
                onClicked: root.navigate("settings")
            }

            NavItem {
                title: "Java 管理"
                selected: root.currentPage === "java"
                style: root.style
                onClicked: root.navigate("java")
            }

            NavItem {
                title: "反馈"
                selected: root.currentPage === "feedback"
                style: root.style
                onClicked: root.navigate("feedback")
            }
        }
    }
}
