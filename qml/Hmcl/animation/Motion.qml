import QtQuick

pragma Singleton

QtObject {
    // MD3 Duration tokens
    readonly property int short1: 50
    readonly property int short2: 100
    readonly property int short3: 150
    readonly property int short4: 200

    readonly property int medium1: 250
    readonly property int medium2: 300
    readonly property int medium3: 350
    readonly property int medium4: 400

    readonly property int long1: 450
    readonly property int long2: 500
    readonly property int long3: 550
    readonly property int long4: 600

    readonly property int extraLong1: 700
    readonly property int extraLong2: 800
    readonly property int extraLong3: 900
    readonly property int extraLong4: 1000

    // MD3 Easing curves (cubic-bezier control points)
    readonly property var emphasizedAccelerate: [0.3, 0.0, 0.8, 0.15]
    readonly property var emphasizedDecelerate: [0.05, 0.7, 0.1, 1.0]
    readonly property var standard: [0.2, 0.0, 0.0, 1.0]
    readonly property var standardAccelerate: [0.3, 0.0, 1.0, 1.0]
    readonly property var standardDecelerate: [0.0, 0.0, 0.0, 1.0]
    readonly property var legacy: [0.4, 0.0, 0.2, 1.0]
    readonly property var legacyDecelerate: [0.0, 0.0, 0.2, 1.0]
    readonly property var legacyAccelerate: [0.4, 0.0, 1.0, 1.0]

    readonly property var ease: [0.25, 0.1, 0.25, 1.0]
    readonly property var easeIn: [0.42, 0.0, 1.0, 1.0]
    readonly property var easeOut: [0.0, 0.0, 0.58, 1.0]
    readonly property var easeInOut: [0.42, 0.0, 0.58, 1.0]

    readonly property var easeInCubic: [0.55, 0.055, 0.675, 0.19]
    readonly property var easeOutCubic: [0.215, 0.61, 0.355, 1.0]
    readonly property var easeInOutCubic: [0.645, 0.045, 0.355, 1.0]

    readonly property var easeInQuart: [0.895, 0.03, 0.685, 0.22]
    readonly property var easeOutQuart: [0.165, 0.84, 0.44, 1.0]
    readonly property var easeInOutQuart: [0.77, 0.0, 0.175, 1.0]

    readonly property var fastOutSlowIn: [0.4, 0.0, 0.2, 1.0]
}
