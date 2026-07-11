import QtQuick
import "../../../components"
Item {
        id: item

        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconSource: ""
        property string iconKind: ""
        property bool selected: false

        signal clicked()

        height: 48

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: item.selected
                   ? Qt.rgba(item.style.cPrimary.r, item.style.cPrimary.g, item.style.cPrimary.b, 0.14)
                   : (mouse.containsMouse ? Qt.rgba(item.style.cTextOnSurface.r, item.style.cTextOnSurface.g, item.style.cTextOnSurface.b, 0.06) : "transparent")
        }

        Image {
            visible: item.iconSource.length > 0
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            source: item.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
        }

        HmclSvgIcon {
            visible: item.iconSource.length === 0
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            icon: item.iconKind
            iconSize: 22
            iconColor: item.selected ? item.style.cPrimary : item.style.cTextOnSurfaceVariant
            animationsEnabled: item.style.animationsEnabled
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: item.title
                color: item.selected ? item.style.cPrimary : item.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: item.selected
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: item.subtitle
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
        }
    }
