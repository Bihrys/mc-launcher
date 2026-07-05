import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property var style
    property string title: ""
    property string subtitle: ""
    property bool enabledRow: true
    property bool clickable: false
    signal clicked()
    default property alias trailing: trailingBox.children

    width: parent ? parent.width : 800
    implicitHeight: Math.max(48, titleColumn.implicitHeight + 20)
    height: implicitHeight
    color: hover.hovered ? root.styleValue("cSurfaceContainer", "#F5F2FA") : root.styleValue("cSurface", "#FFFBFE")
    opacity: enabledRow ? 1.0 : 0.42


    HoverHandler {
        id: hover
        enabled: root.enabledRow
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        ColumnLayout {
            id: titleColumn
            Layout.fillWidth: true
            spacing: 2

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
        anchors.fill: parent
        enabled: root.clickable && root.enabledRow
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

}
