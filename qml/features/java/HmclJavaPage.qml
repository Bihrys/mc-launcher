pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var style
    required property var backend

    property string selectedDistribution: "temurin"
    property string selectedMajor: "17"
    property string selectedPackageType: "jdk"

    // 解析后的本机 Java 运行时列表（来自 backend.detectedJavaJson）。
    property var detectedRuntimes: []

    function reloadRuntimes() {
        var raw = root.backend.detectedJavaJson
        if (!raw || raw.length === 0) {
            root.detectedRuntimes = []
            return
        }
        try {
            var parsed = JSON.parse(raw)
            root.detectedRuntimes = parsed.runtimes || []
        } catch (e) {
            root.detectedRuntimes = []
        }
    }

    Component.onCompleted: root.reloadRuntimes()

    Connections {
        target: root.backend
        function onDetectedJavaJsonChanged() {
            root.reloadRuntimes()
        }
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        anchors.bottomMargin: 96
        spacing: 18

        Text {
            text: "Java 管理"
            color: root.style.cTextOnSurface
            font.pixelSize: 24
            font.bold: true
        }

        Rectangle {
            width: Math.min(parent.width, 760)
            height: 318
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Column {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "下载 Java"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: "选择 Java 发行版、版本和包类型。下载源使用 HMCL 同源的 Foojay Disco API。"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "发行版"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Flow {
                        width: parent.width
                        spacing: 8

                        ChoiceButton {
                            style: root.style
                            text: "Eclipse Temurin"
                            value: "temurin"
                            selected: root.selectedDistribution === value
                            onClicked: root.selectedDistribution = value
                        }

                        ChoiceButton {
                            style: root.style
                            text: "BellSoft Liberica"
                            value: "liberica"
                            selected: root.selectedDistribution === value
                            onClicked: root.selectedDistribution = value
                        }

                        ChoiceButton {
                            style: root.style
                            text: "Azul Zulu"
                            value: "zulu"
                            selected: root.selectedDistribution === value
                            onClicked: root.selectedDistribution = value
                        }

                        ChoiceButton {
                            style: root.style
                            text: "Oracle GraalVM"
                            value: "graalvm"
                            selected: root.selectedDistribution === value
                            onClicked: root.selectedDistribution = value
                        }

                        ChoiceButton {
                            style: root.style
                            text: "IBM Semeru"
                            value: "semeru"
                            selected: root.selectedDistribution === value
                            onClicked: root.selectedDistribution = value
                        }

                        ChoiceButton {
                            style: root.style
                            text: "Amazon Corretto"
                            value: "corretto"
                            selected: root.selectedDistribution === value
                            onClicked: root.selectedDistribution = value
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 22

                    Column {
                        spacing: 8

                        Text {
                            text: "版本"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Row {
                            spacing: 8

                            ChoiceButton {
                                style: root.style
                                text: "Java 8"
                                value: "8"
                                selected: root.selectedMajor === value
                                onClicked: root.selectedMajor = value
                            }

                            ChoiceButton {
                                style: root.style
                                text: "Java 17"
                                value: "17"
                                selected: root.selectedMajor === value
                                onClicked: root.selectedMajor = value
                            }

                            ChoiceButton {
                                style: root.style
                                text: "Java 21"
                                value: "21"
                                selected: root.selectedMajor === value
                                onClicked: root.selectedMajor = value
                            }

                            ChoiceButton {
                                style: root.style
                                text: "Java 25"
                                value: "25"
                                selected: root.selectedMajor === value
                                onClicked: root.selectedMajor = value
                            }
                        }
                    }

                    Column {
                        spacing: 8

                        Text {
                            text: "包类型"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Row {
                            spacing: 8

                            ChoiceButton {
                                style: root.style
                                text: "JDK"
                                value: "jdk"
                                selected: root.selectedPackageType === value
                                onClicked: root.selectedPackageType = value
                            }

                            ChoiceButton {
                                style: root.style
                                text: "JRE"
                                value: "jre"
                                selected: root.selectedPackageType === value
                                onClicked: root.selectedPackageType = value
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 62
                    radius: root.style.radiusValue
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        ActionButton {
                            style: root.style
                            text: "检测本机 Java"
                            primary: false
                            onClicked: root.backend.detectJava()
                        }

                        ActionButton {
                            style: root.style
                            text: "下载所选 Java"
                            primary: true
                            onClicked: root.backend.downloadJava(
                                root.selectedDistribution,
                                root.selectedMajor,
                                root.selectedPackageType
                            )
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "~/.local/share/mc-launcher/java/"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                        }
                    }
                }
            }
        }

        Rectangle {
            width: Math.min(parent.width, 760)
            height: Math.max(180, parent.height - 388)
            radius: root.style.radiusValue
            color: root.style.cSurfaceContainer
            border.color: root.style.cBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "本机 Java 运行时"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.detectedRuntimes.length > 0
                              ? "共 " + root.detectedRuntimes.length + " 个"
                              : ""
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                    }
                }

                ListView {
                    id: runtimeList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.detectedRuntimes
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Text {
                        anchors.centerIn: parent
                        visible: root.detectedRuntimes.length === 0
                        text: "尚未检测。点击“检测本机 Java”。"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                        font.italic: true
                    }

                    delegate: Rectangle {
                        id: runtimeCell

                        required property var modelData

                        width: runtimeList.width
                        height: 56
                        radius: root.style.radiusValue
                        color: runtimeMouse.containsMouse
                               ? root.style.cButtonHover
                               : root.style.cSurfaceContainerHigh
                        border.width: 1
                        border.color: root.style.cBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 19
                                color: root.style.cButtonSelected

                                Text {
                                    anchors.centerIn: parent
                                    text: runtimeCell.modelData.major && runtimeCell.modelData.major.length > 0
                                          ? runtimeCell.modelData.major
                                          : "?"
                                    color: root.style.cButtonSelectedText
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: {
                                        var v = runtimeCell.modelData.version
                                        var vendor = runtimeCell.modelData.vendor
                                        var head = (v && v.length > 0) ? "Java " + v : "Java"
                                        if (vendor && vendor.length > 0)
                                            head += " · " + vendor
                                        return head
                                    }
                                    color: root.style.cTextOnSurface
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: runtimeCell.modelData.path
                                    color: root.style.cTextOnSurfaceVariant
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        MouseArea {
                            id: runtimeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.backend.output.length > 0
                    text: root.backend.output
                    color: root.style.cTextOnSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component ChoiceButton: Rectangle {
        id: button

        required property var style

        property string text: ""
        property string value: ""
        property bool selected: false

        signal clicked()

        width: Math.max(74, label.implicitWidth + 24)
        height: 34
        radius: 17

        color: selected
               ? style.cButtonSelected
               : mouse.containsMouse ? style.cButtonHover : style.cButtonSurface

        border.width: selected ? 0 : 1
        border.color: style.cBorder

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.selected ? button.style.cButtonSelectedText : button.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: button.selected
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
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

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

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
}
