import QtQuick
import QtQuick.Layouts
import "../icons"

Item {
    id: root

    // Qt 转写 HMCL ComponentSublist.java + ComponentSublistWrapper.java。
    // Header 继承 LineButton 视觉：48px 最小高度、10/16 padding、12 spacing。
    // 展开动画：Motion.LONG2(500ms) + EASE_IN_OUT_CUBIC_EMPHASIZED 的近似曲线。
    property var style
    property string title: ""
    property string subtitle: ""
    property string description: ""
    property string trailingText: description
    property bool hasSubtitle: subtitle.length > 0
    property bool expanded: false
    property bool componentPadding: true
    property bool animationsEnabled: styleValue("animationsEnabled", true)
    default property alias content: contentColumn.children

    width: parent ? parent.width : 600
    implicitHeight: header.height + contentClip.height

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    Rectangle {
        id: header
        width: root.width
        height: root.hasSubtitle ? 68 : 48
        color: mouse.containsMouse ? Qt.rgba(0, 0, 0, 0.045) : root.styleValue("cSurface", "#FFFBFE")

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.styleValue("cBorder", "#D9D7E2")
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.styleValue("cTextOnSurface", "#1B1B21")
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.hasSubtitle
                    text: root.subtitle
                    color: root.styleValue("cTextOnSurfaceVariant", "#454651")
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Text {
                visible: root.trailingText.length > 0
                Layout.maximumWidth: 240
                text: root.trailingText
                color: root.styleValue("cTextOnSurfaceVariant", "#454651")
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            SvgIcon {
                icon: "KEYBOARD_ARROW_DOWN"
                iconSize: 20
                iconColor: root.styleValue("cTextOnSurfaceVariant", "#454651")
                animationsEnabled: root.animationsEnabled
                rotation: root.expanded ? -180 : 0

                Behavior on rotation {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        }
    }

    Item {
        id: contentClip
        anchors.top: header.bottom
        width: root.width
        height: root.expanded ? contentColumn.implicitHeight : 0
        clip: true
        visible: height > 0.5

        Behavior on height {
            enabled: root.animationsEnabled
            NumberAnimation {
                duration: 500
                easing.type: Easing.InOutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.styleValue("cSurfaceContainer", "#F5F2FA")
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: 0
        }
    }
}
