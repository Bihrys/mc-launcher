import QtQuick

QtObject {
    id: root

    property string themeMode: "light"
    property bool systemDark: false
    // 主题色：default(靛蓝) / purple / blue / green / red / orange，或自定义 "#RRGGBB"。
    property string themeColor: "default"

    readonly property bool darkMode: themeMode === "dark" || (themeMode === "system" && systemDark)

    property bool animationsEnabled: true
    readonly property int motionShort1: 50
    readonly property int motionShort2: 100
    readonly property int motionShort3: 150
    readonly property int motionShort4: 200
    readonly property int motionMedium2: 300
    readonly property int motionMedium3: 350
    readonly property int motionMedium4: 400

    // 主题色基准（浅色模式下使用的强调色）。深色模式自动调亮。
    readonly property color accentBase: {
        switch (themeColor) {
        case "purple": return "#6750A4"
        case "blue": return "#1565C0"
        case "green": return "#2E7D44"
        case "red": return "#B3261E"
        case "orange": return "#E0701A"
        case "default": return "#4352A5"
        default:
            // 自定义十六进制色，非法时回退默认。
            return (typeof themeColor === "string" && themeColor.charAt(0) === "#")
                   ? themeColor
                   : "#4352A5"
        }
    }

    // 深色模式下把强调色调亮，浅色模式直接使用基准色。
    readonly property color accent: darkMode ? Qt.lighter(accentBase, 1.55) : accentBase
    readonly property color accentHover: darkMode ? Qt.lighter(accentBase, 1.75) : Qt.lighter(accentBase, 1.12)
    readonly property color accentText: darkMode ? Qt.darker(accentBase, 2.2) : "#FFFFFF"

    readonly property color cPrimary: accent
    readonly property color cPrimaryContainer: darkMode ? Qt.darker(accentBase, 1.3) : Qt.lighter(accentBase, 1.25)
    readonly property color cTextOnPrimaryContainer: "#F8F6FF"

    readonly property color cBgStart: darkMode ? "#121318" : "#F8F6FF"
    readonly property color cBgEnd: darkMode ? "#1B1B24" : Qt.lighter(accentBase, 2.4)

    readonly property color cSurfaceTransparent: darkMode ? "#EE1B1B21" : "#EEFBF8FF"
    readonly property color cSurface: darkMode ? "#1B1B21" : "#FFFBFE"
    readonly property color cSurfaceContainer: darkMode ? "#CC252631" : "#CCF5F2FA"
    readonly property color cSurfaceContainerHigh: darkMode ? "#E82D2E3A" : "#E8F5F2FA"

    readonly property color cInverseSurface: darkMode ? "#E6E1E5" : "#313033"
    readonly property color cInverseSurfaceTransparent80: darkMode ? "#CCE6E1E5" : "#CC313033"
    readonly property color cInverseOnSurface: darkMode ? "#313033" : "#F4EFF4"

    readonly property color cTextOnSurface: darkMode ? "#E4E1E9" : "#1B1B21"
    readonly property color cTextOnSurfaceVariant: darkMode ? "#C7C5D0" : "#454651"

    readonly property color cNavSelected: Qt.rgba(accent.r, accent.g, accent.b, darkMode ? 0.40 : 0.22)
    readonly property color cNavHover: Qt.rgba(accent.r, accent.g, accent.b, darkMode ? 0.22 : 0.12)

    readonly property color cLaunchButton: accent
    readonly property color cLaunchButtonHover: accentHover
    readonly property color cLaunchButtonText: accentText

    readonly property color cBorder: darkMode ? "#3D3E4A" : "#D9D7E2"
    readonly property color cButtonSurface: darkMode ? "#2A2B36" : "#FFFFFF"
    readonly property color cButtonHover: darkMode ? "#343541" : "#F0F0F8"
    readonly property color cButtonSelected: accent
    readonly property color cButtonSelectedText: accentText

    property int titleBarHeightValue: 42
    property int sidebarWidthValue: 200
    property int radiusValue: 4
}
