import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "components"

Item {
    id: page
    objectName: "downloadVersionsPage"

    required property var style
    required property var controller

    // HMCL VersionsPage.Status: LOADING / SUCCESS / FAILED.
    // Keep all three panes alive and only fade their opacity. This avoids
    // destroying/recreating the ListView and losing the ListModel presentation
    // during Loader/TransitionPane switches.
    readonly property int catalogState: page.controller.catalogTaskStatus.active ? 0
                                      : page.controller.catalogLoadFailed ? 2 : 1

    onCatalogStateChanged: {
        page.controller.logAction("versions_page_state_changed", {
            "state": page.catalogState,
            "active": !!page.controller.catalogTaskStatus.active,
            "failed": !!page.controller.catalogLoadFailed,
            "allCount": page.controller.allVersions.count,
            "visibleCount": page.controller.visibleVersions.count
        })
    }

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
                    text: "名称"
                    color: page.style.cTextOnSurface
                    font.pixelSize: 13
                }

                TextField {
                    id: searchField
                    objectName: "downloadVersionSearchField"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    placeholderText: "输入版本名称进行搜索"
                    text: page.controller.searchText
                    selectByMouse: true

                    onTextChanged: {
                        page.controller.searchText = text
                        page.controller.rebuildVisibleVersions()
                    }
                }

                Text {
                    text: "版本类型"
                    color: page.style.cTextOnSurface
                    font.pixelSize: 13
                }

                ComboBox {
                    id: versionFilterCombo
                    objectName: "downloadVersionFilterCombo"

                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 36
                    model: ["全部", "正式版", "快照版", "愚人节", "远古版本"]
                    currentIndex: 1

                    onCurrentIndexChanged: {
                        var values = ["all", "release", "snapshot", "april", "old"]
                        if (currentIndex < 0 || currentIndex >= values.length)
                            return
                        page.controller.versionFilter = values[currentIndex]
                        page.controller.rebuildVisibleVersions()
                    }
                }

                DownloadButton {
                    objectName: "downloadCatalogRefreshButton"
                    Layout.preferredWidth: 72
                    style: page.style
                    text: "刷新"
                    primary: true
                    buttonEnabled: !page.controller.catalogTaskStatus.active
                    onClicked: page.controller.startRefreshCatalog()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 4
            color: page.style.cSurfaceContainerHigh
            border.color: page.style.cBorder
            border.width: 1
            clip: true

            // SUCCESS pane. It is persistent, matching HMCL's persistent
            // JFXListView. Refreshing does not replace the ListView object.
            Item {
                id: contentPane
                objectName: "downloadVersionsContentPane"
                anchors.fill: parent
                enabled: page.catalogState === 1
                opacity: page.catalogState === 1 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: page.style.animationsEnabled ? 220 : 0
                        easing.type: Easing.InOutCubic
                    }
                }

                ListView {
                    id: versionList
                    objectName: "downloadVersionList"
                    anchors.fill: parent
                    anchors.margins: 8
                    model: page.controller.visibleVersions
                    spacing: 0
                    clip: true
                    reuseItems: true
                    cacheBuffer: Math.max(height, 512)
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: true
                    currentIndex: -1

                    onCountChanged: {
                        page.controller.logAction("versions_list_count_changed", {
                            "count": count,
                            "modelCount": page.controller.visibleVersions.count,
                            "width": width,
                            "height": height,
                            "state": page.catalogState
                        })
                        if (count > 0)
                            positionViewAtBeginning()
                    }

                    delegate: Item {
                        id: versionDelegate

                        required property int index
                        required property string versionId
                        required property string releaseTime
                        required property string tagText
                        required property string iconSource

                        width: versionList.width
                        height: 64

                        DownloadVersionCell {
                            anchors.fill: parent
                            style: page.style
                            versionId: versionDelegate.versionId
                            subtitle: versionDelegate.releaseTime
                            tagText: versionDelegate.tagText
                            iconSource: versionDelegate.iconSource
                            selected: page.controller.selectedGameVersion === versionDelegate.versionId
                            onClicked: page.controller.openInstallerForVersion(versionDelegate.index)
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: page.controller.visibleVersions.count === 0
                    text: "没有匹配的版本"
                    color: page.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                }
            }

            // LOADING pane.
            Item {
                id: loadingPane
                objectName: "downloadVersionsLoadingPane"
                anchors.fill: parent
                enabled: page.catalogState === 0
                opacity: page.catalogState === 0 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: page.style.animationsEnabled ? 220 : 0
                        easing.type: Easing.InOutCubic
                    }
                }

                DownloadSpinner {
                    anchors.centerIn: parent
                    width: 50
                    height: 50
                    style: page.style
                    running: page.catalogState === 0
                }
            }

            // FAILED pane.
            Item {
                id: failedPane
                objectName: "downloadVersionsFailedPane"
                anchors.fill: parent
                enabled: page.catalogState === 2
                opacity: page.catalogState === 2 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: page.style.animationsEnabled ? 220 : 0
                        easing.type: Easing.InOutCubic
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: page.controller.catalogFailedMessage
                              || page.controller.catalogTaskStatus.message
                              || "加载失败，点击重试"
                        color: page.style.cTextOnSurfaceVariant
                        font.pixelSize: 13
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: retryLabel.implicitWidth + 24
                        height: 32
                        radius: 3
                        color: retryMouse.containsMouse
                               ? page.style.cButtonHover
                               : page.style.cButtonSurface

                        Text {
                            id: retryLabel
                            anchors.centerIn: parent
                            text: "重试"
                            color: page.style.cPrimary
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: retryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.controller.startRefreshCatalog()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        page.controller.logAction("versions_page_completed", {
            "state": page.catalogState,
            "allCount": page.controller.allVersions.count,
            "visibleCount": page.controller.visibleVersions.count,
            "width": page.width,
            "height": page.height
        })
    }
}
