import QtQuick

Item {
    id: root

    required property var style

    // DecoratorAnimatedPage：left + center。
    property real leftWidth: 0
    property Component leftComponent: null
    property Component centerComponent: null

    // HmclNavigator 注入动画偏移。
    property real leftTranslateX: 0
    property real centerTranslateX: 0

    clip: true

    Rectangle {
        id: leftBackground

        x: root.leftTranslateX
        y: 0
        width: root.leftWidth
        height: root.height
        visible: root.leftWidth > 0
        color: root.style.cSidebarBackground !== undefined
               ? root.style.cSidebarBackground
               : (root.style.darkMode ? "#801B1B21" : "#80FBF8FF")
    }

    Loader {
        id: leftLoader

        x: root.leftTranslateX
        y: 0
        width: root.leftWidth
        height: root.height
        visible: root.leftWidth > 0
        active: root.leftComponent !== null && root.leftWidth > 0
        sourceComponent: root.leftComponent
        asynchronous: true
    }

    Loader {
        id: centerLoader

        x: root.leftWidth + root.centerTranslateX
        y: 0
        width: Math.max(1, root.width - root.leftWidth)
        height: root.height
        active: root.centerComponent !== null
        sourceComponent: root.centerComponent
        asynchronous: true
    }
}
