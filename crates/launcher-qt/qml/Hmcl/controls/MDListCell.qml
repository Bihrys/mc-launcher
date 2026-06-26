import QtQuick

Item {
    id: root

    // HMCL 基础列表行。style 由外层页面传入；为了避免 QML 创建阶段 style 尚未绑定时刷 undefined，
    // 所有颜色读取都必须经过 styleColor()。
    property var style
    property bool hovered: mouse.containsMouse

    signal clicked()

    implicitHeight: 48

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null) {
                return value
            }
        }
        return fallback
    }

    function styleColor(name, fallback) {
        return styleValue(name, fallback)
    }

    Rectangle {
        anchors.fill: parent
        color: root.hovered ? root.styleColor("cNavHover", "transparent") : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.styleColor("cBorder", "transparent")
        opacity: 0.7
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }
}
