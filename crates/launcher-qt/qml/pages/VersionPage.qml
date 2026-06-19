import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    ListModel {
        id: versionModel
    }

    property string minecraftRoot: ""
    property string selectedVersion: ""

    Component.onCompleted: root.reloadVersions()

    onVisibleChanged: {
        if (visible) {
            root.reloadVersions()
        }
    }

    Connections {
        target: root.backend

        function onInstalledVersionsJsonChanged() {
            root.applyVersionsJson(root.backend.installedVersionsJson)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        anchors.bottomMargin: 96
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "版本管理"
                    color: root.style.cTextOnSurface
                    font.pixelSize: 24
                    font.bold: true
                }

                Text {
                    text: root.minecraftRoot.length > 0
                          ? "Minecraft 根目录：" + root.minecraftRoot
                          : "管理已安装版本，选择后即可启动。"
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideLeft
                    width: parent.width
                }
            }

            ActionButton {
                style: root.style
                text: "刷新"
                primary: false
                onClicked: root.reloadVersions()
            }

            ActionButton {
                style: root.style
                text: "启动所选版本"
                primary: true
                onClicked: root.backend.launchSelectedVersion()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 960
            Layout.fillHeight: true
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 360
                    Layout.fillHeight: true
                    radius: root.style.radiusValue
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "已安装版本"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: versionModel.count > 0
                                  ? "点击版本选择。双击可生成启动命令预览。"
                                  : "还没有已安装版本。请先到下载页安装。"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        ListView {
                            id: versionList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: versionModel
                            spacing: 8
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Rectangle {
                                id: item

                                width: versionList.width
                                height: 78
                                radius: 8
                                color: selected
                                       ? root.style.cNavSelected
                                       : mouse.containsMouse ? root.style.cNavHover : "transparent"
                                border.width: selected ? 1 : 0
                                border.color: root.style.cBorder

                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.backend.selectGameVersion(versionId)
                                        root.reloadVersions()
                                    }

                                    onDoubleClicked: {
                                        root.backend.generateLaunchCommand(versionId)
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 46
                                        Layout.preferredHeight: 46
                                        radius: 8
                                        color: root.style.cButtonSurface
                                        border.color: root.style.cBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: selected ? "✓" : "▶"
                                            color: root.style.cTextOnSurface
                                            font.pixelSize: 20
                                            font.bold: true
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: versionId
                                            color: root.style.cTextOnSurface
                                            font.pixelSize: 15
                                            font.bold: selected
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: versionType
                                                  + (inheritsFrom.length > 0 ? " · inherits " + inheritsFrom : "")
                                                  + (javaMajor > 0 ? " · Java " + javaMajor : "")
                                            color: root.style.cTextOnSurfaceVariant
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: hasClientJar ? "client jar 已存在" : "无 client jar，可能是 loader profile"
                                            color: root.style.cTextOnSurfaceVariant
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }

                                    SmallButton {
                                        style: root.style
                                        text: "命令"
                                        onClicked: root.backend.generateLaunchCommand(versionId)
                                    }

                                    SmallButton {
                                        style: root.style
                                        text: "删除"
                                        onClicked: {
                                            root.backend.deleteGameVersion(versionId)
                                            root.reloadVersions()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.style.radiusValue
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "启动输出"
                            color: root.style.cTextOnSurface
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedVersion.length > 0
                                  ? "当前选择：" + root.selectedVersion
                                  : "还没有选择版本。"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            radius: root.style.radiusValue
                            color: root.style.cSurfaceContainerHigh
                            border.color: root.style.cBorder
                            border.width: 1

                            Text {
                                anchors.fill: parent
                                anchors.margins: 12
                                text: "启动前会按 HMCL 思路执行：解析 version.json → 处理 inheritsFrom → 合并 libraries/arguments → 生成 classpath → 解压 natives → 写 launch 脚本 → 启动 Java 进程。"
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            TextArea {
                                width: parent.width
                                readOnly: true
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                text: root.backend.output
                                placeholderText: "启动输出会显示在这里。"
                                color: root.style.cTextOnSurface
                                placeholderTextColor: root.style.cTextOnSurfaceVariant
                                background: Item {}
                            }
                        }
                    }
                }
            }
        }
    }

    function reloadVersions() {
        var raw = root.backend.refreshInstalledVersions()
        root.applyVersionsJson(raw)
    }

    function applyVersionsJson(raw) {
        if (!raw || raw.length === 0) {
            return
        }

        var payload = JSON.parse(raw)

        versionModel.clear()

        root.minecraftRoot = payload.minecraftRoot || ""
        root.selectedVersion = payload.selectedVersion || ""

        if (!payload.versions) {
            return
        }

        for (var i = 0; i < payload.versions.length; i++) {
            var version = payload.versions[i]

            versionModel.append({
                "versionId": version.id || "",
                "versionType": version.versionType || "",
                "inheritsFrom": version.inheritsFrom || "",
                "mainClass": version.mainClass || "",
                "javaMajor": version.javaMajor || 0,
                "hasClientJar": !!version.hasClientJar,
                "hasVersionJson": !!version.hasVersionJson,
                "selected": !!version.selected,
                "path": version.path || ""
            })
        }
    }

    component ActionButton: Rectangle {
        id: button

        required property var style
        property string text: ""
        property bool primary: false

        signal clicked()

        width: Math.max(126, label.implicitWidth + 28)
        height: 38
        radius: 19

        color: primary
               ? mouse.containsMouse ? style.cLaunchButtonHover : style.cLaunchButton
               : mouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: primary ? 0 : 1
        border.color: style.cBorder

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

    component SmallButton: Rectangle {
        id: button

        required property var style
        property string text: ""

        signal clicked()

        width: Math.max(52, label.implicitWidth + 18)
        height: 28
        radius: 14

        color: mouse.containsMouse ? style.cButtonHover : style.cButtonSurface
        border.width: 1
        border.color: style.cBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.style.cTextOnSurface
            font.pixelSize: 12
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
