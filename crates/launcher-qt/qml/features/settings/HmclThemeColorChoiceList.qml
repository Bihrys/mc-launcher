import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import "../../Hmcl/controls" as Hmcl
import "../../components"

Column {
    id: root

    property var style
    property string value: "default"
    property string colorValue: "#5C6BC0"
    property var standardColors: [
        {"name":"blue", "value":"#5C6BC0"},
        {"name":"darker_blue", "value":"#283593"},
        {"name":"green", "value":"#43A047"},
        {"name":"orange", "value":"#E67E22"},
        {"name":"purple", "value":"#9C27B0"},
        {"name":"red", "value":"#B71C1C"}
    ]
    signal selected(string value)
    signal colorSelected(string value)

    width: parent ? parent.width : 800
    spacing: 0

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var v = root.style[name]
            if (v !== undefined && v !== null) return v
        }
        return fallback
    }

    function normalizeColor(value) {
        var s = String(value || "#5C6BC0")
        if (s === "default" || s === "blue") return "#5C6BC0"
        if (s === "darker_blue") return "#283593"
        if (s === "green") return "#43A047"
        if (s === "orange") return "#E67E22"
        if (s === "purple") return "#9C27B0"
        if (s === "red") return "#B71C1C"
        if (s.charAt(0) === "#") return s
        return "#5C6BC0"
    }

    HmclRadioOptionLine {
        width: parent.width
        style: root.style
        title: "默认"
        checked: root.value === "default"
        onClicked: root.selected("default")
    }

    HmclRadioOptionLine {
        width: parent.width
        style: root.style
        title: "自定义"
        subtitle: "使用自定义主题色。"
        checked: root.value === "custom"
        showTopBorder: true
        onClicked: root.selected("custom")

        Rectangle {
            id: colorButton
            Layout.preferredWidth: 72
            Layout.preferredHeight: 28
            radius: 3
            color: root.normalizeColor(root.colorValue)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.22)
            clip: true

            HmclRipple {
                id: colorRipple
                anchors.fill: parent
                hovered: colorMouse.containsMouse
                hoverColor: "white"
                rippleColor: "white"
                animationsEnabled: !!root.styleValue("animationsEnabled", true)
            }

            Text {
                anchors.centerIn: parent
                text: root.normalizeColor(root.colorValue).toUpperCase()
                color: "white"
                font.pixelSize: 12
            }

            MouseArea {
                id: colorMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: function(mouse) { colorRipple.press(mouse.x, mouse.y) }
                onReleased: colorRipple.release()
                onCanceled: colorRipple.cancel()
                onClicked: {
                    root.selected("custom")
                    if (colorPopup.opened) colorPopup.close()
                    else colorPopup.open()
                }
            }

            Popup {
                id: colorPopup
                x: -172
                y: colorButton.height + 8
                width: 200
                height: 356
                padding: 0
                modal: false
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle {
                    color: root.styleValue("cSurface", "#FFFBFE")
                    radius: 2
                    border.width: 1
                    border.color: root.styleValue("cBorder", "#D9D7E2")
                }

                contentItem: Item {
                    width: colorPopup.width
                    height: colorPopup.height

                    Grid {
                        id: colorGrid
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 14
                        anchors.topMargin: 14
                        columns: 12
                        spacing: 1

                        Repeater {
                            model: [
                                "#ECEFF1","#CFD8DC","#B0BEC5","#90A4AE","#78909C","#607D8B","#546E7A","#455A64","#37474F","#263238","#212121","#000000",
                                "#FFEBEE","#FFCDD2","#EF9A9A","#E57373","#EF5350","#F44336","#E53935","#D32F2F","#C62828","#B71C1C","#FF8A80","#FF5252",
                                "#FCE4EC","#F8BBD0","#F48FB1","#F06292","#EC407A","#E91E63","#D81B60","#C2185B","#AD1457","#880E4F","#FF80AB","#FF4081",
                                "#F3E5F5","#E1BEE7","#CE93D8","#BA68C8","#AB47BC","#9C27B0","#8E24AA","#7B1FA2","#6A1B9A","#4A148C","#EA80FC","#E040FB",
                                "#EDE7F6","#D1C4E9","#B39DDB","#9575CD","#7E57C2","#673AB7","#5E35B1","#512DA8","#4527A0","#311B92","#B388FF","#7C4DFF",
                                "#E8EAF6","#C5CAE9","#9FA8DA","#7986CB","#5C6BC0","#3F51B5","#3949AB","#303F9F","#283593","#1A237E","#8C9EFF","#536DFE",
                                "#E3F2FD","#BBDEFB","#90CAF9","#64B5F6","#42A5F5","#2196F3","#1E88E5","#1976D2","#1565C0","#0D47A1","#82B1FF","#448AFF",
                                "#E1F5FE","#B3E5FC","#81D4FA","#4FC3F7","#29B6F6","#03A9F4","#039BE5","#0288D1","#0277BD","#01579B","#80D8FF","#40C4FF",
                                "#E0F2F1","#B2DFDB","#80CBC4","#4DB6AC","#26A69A","#009688","#00897B","#00796B","#00695C","#004D40","#A7FFEB","#64FFDA",
                                "#E8F5E9","#C8E6C9","#A5D6A7","#81C784","#66BB6A","#4CAF50","#43A047","#388E3C","#2E7D32","#1B5E20","#B9F6CA","#69F0AE",
                                "#FFFDE7","#FFF9C4","#FFF59D","#FFF176","#FFEE58","#FFEB3B","#FDD835","#FBC02D","#F9A825","#F57F17","#FFFF8D","#FFFF00",
                                "#FFF3E0","#FFE0B2","#FFCC80","#FFB74D","#FFA726","#FF9800","#FB8C00","#F57C00","#EF6C00","#E65100","#FFD180","#FFAB40",
                                "#FBE9E7","#FFCCBC","#FFAB91","#FF8A65","#FF7043","#FF5722","#F4511E","#E64A19","#D84315","#BF360C","#FF9E80","#FF6E40",
                                "#EFEBE9","#D7CCC8","#BCAAA4","#A1887F","#8D6E63","#795548","#6D4C41","#5D4037","#4E342E","#3E2723","#D7CCC8","#A1887F"
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 14
                                height: 14
                                color: modelData
                                border.width: root.normalizeColor(root.colorValue).toUpperCase() === modelData.toUpperCase() ? 2 : 0
                                border.color: root.styleValue("cLaunchButton", "#5C6BC0")

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selected("custom")
                                        root.colorSelected(modelData)
                                        colorPopup.close()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.top: colorGrid.bottom
                        anchors.topMargin: 14
                        anchors.leftMargin: 14
                        text: "推荐"
                        color: root.styleValue("cTextOnSurface", "#1B1B21")
                        font.pixelSize: 13
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.top: colorGrid.bottom
                        anchors.topMargin: 38
                        anchors.leftMargin: 14
                        spacing: 2
                        Repeater {
                            model: root.standardColors
                            delegate: Rectangle {
                                required property var modelData
                                width: 16
                                height: 16
                                color: modelData.value
                                border.width: 0
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selected("custom")
                                        root.colorSelected(String(modelData.value))
                                        colorPopup.close()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.top: colorGrid.bottom
                        anchors.topMargin: 72
                        anchors.leftMargin: 14
                        text: "自定义颜色"
                        color: root.styleValue("cTextOnSurface", "#1B1B21")
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    HmclRadioOptionLine {
        width: parent.width
        style: root.style
        title: "跟随背景"
        checked: root.value === "background"
        showTopBorder: true
        onClicked: root.selected("background")
    }
}
