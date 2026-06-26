import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property var style
    property string title: ""
    property string subtitle: ""
    property string tag: ""
    spacing: 1

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            Layout.fillWidth: true
            text: root.title
            color: root.style.cTextOnSurface
            font.pixelSize: 15
            elide: Text.ElideRight
        }
        Rectangle {
            visible: root.tag.length > 0
            radius: 7
            color: root.style.cSurfaceContainerHigh
            border.color: root.style.cBorder
            border.width: 1
            Layout.preferredHeight: 18
            Layout.preferredWidth: tagText.implicitWidth + 12
            Text {
                id: tagText
                anchors.centerIn: parent
                text: root.tag
                color: root.style.cTextOnSurfaceVariant
                font.pixelSize: 10
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.subtitle
        color: root.style.cTextOnSurfaceVariant
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
