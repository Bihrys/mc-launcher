import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "pages"

Item {
    id: root

    required property var window
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
        color: style.surfaceTransparent
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TitleBar {
            Layout.fillWidth: true
            window: root.window
            style: style
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.preferredWidth: style.sidebarWidth
                Layout.fillHeight: true
                style: style
                backend: root.backend
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
                    pageTitle: root.pageTitle(root.currentPage)
                }

                SplitLaunchButton {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 24
                    style: style
                    title: "启动游戏"
                    subtitle: "未选择版本"
                    onLaunchClicked: {
                        if (backend && typeof backend.launch === "function") {
                            backend.launch()
                        } else {
                            console.log("launch")
                        }
                    }
                    onMenuClicked: {
                        root.currentPage = "versions"
                    }
                }
            }
        }
    }

    function pageTitle(page) {
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
