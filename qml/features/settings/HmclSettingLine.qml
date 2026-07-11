import QtQuick
import QtQuick.Layouts
import "../../components"

Rectangle {
    id: root
    objectName: "SettingsLine:" + root.title
    property var style
    property string title: ""
    property string subtitle: ""
    property bool enabledRow: true
    property bool clickable: false
    property bool developmentPending: false
    readonly property bool effectiveEnabled: root.enabledRow && !root.developmentPending
    signal clicked()
    default property alias trailing: trailingBox.children

    width: parent ? parent.width : 800
    implicitHeight: Math.max(48, titleColumn.implicitHeight + 20)
    height: implicitHeight
    color: root.styleValue("cSurface", "#FFFBFE")
    opacity: root.developmentPending ? 0.72 : (root.enabledRow ? 1.0 : 0.42)


    HoverHandler {
        id: hover
        enabled: root.effectiveEnabled
    }

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) return value
        }
        return fallback
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: root.styleValue("cBorder", "#D9D7E2")
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: hover.hovered && root.effectiveEnabled
        hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
        rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        ColumnLayout {
            id: titleColumn
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.styleValue("cTextOnSurface", "#1B1B21")
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    visible: root.developmentPending
                    Layout.preferredWidth: pendingLabel.implicitWidth + 10
                    Layout.preferredHeight: 20
                    radius: 10
                    color: root.styleValue("cSurfaceContainerHigh", "#ECE9F1")
                    border.width: 1
                    border.color: root.styleValue("cBorder", "#D9D7E2")

                    Text {
                        id: pendingLabel
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
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Item {
            id: trailingBox
            Layout.preferredWidth: Math.min(420, root.width * 0.52)
            Layout.fillHeight: true
        }
    }
    MouseArea {
        objectName: "SettingsLineMouse:" + root.title
        anchors.fill: parent
        enabled: root.clickable && root.effectiveEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { ripple.press(mouse.x, mouse.y) }
        onReleased: ripple.release()
        onCanceled: ripple.cancel()
        onClicked: root.clicked()
    }

}
