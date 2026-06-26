import QtQuick
QtObject {
    required property var style
    readonly property color surface: style.cSurface
    readonly property color surfaceContainer: style.cSurfaceContainer
    readonly property color text: style.cTextOnSurface
    readonly property color subtext: style.cTextOnSurfaceVariant
    readonly property color border: style.cBorder
}
