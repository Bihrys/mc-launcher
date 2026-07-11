import QtQuick

Item {
    id: card

    required property var style
    property string libraryId: ""
    property string title: ""
    property string statusText: ""
    property string iconSource: ""
    property bool selected: false
    property bool removable: false
    // HMCL keeps incompatible entries visible, but disables the install action.
    property bool incompatibleCard: false
    // Features that only have a visual shell are explicitly labelled as pending.
    property bool pendingCard: false
    readonly property bool interactive: !card.incompatibleCard && !card.pendingCard

    signal installClicked()
    signal removeClicked()

    height: width * 0.7
    opacity: card.pendingCard ? 0.54 : 1.0

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 1
        anchors.topMargin: 2
        radius: 4
        color: Qt.rgba(0, 0, 0, card.style.darkMode ? 0.34 : 0.20)
        visible: !card.pendingCard
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: mouse.containsMouse && card.interactive
               ? Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.06)
               : card.style.cSurface
        border.color: card.incompatibleCard
                      ? Qt.rgba(card.style.cTextOnSurfaceVariant.r,
                                card.style.cTextOnSurfaceVariant.g,
                                card.style.cTextOnSurfaceVariant.b, 0.32)
                      : "transparent"
        border.width: card.incompatibleCard ? 1 : 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: card.interactive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.installClicked()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 3

        Image {
            width: 32
            height: 32
            anchors.horizontalCenter: parent.horizontalCenter
            source: card.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: false
            opacity: card.incompatibleCard ? 0.68 : 1.0
        }

        Text {
            width: parent.width
            text: card.title
            color: card.style.cTextOnSurface
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: card.statusText
            color: card.incompatibleCard
                   ? card.style.cTextOnSurface
                   : card.style.cTextOnSurfaceVariant
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Rectangle {
                width: 28
                height: 28
                radius: 14
                visible: card.removable
                color: removeMouse.containsMouse
                       ? Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.10)
                       : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: card.style.cTextOnSurface
                    font.pixelSize: 18
                }

                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(event) {
                        event.accepted = true
                        card.removeClicked()
                    }
                }
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                visible: card.interactive
                color: installMouse.containsMouse
                       ? Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.10)
                       : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: card.selected ? "↻" : "➜"
                    color: card.style.cTextOnSurface
                    font.pixelSize: 17
                }

                MouseArea {
                    id: installMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(event) {
                        event.accepted = true
                        card.installClicked()
                    }
                }
            }
        }
    }
}
