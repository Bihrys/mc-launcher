import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl
import "../../components"

Rectangle {
    id: root

    property var style
    property string title: ""
    property string subtitle: ""
    property string rightText: ""
    property bool checked: false
    property bool enabledRow: true
    property bool showTopBorder: false
    property bool developmentPending: false
    readonly property bool effectiveEnabled: root.enabledRow && !root.developmentPending
    default property alias rightContent: rightBox.children

    signal clicked()

    width: parent ? parent.width : 800
    implicitHeight: root.subtitle.length > 0 ? 46 : 30
    height: implicitHeight
    color: "transparent"
    opacity: root.developmentPending ? 0.72 : (root.enabledRow ? 1.0 : 0.42)

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse && root.effectiveEnabled
        hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
        rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
        hoverOpacity: 0.04
        rippleOpacity: 0.10
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        visible: root.showTopBorder
        color: root.styleValue("cBorder", "#D9D7E2")
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.effectiveEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { ripple.press(mouse.x, mouse.y) }
        onReleased: ripple.release()
        onCanceled: ripple.cancel()
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 3
        anchors.rightMargin: 3
        spacing: 6

        Hmcl.RadioButton {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            style: root.style
            checked: root.checked
            onClicked: root.clicked()
        }

        ColumnLayout {
            id: textColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.styleValue("cTextOnSurface", "#1B1B21")
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root.developmentPending
                    Layout.preferredWidth: radioPendingLabel.implicitWidth + 10
                    Layout.preferredHeight: 18
                    radius: 9
                    color: root.styleValue("cSurfaceContainerHigh", "#ECE9F1")
                    border.width: 1
                    border.color: root.styleValue("cBorder", "#D9D7E2")

                    Text {
                        id: radioPendingLabel
                        anchors.centerIn: parent
                        text: "待开发"
                        color: root.styleValue("cTextOnSurfaceVariant", "#454651")
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: root.styleValue("cTextOnSurfaceVariant", "#454651")
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Text {
            visible: root.rightText.length > 0 && rightBox.children.length === 0
            Layout.maximumWidth: Math.min(360, root.width * 0.50)
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            text: root.rightText
            color: root.styleValue("cTextOnSurface", "#1B1B21")
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
        }

        RowLayout {
            id: rightBox
            Layout.maximumWidth: Math.min(360, root.width * 0.50)
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: 8
        }
    }
}
