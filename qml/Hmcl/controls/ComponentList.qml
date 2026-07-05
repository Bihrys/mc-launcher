import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Qt 转写 HMCL ComponentList.java / root.css:
    // .options-list: transparent background + depth shadow
    // .options-list-item: surface background, 1px top border, radius由首尾项承担。
    property var style
    property real radiusValue: 4
    default property alias content: contentColumn.children

    width: parent ? parent.width : 600
    implicitHeight: contentColumn.implicitHeight

    function styleValue(name, fallback) {
        if (root.style !== undefined && root.style !== null) {
            var value = root.style[name]
            if (value !== undefined && value !== null)
                return value
        }
        return fallback
    }

    // 近似 HMCL .options-list depth：不用额外 Qt GraphicalEffects，避免增加模块依赖。
    Rectangle {
        anchors.fill: surface
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        anchors.topMargin: 1
        anchors.bottomMargin: -1
        radius: root.radiusValue
        color: "#000000"
        opacity: 0.10
        visible: contentColumn.children.length > 0
    }

    Rectangle {
        id: surface
        anchors.fill: contentColumn
        radius: root.radiusValue
        color: root.styleValue("cSurface", "#FFFBFE")
        border.width: 0
        visible: contentColumn.children.length > 0
    }

    Column {
        id: contentColumn
        width: root.width
        spacing: 0
    }
}
