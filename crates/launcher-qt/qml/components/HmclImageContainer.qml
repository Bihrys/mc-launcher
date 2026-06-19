import QtQuick

Item {
    id: root

    required property var style

    property string source: ""
    property string fallbackIcon: "FORMAT_LIST_BULLETED"
    property int imageSize: 32
    property bool animationsEnabled: true

    width: imageSize
    height: imageSize

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "transparent"
        clip: true

        Image {
            id: img

            anchors.centerIn: parent
            width: root.imageSize
            height: root.imageSize
            source: root.source
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.animationsEnabled ? 200 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }

        HmclSvgIcon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            icon: root.fallbackIcon
            iconSize: 20
            iconColor: root.style.cTextOnSurfaceVariant
            animationsEnabled: root.animationsEnabled
        }
    }
}
