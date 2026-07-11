import QtQuick
import "components"

Item {
    id: root
    required property var style
    required property var controller

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        DownloadClassTitle {
            width: parent.width
            style: root.style
            text: "游戏"
        }

        DownloadNavItem {
            width: parent.width
            style: root.style
            iconSource: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/grass.png"
            title: "游戏"
            subtitle: "Minecraft"
            selected: root.controller.currentTab === "game"
            onClicked: root.controller.currentTab = "game"
        }

        DownloadNavItem {
            width: parent.width
            style: root.style
            iconKind: "PACKAGE2"
            title: "整合包"
            subtitle: "Modpack"
            selected: root.controller.currentTab === "modpack"
            onClicked: root.controller.currentTab = "modpack"
        }

        DownloadClassTitle {
            width: parent.width
            style: root.style
            text: "内容"
        }

        DownloadNavItem {
            width: parent.width
            style: root.style
            iconKind: "EXTENSION"
            title: "Mod"
            subtitle: "CurseForge / Modrinth"
            selected: root.controller.currentTab === "mod"
            onClicked: root.controller.currentTab = "mod"
        }

        DownloadNavItem {
            width: parent.width
            style: root.style
            iconKind: "TEXTURE"
            title: "资源包"
            subtitle: "Resource Pack"
            selected: root.controller.currentTab === "resourcepack"
            onClicked: root.controller.currentTab = "resourcepack"
        }

        DownloadNavItem {
            width: parent.width
            style: root.style
            iconKind: "WB_SUNNY"
            title: "光影包"
            subtitle: "Shader"
            selected: root.controller.currentTab === "shader"
            onClicked: root.controller.currentTab = "shader"
        }

        DownloadNavItem {
            width: parent.width
            style: root.style
            iconKind: "PUBLIC"
            title: "世界"
            subtitle: "World"
            selected: root.controller.currentTab === "world"
            onClicked: root.controller.currentTab = "world"
        }

        Item { width: parent.width; height: 4 }
        Rectangle { width: parent.width; height: 1; color: root.style.cBorder }

        Text {
            width: parent.width
            text: root.controller.catalog
                  ? "最新正式版 " + root.controller.catalog.latestRelease
                    + "\n最新快照 " + root.controller.catalog.latestSnapshot
                  : ""
            color: root.style.cTextOnSurfaceVariant
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
}
