import QtQuick
import QtQuick.Layouts
import "../icons"
import "../../components"

Item {
    id: root

    property var style
    property string title: ""
    property string subtitle: ""
    property string iconKind: ""
    property string selectedIconKind: ""
    property bool selected: false
    property bool enabledItem: true

    signal clicked()

    width: parent ? parent.width : 220
    height: subtitle.length > 0 ? 48 : 40

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    Rectangle {
        anchors.fill: parent
        color: root.selected ? root.styleValue("cNavSelected", "transparent") : "transparent"
    }

    HmclRipple {
        id: ripple
        anchors.fill: parent
        hovered: mouse.containsMouse && root.enabledItem
        hoverColor: root.styleValue("cTextOnSurface", "#1B1B21")
        rippleColor: root.styleValue("cTextOnSurface", "#1B1B21")
        animationsEnabled: !!root.styleValue("animationsEnabled", true)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        Item {
            visible: root.iconKind.length > 0
            Layout.preferredWidth: 32
            Layout.preferredHeight: 20

            SvgIcon {
                anchors.centerIn: parent
                icon: root.selected && root.selectedIconKind.length > 0 ? root.selectedIconKind : root.iconKind
                iconSize: 20
                iconColor: root.selected ? root.styleValue("cButtonSelected", "#2f6fed") : root.styleValue("cTextOnSurfaceVariant", "#666666")
                animationsEnabled: !!root.styleValue("animationsEnabled", true)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: root.title
                color: root.selected ? root.styleValue("cButtonSelected", root.styleValue("cTextOnSurface", "#222222")) : root.styleValue("cTextOnSurface", "#222222")
                font.pixelSize: 13
                font.bold: root.selected
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: root.styleValue("cTextOnSurfaceVariant", "#666666")
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabledItem
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) { ripple.press(mouse.x, mouse.y) }
        onReleased: ripple.release()
        onCanceled: ripple.cancel()
        onClicked: root.clicked()
    }
}
