import QtQuick

Item {
    id: root

    required property var style
    property Component contentComponent: null

    signal backRequested()

    anchors.fill: parent

    Item {
        id: topBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 56

        Item {
            id: backButton

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44

            Rectangle {
                anchors.fill: parent
                radius: 22
                color: backMouse.containsMouse
                       ? Qt.rgba(root.style.cTextOnSurface.r,
                                 root.style.cTextOnSurface.g,
                                 root.style.cTextOnSurface.b,
                                 0.06)
                       : "transparent"
            }

            Canvas {
                id: backArrowCanvas

                anchors.centerIn: parent
                width: 22
                height: 22

                property color arrowColor: root.style.cTextOnSurface

                onArrowColorChanged: requestPaint()
                onVisibleChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = arrowColor
                    ctx.lineWidth = 1.8
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    ctx.beginPath()
                    ctx.moveTo(13.5, 5)
                    ctx.lineTo(7.5, 11)
                    ctx.lineTo(13.5, 17)
                    ctx.stroke()
                }
            }

            MouseArea {
                id: backMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: root.backRequested()
            }
        }
    }

    Loader {
        id: pageLoader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        sourceComponent: root.contentComponent
        active: root.contentComponent !== null
    }
}
