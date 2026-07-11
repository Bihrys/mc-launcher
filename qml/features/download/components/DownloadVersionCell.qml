import QtQuick
import "../../../components"
Item {
        id: cell

        required property var style
        property string versionId: ""
        property string subtitle: ""
        property string tagText: ""
        property string iconSource: ""
        property bool selected: false

        signal clicked()

        height: 56

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: cell.selected
                   ? Qt.rgba(cell.style.cPrimary.r, cell.style.cPrimary.g, cell.style.cPrimary.b, 0.14)
                   : (mouse.containsMouse ? Qt.rgba(cell.style.cTextOnSurface.r, cell.style.cTextOnSurface.g, cell.style.cTextOnSurface.b, 0.06) : "transparent")
        }

        Image {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            source: cell.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 62
            anchors.right: arrow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: cell.versionId
                    color: cell.style.cTextOnSurface
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - tag.width - 12)
                }

                Rectangle {
                    id: tag
                    width: tagText.implicitWidth + 12
                    height: 20
                    radius: 2
                    color: Qt.rgba(cell.style.cPrimary.r, cell.style.cPrimary.g, cell.style.cPrimary.b, 0.14)

                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: cell.tagText
                        color: cell.style.cPrimary
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                width: parent.width
                text: cell.subtitle
                color: cell.style.cTextOnSurfaceVariant
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        HmclSvgIcon {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            icon: "ARROW_FORWARD"
            iconSize: 20
            iconColor: cell.style.cTextOnSurfaceVariant
            animationsEnabled: cell.style.animationsEnabled
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cell.clicked()
        }
    }
