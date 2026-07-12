import QtQuick
import "../../../components"

// Qt Quick port of HMCL InstallerItem.Style.CARD + InstallerItemSkin.
Item {
    id: card

    required property var style
    property string libraryId: ""
    property string title: ""
    property string statusText: ""
    property string iconSource: ""
    property bool selected: false
    property bool removable: false
    property bool incompatibleCard: false
    property bool pendingCard: false
    property bool installActionVisible: !card.incompatibleCard && !card.pendingCard
    readonly property bool interactive: card.installActionVisible

    signal installClicked()
    signal removeClicked()

    implicitWidth: 180
    height: width * 0.7
    opacity: card.pendingCard ? 0.54 : 1.0

    // root.css: dropshadow(gaussian, rgba(0, 0, 0, 0.26), 10, 0.12, -1, 2)
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 1
        anchors.rightMargin: -1
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: 4
        color: Qt.rgba(0, 0, 0, card.style.darkMode ? 0.34 : 0.24)
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 4
        color: card.style.cSurface
        clip: true

        HmclRipple {
            id: ripple
            anchors.fill: parent
            hoverColor: card.style.cTextOnSurface
            rippleColor: card.style.cPrimary
            hovered: hitArea.containsMouse && card.interactive
            animationsEnabled: card.style.animationsEnabled
            z: 0
        }

        Column {
            anchors.fill: parent
            anchors.topMargin: 18
            anchors.bottomMargin: 8
            spacing: 3
            z: 1

            Image {
                width: 32
                height: 32
                anchors.horizontalCenter: parent.horizontalCenter
                source: card.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: false
                mipmap: false
                opacity: card.incompatibleCard ? 0.82 : 1.0
            }

            Item { width: 1; height: 6 }

            Text {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.title
                color: card.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: false
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.statusText
                color: card.style.cTextOnSurface
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Item { width: 1; height: 1 }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                height: 28
                transform: Translate { y: -5 }

                Item {
                    width: 28
                    height: 28
                    visible: card.removable

                    HmclSvgIcon {
                        anchors.centerIn: parent
                        icon: "CLOSE"
                        iconSize: 20
                        iconColor: card.style.cTextOnSurface
                        animationsEnabled: card.style.animationsEnabled
                    }

                    HmclRipple {
                        id: removeRipple
                        anchors.fill: parent
                        circularMask: true
                        hoverColor: card.style.cTextOnSurface
                        rippleColor: card.style.cPrimary
                        hovered: removeMouse.containsMouse
                        animationsEnabled: card.style.animationsEnabled
                    }

                    MouseArea {
                        id: removeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function(event) { removeRipple.press(event.x, event.y) }
                        onReleased: removeRipple.release()
                        onCanceled: removeRipple.cancel()
                        onClicked: function(event) {
                            event.accepted = true
                            card.removeClicked()
                        }
                    }
                }

                Item {
                    width: 28
                    height: 28
                    visible: card.installActionVisible

                    HmclSvgIcon {
                        anchors.centerIn: parent
                        icon: card.selected ? "UPDATE" : "ARROW_FORWARD"
                        iconSize: 20
                        iconColor: card.style.cTextOnSurface
                        animationsEnabled: card.style.animationsEnabled
                    }

                    HmclRipple {
                        id: installRipple
                        anchors.fill: parent
                        circularMask: true
                        hoverColor: card.style.cTextOnSurface
                        rippleColor: card.style.cPrimary
                        hovered: installMouse.containsMouse
                        animationsEnabled: card.style.animationsEnabled
                    }

                    MouseArea {
                        id: installMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function(event) { installRipple.press(event.x, event.y) }
                        onReleased: installRipple.release()
                        onCanceled: installRipple.cancel()
                        onClicked: function(event) {
                            event.accepted = true
                            card.installClicked()
                        }
                    }
                }
            }
        }

        MouseArea {
            id: hitArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: card.interactive
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            propagateComposedEvents: true
            onPressed: function(event) { ripple.press(event.x, event.y) }
            onReleased: ripple.release()
            onCanceled: ripple.cancel()
            onClicked: card.installClicked()
        }
    }
}
