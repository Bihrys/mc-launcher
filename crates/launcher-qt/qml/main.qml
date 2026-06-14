import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import com.bihrys.launcher

ApplicationWindow {
    id: window

    width: 960
    height: 600
    minimumWidth: 840
    minimumHeight: 520
    visible: true
    title: "MC Launcher"
    flags: Qt.Window | Qt.FramelessWindowHint

    property string currentPage: "main"

    property color cPrimary: "#4352A5"
    property color cPrimaryContainer: "#5C6BC0"
    property color cTextOnPrimaryContainer: "#F8F6FF"

    property color cSurfaceTransparent: "#EEFBF8FF"
    property color cSurfaceContainer: "#CCF5F2FA"
    property color cSurfaceContainerHigh: "#E8F5F2FA"

    property color cTextOnSurface: "#1B1B21"
    property color cTextOnSurfaceVariant: "#454651"

    property color cNavSelected: "#80D0D5FD"
    property color cNavHover: "#44D0D5FD"

    property color cLaunchButton: "#4352A5"
    property color cLaunchButtonHover: "#5363BF"
    property color cLaunchButtonText: "#FFFFFF"

    property int titleBarHeightValue: 42
    property int sidebarWidthValue: 245
    property int radiusValue: 8

    LauncherBackend {
        id: backend
    }

    ListModel {
        id: navModel

        ListElement { kind: "section"; label: "ACCOUNT"; page: ""; subtitle: "" }
        ListElement { kind: "item"; label: "离线账户"; page: "account"; subtitle: "Steve" }

        ListElement { kind: "section"; label: "VERSION"; page: ""; subtitle: "" }
        ListElement { kind: "item"; label: "当前游戏"; page: "main"; subtitle: "未选择版本" }
        ListElement { kind: "item"; label: "版本管理"; page: "versions"; subtitle: "" }
        ListElement { kind: "item"; label: "下载"; page: "download"; subtitle: "" }

        ListElement { kind: "section"; label: "SETTINGS"; page: ""; subtitle: "" }
        ListElement { kind: "item"; label: "启动器设置"; page: "settings"; subtitle: "" }
        ListElement { kind: "item"; label: "Java 管理"; page: "java"; subtitle: "" }
        ListElement { kind: "item"; label: "反馈"; page: "feedback"; subtitle: "" }
    }

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#F8F6FF" }
            GradientStop { position: 1.0; color: "#DDE2FF" }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: window.cSurfaceTransparent
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: window.titleBarHeightValue
            color: window.cPrimaryContainer

            DragHandler {
                onActiveChanged: {
                    if (active) {
                        window.startSystemMove()
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                spacing: 8

                Rectangle {
                    width: 22
                    height: 22
                    radius: 5
                    color: window.cPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "M"
                        color: window.cLaunchButtonText
                        font.bold: true
                        font.pixelSize: 13
                    }
                }

                Text {
                    text: "MC Launcher"
                    color: window.cTextOnPrimaryContainer
                    font.bold: true
                    font.pixelSize: 14
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 42
                    height: window.titleBarHeightValue
                    color: minMouse.containsMouse ? "#225B62C8" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "—"
                        color: window.cTextOnPrimaryContainer
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: minMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.showMinimized()
                    }
                }

                Rectangle {
                    width: 42
                    height: window.titleBarHeightValue
                    color: maxMouse.containsMouse ? "#225B62C8" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: window.visibility === Window.Maximized ? "❐" : "□"
                        color: window.cTextOnPrimaryContainer
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: maxMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (window.visibility === Window.Maximized) {
                                window.showNormal()
                            } else {
                                window.showMaximized()
                            }
                        }
                    }
                }

                Rectangle {
                    width: 42
                    height: window.titleBarHeightValue
                    color: closeMouse.containsMouse ? "#D32F2F" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: window.cTextOnPrimaryContainer
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                id: sidebar

                Layout.preferredWidth: window.sidebarWidthValue
                Layout.fillHeight: true
                color: window.cSurfaceTransparent

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    contentWidth: availableWidth

                    Column {
                        width: sidebar.width - 20
                        spacing: 6

                        Repeater {
                            model: navModel

                            delegate: Item {
                                width: parent.width
                                height: kind === "section" ? 34 : subtitle.length > 0 ? 58 : 46

                                Text {
                                    visible: kind === "section"
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 5
                                    text: label
                                    color: window.cTextOnSurfaceVariant
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Rectangle {
                                    visible: kind === "item"
                                    anchors.fill: parent
                                    radius: 6
                                    color: page === window.currentPage
                                           ? window.cNavSelected
                                           : navMouse.containsMouse ? window.cNavHover : "transparent"

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    MouseArea {
                                        id: navMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: window.currentPage = page
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        spacing: 3

                                        Text {
                                            width: parent.width
                                            text: label
                                            color: window.cTextOnSurface
                                            font.pixelSize: 14
                                            font.bold: page === window.currentPage
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            visible: subtitle.length > 0
                                            text: subtitle
                                            color: window.cTextOnSurfaceVariant
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    anchors.fill: parent
                    visible: window.currentPage === "main"

                    Column {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 24
                        anchors.bottomMargin: 96
                        spacing: 14

                        Rectangle {
                            width: Math.min(parent.width, 520)
                            height: 108
                            radius: window.radiusValue
                            color: window.cSurfaceContainerHigh

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                Text {
                                    text: "Hello Minecraft! Launcher 风格首页"
                                    color: window.cTextOnSurface
                                    font.pixelSize: 19
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: "这是 Qt/QML 主界面壳。后续可以把账号、版本、下载、设置等页面逐步接入 Rust 后端。"
                                    color: window.cTextOnSurfaceVariant
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Row {
                            spacing: 10

                            Button {
                                text: "检测 Java"
                                onClicked: backend.detectJava()
                            }

                            Button {
                                text: "刷新版本"
                                onClicked: console.log("refresh versions")
                            }
                        }

                        Rectangle {
                            width: Math.min(parent.width, 620)
                            height: 230
                            radius: window.radiusValue
                            color: window.cSurfaceContainer

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    text: "后端输出"
                                    color: window.cTextOnSurface
                                    font.bold: true
                                    font.pixelSize: 14
                                }

                                TextArea {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    readOnly: true
                                    wrapMode: TextEdit.Wrap
                                    text: backend.output
                                    placeholderText: "等待 Rust 后端输出..."
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: window.currentPage !== "main"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 24
                        width: Math.min(parent.width - 48, 520)
                        height: 120
                        radius: window.radiusValue
                        color: window.cSurfaceContainerHigh

                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 8

                            Text {
                                text: window.getPageTitle(window.currentPage)
                                color: window.cTextOnSurface
                                font.pixelSize: 21
                                font.bold: true
                            }

                            Text {
                                width: parent.width
                                text: "页面占位。下一步把 HMCL 对应页面的控件和 Rust 后端接口接进这里。"
                                color: window.cTextOnSurfaceVariant
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Rectangle {
                    id: launchButton

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 24

                    width: 245
                    height: 56
                    radius: 8
                    color: launchMainMouse.containsMouse || launchMenuMouse.containsMouse
                           ? window.cLaunchButtonHover
                           : window.cLaunchButton

                    Row {
                        anchors.fill: parent

                        Item {
                            width: launchButton.width - 38
                            height: launchButton.height

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "启动游戏"
                                    color: window.cLaunchButtonText
                                    font.bold: true
                                    font.pixelSize: 16
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "未选择版本"
                                    color: window.cLaunchButtonText
                                    opacity: 0.82
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: launchMainMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("launch")
                            }
                        }

                        Rectangle {
                            width: 1
                            height: launchButton.height
                            color: "#55FFFFFF"
                        }

                        Item {
                            width: 37
                            height: launchButton.height

                            Text {
                                anchors.centerIn: parent
                                text: "▲"
                                color: window.cLaunchButtonText
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: launchMenuMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.currentPage = "versions"
                            }
                        }
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
