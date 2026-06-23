import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root

    required property var appWindow
    required property var style

    property var pageState: null
    property int stateSerial: 0
    property string navigationDirection: "next"
    property bool navigatorCanBack: false

    signal backRequested()
    signal closeRequested()
    signal homeRequested()
    signal refreshRequested()

    property string shownTitle: ""
    property bool shownBrand: false
    property bool shownBack: false
    property bool shownClose: false
    property bool shownHome: false
    property bool shownRefresh: false

    property string incomingTitle: ""
    property bool incomingBrand: false
    property bool incomingBack: false
    property bool incomingClose: false
    property bool incomingHome: false
    property bool incomingRefresh: false

    property real oldOpacity: 0
    property real oldX: 0
    property real newOpacity: 1
    property real newX: 0

    height: style.titleBarHeightValue
    implicitHeight: style.titleBarHeightValue
    color: style.cPrimaryContainer
    clip: true

    Component.onCompleted: {
        root.syncShown()
    }

    onStateSerialChanged: {
        root.animateStateChange()
    }

    DragHandler {
        onActiveChanged: {
            if (active) {
                root.appWindow.startSystemMove()
            }
        }
    }

    function stateTitle() {
        return root.pageState && root.pageState.title ? root.pageState.title : ""
    }

    function stateBrand() {
        return root.pageState && root.pageState.showBrand === true
    }

    function stateBack() {
        if (!root.pageState || root.pageState.backable !== true) {
            return false
        }

        if (root.pageState.key === "main") {
            return false
        }

        return true
    }

    function stateClose() {
        return root.pageState && root.pageState.closeable === true
    }

    function stateHome() {
        return root.pageState && root.pageState.showCloseAsHome === true
    }

    function stateRefresh() {
        return root.pageState && root.pageState.refreshable === true
    }

    function syncShown() {
        root.shownTitle = root.stateTitle()
        root.shownBrand = root.stateBrand()
        root.shownBack = root.stateBack()
        root.shownClose = root.stateClose()
        root.shownHome = root.stateHome()
        root.shownRefresh = root.stateRefresh()
        root.oldOpacity = 0
        root.newOpacity = 1
        root.oldX = 0
        root.newX = 0
    }

    function animateStateChange() {
        if (!root.style.animationsEnabled) {
            root.syncShown()
            return
        }

        root.incomingTitle = root.stateTitle()
        root.incomingBrand = root.stateBrand()
        root.incomingBack = root.stateBack()
        root.incomingClose = root.stateClose()
        root.incomingHome = root.stateHome()
        root.incomingRefresh = root.stateRefresh()

        root.oldOpacity = 1
        root.newOpacity = 0
        root.oldX = 0
        root.newX = root.navigationDirection === "previous" ? -24 : 24

        navBarTransition.restart()
    }

    SequentialAnimation {
        id: navBarTransition

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "oldOpacity"
                from: 1
                to: 0
                duration: root.style.motionShort4 / 2
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "oldX"
                from: 0
                to: root.navigationDirection === "previous" ? 24 : -24
                duration: root.style.motionShort4 / 2
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "newOpacity"
                from: 0
                to: 1
                duration: root.style.motionShort4 / 2
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "newX"
                to: 0
                duration: root.style.motionShort4 / 2
                easing.type: Easing.OutCubic
            }
        }

        onFinished: {
            root.shownTitle = root.incomingTitle
            root.shownBrand = root.incomingBrand
            root.shownBack = root.incomingBack
            root.shownClose = root.incomingClose
            root.shownHome = root.incomingHome
            root.shownRefresh = root.incomingRefresh
            root.oldOpacity = 0
            root.newOpacity = 1
            root.oldX = 0
            root.newX = 0
        }
    }

    Item {
        id: navArea

        anchors.left: parent.left
        anchors.right: windowButtons.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        DecoratorNavContent {
            anchors.fill: parent
            opacityValue: navBarTransition.running ? root.oldOpacity : 0
            xOffset: navBarTransition.running ? root.oldX : 0
            title: root.shownTitle
            showBrand: root.shownBrand
            canBack: root.shownBack
            canClose: root.shownClose
            showHome: root.shownHome
            canRefresh: root.shownRefresh
            style: root.style
            onBackRequested: root.backRequested()
            onCloseRequested: root.closeRequested()
            onHomeRequested: root.homeRequested()
            onRefreshRequested: root.refreshRequested()
        }

        DecoratorNavContent {
            anchors.fill: parent
            opacityValue: navBarTransition.running ? root.newOpacity : 1
            xOffset: navBarTransition.running ? root.newX : 0
            title: navBarTransition.running ? root.incomingTitle : root.shownTitle
            showBrand: navBarTransition.running ? root.incomingBrand : root.shownBrand
            canBack: navBarTransition.running ? root.incomingBack : root.shownBack
            canClose: navBarTransition.running ? root.incomingClose : root.shownClose
            showHome: navBarTransition.running ? root.incomingHome : root.shownHome
            canRefresh: navBarTransition.running ? root.incomingRefresh : root.shownRefresh
            style: root.style
            onBackRequested: root.backRequested()
            onCloseRequested: root.closeRequested()
            onHomeRequested: root.homeRequested()
            onRefreshRequested: root.refreshRequested()
        }
    }

    Row {
        id: windowButtons

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 126
        spacing: 0

        WindowButton {
            style: root.style
            text: "—"
            hoverDanger: false
            onClicked: root.appWindow.showMinimized()
        }

        WindowButton {
            style: root.style
            text: root.appWindow.visibility === Window.Maximized ? "❐" : "□"
            hoverDanger: false
            onClicked: {
                if (root.appWindow.visibility === Window.Maximized) {
                    root.appWindow.showNormal()
                } else {
                    root.appWindow.showMaximized()
                }
            }
        }

        WindowButton {
            style: root.style
            text: "×"
            hoverDanger: true
            onClicked: Qt.quit()
        }
    }

    component DecoratorNavContent: Item {
        id: content

        required property var style
        property real opacityValue: 1
        property real xOffset: 0
        property string title: ""
        property bool showBrand: false
        property bool canBack: false
        property bool canClose: false
        property bool showHome: false
        property bool canRefresh: false

        signal backRequested()
        signal closeRequested()
        signal homeRequested()
        signal refreshRequested()

        opacity: opacityValue
        x: xOffset

        Row {
            id: navLeft

            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 0

            DecoratorIconButton {
                visible: content.canBack
                style: content.style
                iconKind: "ARROW_BACK"
                onClicked: content.backRequested()
            }

            DecoratorIconButton {
                visible: content.canClose
                style: content.style
                iconKind: content.showHome ? "HOME" : "CLOSE"
                onClicked: content.showHome ? content.homeRequested() : content.closeRequested()
            }
        }

        Row {
            anchors.left: navLeft.right
            anchors.leftMargin: 8
            anchors.right: refreshButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            clip: true

            Image {
                visible: content.showBrand
                width: 24
                height: 24
                source: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/icon-title.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: content.showBrand ? "Hello Minecraft! Launcher" : content.title
                visible: text.length > 0
                color: content.style.cTextOnPrimaryContainer
                font.pixelSize: 14
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.width)
            }
        }

        DecoratorIconButton {
            id: refreshButton

            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            visible: content.canRefresh
            style: content.style
            iconKind: "REFRESH"
            onClicked: content.refreshRequested()
        }
    }

    component DecoratorIconButton: Item {
        id: button

        required property var style
        property string iconKind: ""

        signal clicked()

        width: 40
        height: 40

        Rectangle {
            anchors.fill: parent
            color: mouse.containsMouse
                   ? Qt.rgba(button.style.cTextOnPrimaryContainer.r,
                             button.style.cTextOnPrimaryContainer.g,
                             button.style.cTextOnPrimaryContainer.b,
                             0.12)
                   : "transparent"
        }

        HmclSvgIcon {
            anchors.centerIn: parent
            icon: button.iconKind
            iconSize: 20
            iconColor: button.style.cTextOnPrimaryContainer
            animationsEnabled: button.style.animationsEnabled
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component WindowButton: Item {
        id: button

        required property var style
        property string text: ""
        property bool hoverDanger: false

        signal clicked()

        width: 42
        height: root.style.titleBarHeightValue

        Rectangle {
            anchors.fill: parent
            color: mouse.containsMouse
                   ? (button.hoverDanger ? "#D32F2F" : "#225B62C8")
                   : "transparent"
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: button.style.cTextOnPrimaryContainer
            font.pixelSize: 15
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
