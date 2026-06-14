import QtQuick
import QtQuick.Layouts
import "components"
import "pages"

Item {
    id: root

    required property var appWindow
    required property var backend

    property string currentPage: "main"

    Style {
        id: style
    }

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#F8F6FF"
            }

            GradientStop {
                position: 1.0
                color: "#DDE2FF"
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

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.preferredWidth: style.sidebarWidthValue
                Layout.fillHeight: true
                style: style
                currentPage: root.currentPage
                onNavigate: function(page) {
                    root.currentPage = page
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MainPage {
                    anchors.fill: parent
                    visible: root.currentPage === "main"
                    style: style
                    backend: root.backend
                }

                PlaceholderPage {
                    anchors.fill: parent
                    visible: root.currentPage !== "main"
                    style: style
                    titleText: root.getPageTitle(root.currentPage)
                }

                SplitLaunchButton {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 24

                    style: style
                    title: "启动游戏"
                    subtitle: "未选择版本"

                    onLaunchClicked: {
                        console.log("launch")
                    }

                    onMenuClicked: {
                        root.currentPage = "versions"
                    }
                }
            }
        }
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
        default:
            return "页面"
        }
    }
}
