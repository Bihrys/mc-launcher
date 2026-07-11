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
        property bool disabledCard: false

        signal installClicked()
        signal removeClicked()

        height: width * 0.7
        opacity: disabledCard ? 0.52 : 1.0

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.topMargin: 2
            radius: 4
            color: Qt.rgba(0, 0, 0, card.style.darkMode ? 0.34 : 0.20)
            visible: !card.disabledCard
        }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: mouse.containsMouse && !card.disabledCard
                   ? Qt.rgba(card.style.cTextOnSurface.r, card.style.cTextOnSurface.g, card.style.cTextOnSurface.b, 0.06)
                   : card.style.cSurface
            border.color: "transparent"
            border.width: 0
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !card.disabledCard
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
                color: card.style.cTextOnSurfaceVariant
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
                    visible: !card.disabledCard
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
