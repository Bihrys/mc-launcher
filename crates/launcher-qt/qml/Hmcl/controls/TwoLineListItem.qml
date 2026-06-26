import QtQuick

Column {
    id: root

    property string title: ""
    property string subtitle: ""
    required property var style

    spacing: 2

    Text {
        width: parent.width
        text: root.title
        color: root.style.cTextOnSurface
        font.pixelSize: 15
        elide: Text.ElideRight
    }

    Text {
        width: parent.width
        text: root.subtitle
        color: root.style.cTextOnSurfaceVariant
        font.pixelSize: 12
        elide: Text.ElideRight
        visible: root.subtitle.length > 0
    }
}
