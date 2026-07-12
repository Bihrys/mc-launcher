import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var style
    property string title: ""
    property string subtitle: ""
    property string tag: ""
    property int titleFontSize: 15
    property int subtitleFontSize: 12
    property bool titleBold: false

    spacing: 1

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: root.title
            color: root.styleValue("cTextOnSurface", "#222222")
            font.pixelSize: root.titleFontSize
            font.bold: root.titleBold
            elide: Text.ElideRight
        }

        Rectangle {
            visible: root.tag.length > 0
            radius: 7
            color: root.styleValue("cSurfaceContainerHigh", "#f0f0f0")
            border.color: root.styleValue("cBorder", "#dddddd")
            border.width: 1
            Layout.preferredHeight: 18
            Layout.preferredWidth: tagText.implicitWidth + 12

            Text {
                id: tagText
                anchors.centerIn: parent
                text: root.tag
                color: root.styleValue("cTextOnSurfaceVariant", "#666666")
                font.pixelSize: 10
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.subtitle
        color: root.styleValue("cTextOnSurfaceVariant", "#666666")
        font.pixelSize: root.subtitleFontSize
        elide: Text.ElideRight
    }
}
