import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.bihrys.launcher

ApplicationWindow {
    id: root

    width: 760
    height: 520
    visible: true
    title: "MC Launcher - Java Detector"

    property bool darkMode: false

    readonly property color bgColor: darkMode ? "#111827" : "#F3F4F6"
    readonly property color cardColor: darkMode ? "#1F2937" : "#FFFFFF"
    readonly property color textColor: darkMode ? "#E5E7EB" : "#111827"
    readonly property color mutedTextColor: darkMode ? "#9CA3AF" : "#6B7280"
    readonly property color borderColor: darkMode ? "#374151" : "#D1D5DB"
    readonly property color buttonColor: darkMode ? "#2563EB" : "#2563EB"
    readonly property color buttonHoverColor: darkMode ? "#1D4ED8" : "#1D4ED8"
    readonly property color buttonTextColor: "#FFFFFF"

    LauncherBackend {
        id: backend
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "Java Runtime Detector"
                        color: root.textColor
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Label {
                        text: "点击按钮后，Qt/QML 会调用 Rust core 检测本机 Java。"
                        color: root.mutedTextColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                Button {
                    id: themeButton

                    text: root.darkMode ? "浅色模式" : "深色模式"
                    onClicked: root.darkMode = !root.darkMode

                    contentItem: Text {
                        text: themeButton.text
                        color: root.buttonTextColor
                        font: themeButton.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 8
                        color: themeButton.hovered ? root.buttonHoverColor : root.buttonColor
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: root.cardColor
                border.color: root.borderColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Button {
                        id: detectButton

                        text: "检测 Java"
                        onClicked: backend.detectJava()

                        contentItem: Text {
                            text: detectButton.text
                            color: root.buttonTextColor
                            font: detectButton.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 8
                            color: detectButton.hovered ? root.buttonHoverColor : root.buttonColor
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextArea {
                            text: backend.output
                            placeholderText: "等待检测..."
                            placeholderTextColor: root.mutedTextColor
                            readOnly: true
                            wrapMode: TextArea.NoWrap
                            font.family: "monospace"
                            selectByMouse: true
                            color: root.textColor
                            selectedTextColor: "#FFFFFF"
                            selectionColor: root.buttonColor

                            background: Rectangle {
                                color: root.darkMode ? "#0F172A" : "#F9FAFB"
                                border.color: root.borderColor
                                border.width: 1
                                radius: 8
                            }
                        }
                    }
                }
            }
        }
    }
}
