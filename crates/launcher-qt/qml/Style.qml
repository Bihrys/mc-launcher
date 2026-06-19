import QtQuick

QtObject {
    id: root

    property string themeMode: "light"
    property bool systemDark: false

    readonly property bool darkMode: themeMode === "dark" || (themeMode === "system" && systemDark)

    readonly property color cPrimary: darkMode ? "#BFC2FF" : "#4352A5"
    readonly property color cPrimaryContainer: darkMode ? "#303B85" : "#5C6BC0"
    readonly property color cTextOnPrimaryContainer: "#F8F6FF"

    readonly property color cBgStart: darkMode ? "#121318" : "#F8F6FF"
    readonly property color cBgEnd: darkMode ? "#1B1B24" : "#DDE2FF"

    readonly property color cSurfaceTransparent: darkMode ? "#EE1B1B21" : "#EEFBF8FF"
    readonly property color cSurface: darkMode ? "#1B1B21" : "#FFFBFE"
    readonly property color cSurfaceContainer: darkMode ? "#CC252631" : "#CCF5F2FA"
    readonly property color cSurfaceContainerHigh: darkMode ? "#E82D2E3A" : "#E8F5F2FA"

    readonly property color cTextOnSurface: darkMode ? "#E4E1E9" : "#1B1B21"
    readonly property color cTextOnSurfaceVariant: darkMode ? "#C7C5D0" : "#454651"

    readonly property color cNavSelected: darkMode ? "#664352A5" : "#80D0D5FD"
    readonly property color cNavHover: darkMode ? "#44303B85" : "#44D0D5FD"

    readonly property color cLaunchButton: darkMode ? "#BFC2FF" : "#4352A5"
    readonly property color cLaunchButtonHover: darkMode ? "#D9DBFF" : "#5363BF"
    readonly property color cLaunchButtonText: darkMode ? "#202452" : "#FFFFFF"

    readonly property color cBorder: darkMode ? "#3D3E4A" : "#D9D7E2"
    readonly property color cButtonSurface: darkMode ? "#2A2B36" : "#FFFFFF"
    readonly property color cButtonHover: darkMode ? "#343541" : "#F0F0F8"
    readonly property color cButtonSelected: darkMode ? "#BFC2FF" : "#4352A5"
    readonly property color cButtonSelectedText: darkMode ? "#202452" : "#FFFFFF"

    property int titleBarHeightValue: 42
    property int sidebarWidthValue: 200
    property int radiusValue: 4
}
