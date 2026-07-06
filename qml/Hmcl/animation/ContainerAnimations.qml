pragma Singleton
import QtQuick

QtObject {
    enum Type {
        None,
        Fade,
        Forward,
        Backward,
        SwipeLeft,
        SwipeRight,
        SlideUpFadeIn,
        Navigation
    }

    readonly property int none: ContainerAnimations.Type.None
    readonly property int fade: ContainerAnimations.Type.Fade
    readonly property int forward: ContainerAnimations.Type.Forward
    readonly property int backward: ContainerAnimations.Type.Backward
    readonly property int swipeLeft: ContainerAnimations.Type.SwipeLeft
    readonly property int swipeRight: ContainerAnimations.Type.SwipeRight
    readonly property int slideUpFadeIn: ContainerAnimations.Type.SlideUpFadeIn
    readonly property int navigation: ContainerAnimations.Type.Navigation

    function opposite(type) {
        switch (type) {
        case ContainerAnimations.Type.Forward: return ContainerAnimations.Type.Backward
        case ContainerAnimations.Type.Backward: return ContainerAnimations.Type.Forward
        case ContainerAnimations.Type.SwipeLeft: return ContainerAnimations.Type.SwipeRight
        case ContainerAnimations.Type.SwipeRight: return ContainerAnimations.Type.SwipeLeft
        default: return type
        }
    }
}
