import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../../Hmcl/animation" as HmclAnimation
import "components"

Item {
    id: page
    required property var style
    required property var controller

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

                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "输入版本名称进行搜索"
                        text: page.controller.searchText
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
                        Layout.preferredWidth: 112
                        Layout.preferredHeight: 36
                        model: ["全部", "正式版", "快照版", "愚人节", "远古版本"]
                        currentIndex: 1

                        onCurrentIndexChanged: {
                            var values = ["all", "release", "snapshot", "april", "old"]
                            page.controller.versionFilter = values[currentIndex]
                            page.controller.rebuildVisibleVersions()
                        }
                    }

                    DownloadButton {
                        Layout.preferredWidth: 72
                        style: page.style
                        text: "刷新"
                        primary: true
                        buttonEnabled: !page.controller.catalogTaskStatus.active
                        onClicked: page.controller.startRefreshCatalog()
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

                property int catalogState: page.controller.catalogTaskStatus.active ? 0
                                         : page.controller.catalogLoadFailed ? 2 : 1

                onCatalogStateChanged: {
                    versionSpinner.animationType = HmclAnimation.ContainerAnimations.fade
                    if (catalogState === 0)
                        versionSpinner.sourceComponent = spinnerComp
                    else if (catalogState === 2)
                        versionSpinner.sourceComponent = failedComp
                    else
                        versionSpinner.sourceComponent = contentComp
                }

                Component.onCompleted: {
                    versionSpinner.sourceComponent = page.controller.catalogTaskStatus.active ? spinnerComp : contentComp
                }

                Component {
                    id: spinnerComp
                    Item {
                        DownloadSpinner {
                            anchors.centerIn: parent
                            width: 50
                            height: 50
                            style: page.style
                            running: true
                        }
                    }
                }

                Component {
                    id: contentComp
                    Item {
                        ListView {
                            id: versionList
                            anchors.fill: parent
                            anchors.margins: 8
                            model: page.controller.visibleVersions
                            spacing: 0
                            clip: true

                            delegate: Item {
                                id: versionDelegate

                                required property int index
                                required property string versionId
                                required property string versionType
                                required property string releaseTime
                                required property string group
                                required property string iconSource
                                required property string tagText

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
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: page.controller.visibleVersions.count === 0
                            text: "没有匹配的版本"
                            color: page.style.cTextOnSurfaceVariant
                            font.pixelSize: 13
                        }
                    }
                }

                Component {
                    id: failedComp
                    Item {
                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: page.controller.catalogTaskStatus.message || "加载失败，点击重试"
                                color: page.style.cTextOnSurfaceVariant
                                font.pixelSize: 13
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: retryLabel.implicitWidth + 24
                                height: 32
                                radius: 3
                                color: retryMouse.containsMouse ? page.style.cButtonHover : page.style.cButtonSurface

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

                HmclAnimation.TransitionPane {
                    id: versionSpinner
                    anchors.fill: parent
                    duration: page.style.animationsEnabled ? 300 : 0
                    animationsEnabled: page.style.animationsEnabled
                }
            }
        }
}
