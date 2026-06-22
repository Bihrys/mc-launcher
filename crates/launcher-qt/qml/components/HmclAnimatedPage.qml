import QtQuick

Item {
    id: root

    required property var style

    property real leftWidth: 0
    property Component leftComponent: null
    property Component centerComponent: null

    // HmclNavigator 动画时写入
    property real leftTranslateX: 0
    property real centerTranslateX: 0

    anchors.fill: parent
    clip: true

    Loader {
        id: leftLoader

        x: root.leftTranslateX
        y: 0
        width: root.leftWidth
        height: root.height
        visible: root.leftWidth > 0
        active: root.leftComponent !== null && root.leftWidth > 0
        sourceComponent: root.leftComponent
    }

    Loader {
        id: centerLoader

        x: root.leftWidth + root.centerTranslateX
        y: 0
        width: Math.max(1, root.width - root.leftWidth)
        height: root.height
        active: root.centerComponent !== null
        sourceComponent: root.centerComponent
    }
}
