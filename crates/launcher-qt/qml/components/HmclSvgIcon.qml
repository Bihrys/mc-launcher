import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string icon: "NONE"
    property color iconColor: "#000000"
    property int iconSize: 20
    property bool animationsEnabled: true
    property int animationDuration: 200

    property string currentPath: pathFor(icon)
    property string previousPath: ""

    width: iconSize
    height: iconSize

    onIconChanged: {
        var next = pathFor(icon)
        if (root.animationsEnabled && root.currentPath.length > 0 && next !== root.currentPath) {
            root.previousPath = root.currentPath
            root.currentPath = next
            fade.restart()
        } else {
            root.previousPath = ""
            root.currentPath = next
            oldShape.opacity = 0
            newShape.opacity = 1
        }
    }

    onIconColorChanged: {
        oldPath.fillColor = root.iconColor
        newPath.fillColor = root.iconColor
    }

    Shape {
        id: oldShape
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.iconSize / 24.0
        opacity: 0
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            id: oldPath
            fillColor: root.iconColor
            strokeWidth: -1

            PathSvg {
                path: root.previousPath
            }
        }
    }

    Shape {
        id: newShape
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.iconSize / 24.0
        opacity: 1
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            id: newPath
            fillColor: root.iconColor
            strokeWidth: -1

            PathSvg {
                path: root.currentPath
            }
        }
    }

    ParallelAnimation {
        id: fade

        NumberAnimation {
            target: oldShape
            property: "opacity"
            from: 1
            to: 0
            duration: root.animationsEnabled ? root.animationDuration : 0
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: newShape
            property: "opacity"
            from: 0
            to: 1
            duration: root.animationsEnabled ? root.animationDuration : 0
            easing.type: Easing.OutCubic
        }

        onStopped: root.previousPath = ""
    }

    function pathFor(name) {
        if (name === "ARROW_DROP_UP") return "M24 24ZM0 0ZM7 14 12 9 17 14H7Z"
        if (name === "CHAT") return "M24 24ZM0 0ZM6 14H14V12H6V14ZM6 11H18V9H6V11ZM6 8H18V6H6V8ZM2 22V4Q2 3.175 2.5875 2.5875T4 2H20Q20.825 2 21.4125 2.5875T22 4V16Q22 16.825 21.4125 17.4125T20 18H6L2 22ZM5.15 16H20V4H4V17.125L5.15 16ZM4 16V4 16Z"
        if (name === "DOWNLOAD") return "M24 24ZM0 0ZM12 16 7 11 8.4 9.55 11 12.15V4H13V12.15L15.6 9.55 17 11 12 16ZM6 20Q5.175 20 4.5875 19.4125T4 18V15H6V18H18V15H20V18Q20 18.825 19.4125 19.4125T18 20H6Z"
        if (name === "FORMAT_LIST_BULLETED") return "M24 24ZM0 0ZM9 19V17H21V19H9ZM9 13V11H21V13H9ZM9 7V5H21V7H9ZM5 20Q4.175 20 3.5875 19.4125T3 18Q3 17.175 3.5875 16.5875T5 16Q5.825 16 6.4125 16.5875T7 18Q7 18.825 6.4125 19.4125T5 20ZM5 14Q4.175 14 3.5875 13.4125T3 12Q3 11.175 3.5875 10.5875T5 10Q5.825 10 6.4125 10.5875T7 12Q7 12.825 6.4125 13.4125T5 14ZM5 8Q4.175 8 3.5875 7.4125T3 6Q3 5.175 3.5875 4.5875T5 4Q5.825 4 6.4125 4.5875T7 6Q7 6.825 6.4125 7.4125T5 8Z"
        if (name === "GRAPH2") return "M24 24ZM0 0ZM5 22q-1.25 0-2.125-.875T2 19q0-.975.5625-1.75T4 16.175V14q0-1.25.875-2.125T7 11h4V7.825q-.875-.3-1.4375-1.075T9 5q0-1.25.875-2.125T12 2t2.125.875T15 5q0 .975-.5625 1.75T13 7.825V11h4q1.25 0 2.125.875T20 14v2.175q.875.3 1.4375 1.075T22 19q0 1.25-.875 2.125T19 22t-2.125-.875T16 19q0-.975.5625-1.75T18 16.175V14q0-.425-.2875-.7125T17 13H13v3.175q.875.3 1.4375 1.075T15 19q0 1.25-.875 2.125T12 22t-2.125-.875T9 19q0-.975.5625-1.75T11 16.175V13H7q-.425 0-.7125.2875T6 14v2.175q.875.3 1.4375 1.075T8 19q0 1.25-.875 2.125T5 22Zm0-2q.425 0 .7125-.2875T6 19q0-.425-.2875-.7125T5 18q-.425 0-.7125.2875T4 19q0 .425.2875.7125T5 20Zm7 0q.425 0 .7125-.2875T13 19q0-.425-.2875-.7125T12 18q-.425 0-.7125.2875T11 19q0 .425.2875.7125T12 20Zm7 0q.425 0 .7125-.2875T20 19q0-.425-.2875-.7125T19 18q-.425 0-.7125.2875T18 19q0 .425.2875.7125T19 20ZM12 6q.425 0 .7125-.2875T13 5q0-.425-.2875-.7125T12 4q-.425 0-.7125.2875T11 5q0 .425.2875.7125T12 6Z"
        if (name === "SETTINGS") return "M24 24ZM0 0ZM19.43 12.98C19.47 12.66 19.5 12.34 19.5 12 19.5 11.66 19.47 11.34 19.43 11.02L21.54 9.37C21.73 9.22 21.78 8.95 21.66 8.73L19.66 5.27C19.57 5.11 19.4 5.02 19.22 5.02 19.16 5.02 19.1 5.03 19.05 5.05L16.56 6.05C16.04 5.65 15.48 5.32 14.87 5.07L14.49 2.42C14.46 2.18 14.25 2 14 2H10C9.75 2 9.54 2.18 9.51 2.42L9.13 5.07C8.52 5.32 7.96 5.66 7.44 6.05L4.95 5.05C4.89 5.03 4.83 5.02 4.77 5.02 4.6 5.02 4.43 5.11 4.34 5.27L2.34 8.73C2.21 8.95 2.27 9.22 2.46 9.37L4.57 11.02C4.53 11.34 4.5 11.67 4.5 12 4.5 12.33 4.53 12.66 4.57 12.98L2.46 14.63C2.27 14.78 2.22 15.05 2.34 15.27L4.34 18.73C4.43 18.89 4.6 18.98 4.78 18.98 4.84 18.98 4.9 18.97 4.95 18.95L7.44 17.95C7.96 18.35 8.52 18.68 9.13 18.93L9.51 21.58C9.54 21.82 9.75 22 10 22H14C14.25 22 14.46 21.82 14.49 21.58L14.87 18.93C15.48 18.68 16.04 18.34 16.56 17.95L19.05 18.95C19.11 18.97 19.17 18.98 19.23 18.98 19.4 18.98 19.57 18.89 19.66 18.73L21.66 15.27C21.78 15.05 21.73 14.78 21.54 14.63L19.43 12.98ZM17.45 11.27C17.49 11.58 17.5 11.79 17.5 12 17.5 12.21 17.48 12.43 17.45 12.73L17.31 13.86 18.2 14.56 19.28 15.4 18.58 16.61 17.31 16.1 16.27 15.68 15.37 16.36C14.94 16.68 14.53 16.92 14.12 17.09L13.06 17.52 12.9 18.65 12.7 20H11.3L11.11 18.65 10.95 17.52 9.89 17.09C9.46 16.91 9.06 16.68 8.66 16.38L7.75 15.68 6.69 16.11 5.42 16.62 4.72 15.41 5.8 14.57 6.69 13.87 6.55 12.74C6.52 12.43 6.5 12.2 6.5 12S6.52 11.57 6.55 11.27L6.69 10.14 5.8 9.44 4.72 8.6 5.42 7.39 6.69 7.9 7.73 8.32 8.63 7.64C9.06 7.32 9.47 7.08 9.88 6.91L10.94 6.48 11.1 5.35 11.3 4H12.69L12.88 5.35 13.04 6.48 14.1 6.91C14.53 7.09 14.93 7.32 15.33 7.62L16.24 8.32 17.3 7.89 18.57 7.38 19.27 8.59 18.2 9.44 17.31 10.14 17.45 11.27ZM12 8C9.79 8 8 9.79 8 12S9.79 16 12 16 16 14.21 16 12 14.21 8 12 8ZM12 14C10.9 14 10 13.1 10 12S10.9 10 12 10 14 10.9 14 12 13.1 14 12 14Z"
        return ""
    }
}
