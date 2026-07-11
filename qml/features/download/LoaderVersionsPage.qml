import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "components"

Item {
    id: page
    objectName: "downloadLoaderVersionsPage"
    required property var style
    required property var controller

    function logPageState(action) {
        if (!page.controller)
            return
        page.controller.logAction(action, {
            "gameVersion": page.controller.selectedGameVersion,
            "loaderKind": page.controller.loaderVersionKind,
            "visible": page.visible,
            "enabled": page.enabled,
            "opacity": page.opacity,
            "width": page.width,
            "height": page.height
        })
    }

    Component.onCompleted: page.logPageState("loader_versions_page_completed")
    onVisibleChanged: page.logPageState("loader_versions_page_visible_changed")

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 4
                color: page.style.cSurfaceContainerHigh
                border.color: page.style.cBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: page.controller.loaderTitle(page.controller.loaderVersionKind) + " 版本"
                        color: page.style.cTextOnSurface
                        font.pixelSize: 13
                        font.bold: true
                    }

                    TextField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "输入版本名称进行搜索"
                        text: page.controller.loaderSearchText
                        onTextChanged: {
                            page.controller.loaderSearchText = text
                            page.controller.rebuildVisibleLoaderVersions()
                        }
                    }

                    DownloadButton {
                        Layout.preferredWidth: 72
                        style: page.style
                        text: "返回"
                        onClicked: page.controller.closeLoaderVersionPane()
                    }

                    DownloadButton {
                        Layout.preferredWidth: 72
                        style: page.style
                        text: "刷新"
                        primary: true
                        buttonEnabled: !page.controller.installerMetadataTaskStatus.active
                        onClicked: page.controller.startFetchLoaderMetadata(page.controller.loaderVersionKind)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                visible: false
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: page.style.cSurfaceContainerHigh
                border.color: page.style.cBorder
                border.width: 1
                clip: true

                ListView {
                    id: loaderVersionList
                    objectName: "downloadLoaderVersionList"

                    anchors.fill: parent
                    anchors.margins: 8
                    model: page.controller.visibleLoaderVersions
                    spacing: 0
                    clip: true
                    visible: !page.controller.installerMetadataTaskStatus.active
                             && page.controller.installerMetadataTaskStatus.metadataReady

                    delegate: Item {
                        id: loaderVersionDelegate

                        required property int index
                        required property int sourceIndex
                        required property string version
                        required property string subtitle

                        width: loaderVersionList.width
                        height: 64

                        DownloadVersionCell {
                            anchors.fill: parent
                            style: page.style
                            versionId: loaderVersionDelegate.version
                            tagText: page.controller.loaderTitle(page.controller.loaderVersionKind)
                            iconSource: page.controller.loaderIcon(page.controller.loaderVersionKind)
                            subtitle: loaderVersionDelegate.subtitle
                            selected: page.controller.selectedLoaderKind === page.controller.loaderVersionKind
                                      && page.controller.selectedLoaderVersion() === loaderVersionDelegate.version
                            onClicked: page.controller.selectVisibleLoaderVersion(loaderVersionDelegate.index)
                        }
                    }
                }

                DownloadSpinner {
                    anchors.centerIn: parent
                    width: 50
                    height: 50
                    style: page.style
                    visible: page.controller.installerMetadataTaskStatus.active
                    running: visible
                }

                Text {
                    anchors.centerIn: parent
                    visible: page.controller.visibleLoaderVersions.count === 0
                             && !page.controller.installerMetadataTaskStatus.active
                             && page.controller.installerMetadataTaskStatus.metadataReady
                    text: "没有匹配的 " + page.controller.loaderTitle(page.controller.loaderVersionKind) + " 版本"
                    color: page.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: !page.controller.installerMetadataTaskStatus.active
                             && !page.controller.installerMetadataTaskStatus.metadataReady

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: page.controller.installerMetadataTaskStatus.title || "加载器版本加载失败"
                        color: page.style.cTextOnSurface
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: page.controller.installerMetadataTaskStatus.message || "请检查网络或下载源后重试。"
                        color: page.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                    }

                    DownloadButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 88
                        style: page.style
                        text: "重试"
                        primary: true
                        onClicked: page.controller.startFetchLoaderMetadata(page.controller.loaderVersionKind)
                    }
                }
            }
        }
}
