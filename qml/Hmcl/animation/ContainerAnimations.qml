pragma Singleton
import QtQuick

QtObject {
    readonly property int none: 0
    readonly property int fade: 1
    readonly property int forward: 2
    readonly property int backward: 3
    readonly property int swipeLeft: 4
    readonly property int swipeRight: 5
    readonly property int slideUpFadeIn: 6
    readonly property int navigation: 7

    function opposite(type) {
        if (type === 2) return 3
        if (type === 3) return 2
        if (type === 4) return 5
        if (type === 5) return 4
        return type
    }
}
