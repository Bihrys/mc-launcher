import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var style
    required property var backend

    signal openInstance(string versionId)

    readonly property string iconBase: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/"
    property string minecraftRoot: ""
    property string profileRoot: ""
    property string selectedInstance: ""
    property bool searchMode: false
    property string searchText: ""
    property bool loading: false

    ListModel {
        id: profileModel
    }

    ListModel {
        id: instanceModel
    }

    ListModel {
        id: filteredInstanceModel
    }

    Component.onCompleted: root.reloadInstances()

    onVisibleChanged: {
        if (visible) {
            root.reloadInstances()
        }
    }

    onSearchTextChanged: root.rebuildFilteredInstances()

    Connections {
        target: root.backend

        function onInstanceListJsonChanged() {
            root.applyInstancesJson(root.backend.instanceListJson)
        }

        function onInstalledVersionsJsonChanged() {
            if (!root.backend.instanceListJson || root.backend.instanceListJson.length === 0) {
                root.reloadInstances()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: root.style.sidebarWidthValue
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        width: root.style.sidebarWidthValue
                        spacing: 0

                        Item { width: 1; height: 12 }

                        ClassTitle {
                            style: root.style
                            title: "游戏目录"
                        }

                        Repeater {
                            model: profileModel

                            delegate: NavRow {
                                style: root.style
                                title: name
                                subtitle: path
                                iconKind: "DRESSER"
                                active: index === 0
                            }
                        }

                        NavRow {
                            style: root.style
                            title: "新建游戏目录"
                            subtitle: "Profile"
                            iconKind: "ADD_CIRCLE"
                            active: false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40 * 3 + 24
                    color: "transparent"

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 0

                        NavRow {
                            style: root.style
                            title: "安装新游戏"
                            iconKind: "ADD_CIRCLE"
                            active: false
                            onClicked: root.backend.output = "请回到下载页安装新游戏。"
                        }

                        NavRow {
                            style: root.style
                            title: "导入整合包"
                            iconKind: "PACKAGE2"
                            active: false
                            onClicked: root.backend.output = "拖入整合包或在下载页安装整合包。"
                        }

                        NavRow {
                            style: root.style
                            title: "全局游戏设置"
                            iconKind: "SETTINGS"
                            active: false
                            onClicked: root.backend.output = "全局设置位于设置页。"
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: root.style.radiusValue
                color: root.style.cSurfaceContainerHigh
                border.width: 1
                border.color: root.style.cBorder
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48

                        Loader {
                            anchors.fill: parent
                            sourceComponent: root.searchMode ? searchToolbar : normalToolbar
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.style.cBorder
                        opacity: 0.55
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        HmclBusySpinner {
                            anchors.centerIn: parent
                            visible: root.loading
                            style: root.style
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: !root.loading && filteredInstanceModel.count === 0
                            spacing: 12

                            HmclSvgIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: "ADD_CIRCLE"
                                iconSize: 48
                                iconColor: root.style.cTextOnSurfaceVariant
                                animationsEnabled: root.style.animationsEnabled
                            }

                            Text {
                                width: 360
                                horizontalAlignment: Text.AlignHCenter
                                text: root.searchText.length > 0 ? "没有匹配的实例" : "还没有游戏实例"
                                color: root.style.cTextOnSurface
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                width: 360
                                horizontalAlignment: Text.AlignHCenter
                                text: root.searchText.length > 0 ? "清空搜索内容后重新查看列表。" : "到下载页安装游戏，或导入已有整合包。"
                                color: root.style.cTextOnSurfaceVariant
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }

                        ListView {
                            id: listView
                            anchors.fill: parent
                            visible: !root.loading && filteredInstanceModel.count > 0
                            clip: true
                            model: filteredInstanceModel
                            spacing: 0
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: GameListCellQt {
                                width: listView.width
                                style: root.style
                                iconSource: root.iconBase + iconName + ".png"
                                title: model.title
                                subtitle: model.subtitle
                                tag: model.tag
                                selected: model.selected
                                canUpdate: model.isModpack

                                onSelectRequested: {
                                    root.backend.selectInstance(model.id)
                                    root.reloadInstances()
                                }

                                onOpenRequested: root.openInstance(model.id)
                                onLaunchRequested: {
                                    root.backend.selectInstance(model.id)
                                    root.backend.startLaunchSelectedVersion("keep")
                                }
                                onManageRequested: root.openInstance(model.id)
                                onUpdateRequested: root.openInstance(model.id)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: normalToolbar

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 0

            ToolButtonLike {
                style: root.style
                text: "刷新"
                iconKind: "REFRESH"
                onClicked: root.reloadInstances()
            }

            ToolButtonLike {
                style: root.style
                text: "搜索"
                iconKind: "SEARCH"
                onClicked: root.searchMode = true
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.minecraftRoot.length > 0 ? root.minecraftRoot : ""
                color: root.style.cTextOnSurfaceVariant
                font.pixelSize: 11
                elide: Text.ElideLeft
                Layout.maximumWidth: 360
            }
        }
    }

    Component {
        id: searchToolbar

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 3
                color: root.style.cButtonSurface
                border.width: 1
                border.color: searchInput.activeFocus ? root.style.cButtonSelected : root.style.cBorder

                TextField {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: root.searchText
                    placeholderText: "搜索"
                    color: root.style.cTextOnSurface
                    placeholderTextColor: root.style.cTextOnSurfaceVariant
                    selectByMouse: true
                    background: Item {}
                    onTextChanged: root.searchText = text
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: {
                        root.searchMode = false
                        root.searchText = ""
                    }
                }
            }

            ToolButtonLike {
                style: root.style
                text: ""
                iconKind: "CLOSE"
                onClicked: {
                    root.searchMode = false
                    root.searchText = ""
                }
            }
        }
    }

    function reloadInstances() {
        root.loading = true
        var raw = root.backend.refreshInstances()
        root.applyInstancesJson(raw)
        root.loading = false
    }

    function applyInstancesJson(raw) {
        if (!raw || raw.length === 0) {
            return
        }

        var payload = JSON.parse(raw)
        instanceModel.clear()
        profileModel.clear()

        root.minecraftRoot = payload.minecraftRoot || ""
        root.profileRoot = payload.profileRoot || ""
        root.selectedInstance = payload.selectedInstance || ""

        var profiles = payload.profiles || []
        for (var p = 0; p < profiles.length; p++) {
            profileModel.append({
                "id": profiles[p].id || "default",
                "name": profiles[p].name || "默认游戏目录",
                "path": profiles[p].path || ""
            })
        }
        if (profileModel.count === 0) {
            profileModel.append({
                "id": "default",
                "name": "默认游戏目录",
                "path": root.minecraftRoot
            })
        }

        var instances = payload.instances || []
        for (var i = 0; i < instances.length; i++) {
            var item = instances[i]
            instanceModel.append({
                "id": item.id || "",
                "title": item.title || item.id || "",
                "tag": item.tag || "",
                "subtitle": item.subtitle || item.gameVersion || "",
                "iconName": item.iconName || "grass",
                "selected": !!item.selected,
                "isModpack": !!item.isModpack,
                "isIsolated": !!item.isIsolated,
                "path": item.path || "",
                "runDirectory": item.runDirectory || ""
            })
        }

        root.rebuildFilteredInstances()
    }

    function rebuildFilteredInstances() {
        filteredInstanceModel.clear()
        var needle = root.searchText.toLowerCase()

        for (var i = 0; i < instanceModel.count; i++) {
            var item = instanceModel.get(i)
            var text = (item.id + " " + item.title + " " + item.subtitle + " " + item.tag).toLowerCase()
            if (needle.length === 0 || text.indexOf(needle) >= 0) {
                filteredInstanceModel.append(item)
            }
        }
    }

    component ClassTitle: Item {
        id: item
        required property var style
        property string title: ""
        width: parent ? parent.width : 200
        height: 34

        Column {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 8
            anchors.bottomMargin: 8

            Text {
                width: parent.width
                height: 16
                text: item.title
                color: item.style.cTextOnSurface
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: item.style.cTextOnSurfaceVariant
                opacity: 0.65
            }
        }
    }

    component NavRow: Item {
        id: item
        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconKind: "FORMAT_LIST_BULLETED"
        property bool active: false
        signal clicked()

        width: parent ? parent.width : 200
        height: subtitle.length > 0 ? 58 : 40

        Rectangle {
            anchors.fill: parent
            color: item.active ? item.style.cNavSelected : "transparent"
        }

        HmclRipple {
            id: ripple
            anchors.fill: parent
            hovered: mouse.containsMouse
            hoverColor: item.style.cTextOnSurface
            hoverOpacity: 0.04
            rippleColor: item.style.cTextOnSurfaceVariant
            rippleOpacity: 0.10
            animationsEnabled: item.style.animationsEnabled
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(event) { ripple.press(event.x, event.y) }
            onClicked: item.clicked()
        }

        HmclSvgIcon {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            icon: item.iconKind
            iconSize: 20
            iconColor: item.style.cTextOnSurface
            animationsEnabled: item.style.animationsEnabled
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: item.title
                color: item.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: item.active
                elide: Text.ElideRight
            }

            Text {
                visible: item.subtitle.length > 0
                width: parent.width
                text: item.subtitle
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideLeft
            }
        }
    }

    component ToolButtonLike: Rectangle {
        id: button
        required property var style
        property string text: ""
        property string iconKind: "REFRESH"
        signal clicked()

        width: Math.max(40, icon.width + label.implicitWidth + (button.text.length > 0 ? 24 : 16))
        height: 36
        radius: 3
        color: mouse.containsMouse ? button.style.cButtonHover : "transparent"

        HmclRipple {
            id: ripple
            anchors.fill: parent
            hovered: mouse.containsMouse
            hoverColor: button.style.cTextOnSurface
            hoverOpacity: 0.04
            rippleColor: button.style.cTextOnSurfaceVariant
            rippleOpacity: 0.10
            animationsEnabled: button.style.animationsEnabled
        }

        Row {
            anchors.centerIn: parent
            spacing: button.text.length > 0 ? 6 : 0

            HmclSvgIcon {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                icon: button.iconKind
                iconSize: 20
                iconColor: button.style.cTextOnSurface
                animationsEnabled: button.style.animationsEnabled
            }

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                visible: button.text.length > 0
                text: button.text
                color: button.style.cTextOnSurface
                font.pixelSize: 13
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(event) { ripple.press(event.x, event.y) }
            onClicked: button.clicked()
        }
    }

    component GameListCellQt: Item {
        id: item
        required property var style
        property string title: ""
        property string subtitle: ""
        property string tag: ""
        property string iconSource: ""
        property bool selected: false
        property bool canUpdate: false

        signal selectRequested()
        signal openRequested()
        signal launchRequested()
        signal manageRequested()
        signal updateRequested()

        height: 64

        Rectangle {
            anchors.fill: parent
            color: mouse.containsMouse ? item.style.cNavHover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: item.style.animationsEnabled ? item.style.motionShort4 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }

        HmclRipple {
            id: ripple
            anchors.fill: parent
            hovered: mouse.containsMouse
            hoverColor: item.style.cTextOnSurface
            hoverOpacity: 0.04
            rippleColor: item.style.cTextOnSurfaceVariant
            rippleOpacity: 0.10
            animationsEnabled: item.style.animationsEnabled
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(event) { ripple.press(event.x, event.y) }
            onClicked: function(event) {
                if (event.button === Qt.RightButton) {
                    item.manageRequested()
                } else {
                    item.openRequested()
                }
            }
        }

        RadioButton {
            id: selectedButton
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            checked: item.selected
            onClicked: item.selectRequested()
        }

        HmclImageContainer {
            anchors.left: parent.left
            anchors.leftMargin: 56
            anchors.verticalCenter: parent.verticalCenter
            style: item.style
            source: item.iconSource
            imageSize: 32
            animationsEnabled: item.style.animationsEnabled
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 96
            anchors.right: rightButtons.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Row {
                width: parent.width
                spacing: 6

                Text {
                    text: item.title
                    color: item.style.cTextOnSurface
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - tagChip.width - 10)
                }

                Rectangle {
                    id: tagChip
                    visible: item.tag.length > 0
                    width: tagText.implicitWidth + 10
                    height: 18
                    radius: 2
                    color: item.style.cNavSelected

                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: item.tag
                        color: item.style.cTextOnSurface
                        font.pixelSize: 10
                    }
                }
            }

            Text {
                width: parent.width
                text: item.subtitle
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Row {
            id: rightButtons
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            IconButton {
                style: item.style
                iconKind: "UPDATE"
                visible: item.canUpdate
                onClicked: item.updateRequested()
            }

            IconButton {
                style: item.style
                iconKind: "ROCKET_LAUNCH"
                onClicked: item.launchRequested()
            }

            IconButton {
                style: item.style
                iconKind: "MORE_VERT"
                onClicked: item.manageRequested()
            }
        }
    }

    component IconButton: Item {
        id: button
        required property var style
        property string iconKind: "MORE_VERT"
        signal clicked()

        width: 36
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: mouse.containsMouse ? button.style.cButtonHover : "transparent"
        }

        HmclSvgIcon {
            anchors.centerIn: parent
            icon: button.iconKind
            iconSize: 20
            iconColor: button.style.cTextOnSurface
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

    component HmclBusySpinner: Item {
        id: spinner
        required property var style
        width: 48
        height: 48

        Canvas {
            id: canvas
            anchors.fill: parent
            property real angle: 0
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.save()
                ctx.translate(width / 2, height / 2)
                ctx.rotate(angle)
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                ctx.strokeStyle = spinner.style.cTextOnSurfaceVariant
                ctx.globalAlpha = 0.88
                ctx.beginPath()
                ctx.arc(0, 0, Math.min(width, height) / 2 - 5, -Math.PI * 0.15, Math.PI * 1.25)
                ctx.stroke()
                ctx.restore()
            }

            NumberAnimation on angle {
                from: 0
                to: Math.PI * 2
                duration: 900
                loops: Animation.Infinite
                running: spinner.visible
                easing.type: Easing.Linear
                onRunningChanged: canvas.requestPaint()
            }

            onAngleChanged: requestPaint()
        }
    }
}
