import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

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
    property bool menuOpen: false
    property string menuInstanceId: ""
    property real menuX: 0
    property real menuY: 0

    ListModel { id: profileModel }
    ListModel { id: instanceModel }
    ListModel { id: filteredInstanceModel }

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
                                required property string profileName
                                required property string profilePath
                                required property int index

                                style: root.style
                                title: profileName
                                subtitle: profilePath
                                iconKind: "DRESSER"
                                active: index === 0
                            }
                        }

                        NavRow {
                            style: root.style
                            title: "新建游戏目录"
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
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: GameListCellQt {
                                id: cell

                                required property string roleInstanceId
                                required property string roleTitle
                                required property string roleSubtitle
                                required property string roleTag
                                required property string roleIconName
                                required property bool roleSelected
                                required property bool roleCanUpdate

                                width: listView.width
                                style: root.style
                                iconSource: root.iconBase + roleIconName + ".png"
                                title: roleTitle
                                subtitle: roleSubtitle
                                tag: roleTag
                                selected: roleSelected
                                canUpdate: roleCanUpdate

                                onSelectRequested: {
                                    root.backend.selectInstance(roleInstanceId)
                                    root.reloadInstances()
                                }

                                onOpenRequested: root.openInstance(roleInstanceId)
                                onLaunchRequested: {
                                    root.backend.selectInstance(roleInstanceId)
                                    root.backend.startLaunchSelectedVersion("keep")
                                }
                                onManageRequested: function(localX, localY) {
                                    var pos = cell.mapToItem(root, localX, localY)
                                    root.openGameMenu(roleInstanceId, pos.x, pos.y)
                                }
                                onUpdateRequested: root.openInstance(roleInstanceId)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.menuOpen
        z: 900
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: root.menuOpen = false
        }

        Rectangle {
            id: contextMenu
            x: root.menuX
            y: root.menuY
            width: 250
            height: menuColumn.implicitHeight + 8
            radius: 2
            color: root.style.cSurface
            border.width: 1
            border.color: root.style.cBorder
            clip: true

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 0

                MenuRow { style: root.style; title: "测试游戏"; iconKind: "ROCKET_LAUNCH"; onClicked: root.menuLaunch() }
                MenuRow { style: root.style; title: "生成启动脚本"; iconKind: "SCRIPT"; onClicked: root.menuScript() }
                MenuSeparator { style: root.style }
                MenuRow { style: root.style; title: "管理"; iconKind: "SETTINGS"; onClicked: root.menuManage() }
                MenuSeparator { style: root.style }
                MenuRow { style: root.style; title: "打开游戏文件夹"; iconKind: "FOLDER_OPEN"; onClicked: root.menuOpenFolder() }
            }
        }
    }

    Component {
        id: normalToolbar

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
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
        }
    }

    Component {
        id: searchToolbar

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            spacing: 5

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
        root.menuOpen = false
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
                "profileId": profiles[p].id || "default",
                "profileName": profiles[p].name || "默认游戏目录",
                "profilePath": profiles[p].path || ""
            })
        }
        if (profileModel.count === 0) {
            profileModel.append({
                "profileId": "default",
                "profileName": "默认游戏目录",
                "profilePath": root.minecraftRoot
            })
        }

        var instances = payload.instances || []
        for (var i = 0; i < instances.length; i++) {
            var item = instances[i]
            instanceModel.append({
                "roleInstanceId": item.id || "",
                "roleTitle": item.title || item.id || "",
                "roleTag": item.tag || "",
                "roleSubtitle": item.subtitle || item.gameVersion || "",
                "roleIconName": item.iconName || "grass",
                "roleSelected": !!item.selected,
                "roleCanUpdate": !!item.isModpack,
                "roleSearchText": ((item.id || "") + " " + (item.title || "") + " " + (item.subtitle || "") + " " + (item.tag || "")).toLowerCase()
            })
        }

        root.rebuildFilteredInstances()
    }

    function rebuildFilteredInstances() {
        filteredInstanceModel.clear()
        var needle = root.searchText.toLowerCase()

        for (var i = 0; i < instanceModel.count; i++) {
            var item = instanceModel.get(i)
            if (needle.length === 0 || item.roleSearchText.indexOf(needle) >= 0) {
                filteredInstanceModel.append({
                    "roleInstanceId": item.roleInstanceId,
                    "roleTitle": item.roleTitle,
                    "roleTag": item.roleTag,
                    "roleSubtitle": item.roleSubtitle,
                    "roleIconName": item.roleIconName,
                    "roleSelected": item.roleSelected,
                    "roleCanUpdate": item.roleCanUpdate,
                    "roleSearchText": item.roleSearchText
                })
            }
        }
    }

    function openGameMenu(instanceId, x, y) {
        root.menuInstanceId = instanceId
        root.menuX = Math.max(8, Math.min(x - 250, root.width - 260))
        root.menuY = Math.max(8, Math.min(y - 8, root.height - 220))
        root.menuOpen = true
    }

    function closeGameMenu() {
        root.menuOpen = false
    }

    function menuLaunch() {
        var id = root.menuInstanceId
        root.closeGameMenu()
        root.backend.selectInstance(id)
        root.backend.startLaunchSelectedVersion("keep")
    }

    function menuScript() {
        var id = root.menuInstanceId
        root.closeGameMenu()
        root.backend.generateInstanceLaunchCommand(id)
    }

    function menuManage() {
        var id = root.menuInstanceId
        root.closeGameMenu()
        root.openInstance(id)
    }

    function menuOpenFolder() {
        var id = root.menuInstanceId
        root.closeGameMenu()
        root.backend.openInstanceFolder(id, "game")
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
            spacing: 0

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
        height: 37
        radius: 5
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
        signal manageRequested(real x, real y)
        signal updateRequested()

        height: 49

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
                    item.manageRequested(event.x, event.y)
                } else {
                    item.openRequested()
                }
            }
        }

        HmclRadioCircle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            style: item.style
            checked: item.selected
            onClicked: item.selectRequested()
        }

        HmclImageContainer {
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.verticalCenter: parent.verticalCenter
            style: item.style
            source: item.iconSource
            imageSize: 32
            animationsEnabled: item.style.animationsEnabled
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 88
            anchors.right: rightButtons.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                width: parent.width
                height: 20
                spacing: 8

                Text {
                    text: item.title
                    color: item.style.cTextOnSurface
                    font.pixelSize: 15
                    font.bold: false
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    width: Math.min(implicitWidth, parent.width - (tagChip.visible ? tagChip.width + 10 : 0))
                }

                Rectangle {
                    id: tagChip
                    visible: item.tag.length > 0
                    width: tagText.implicitWidth + 8
                    height: 18
                    radius: 2
                    color: item.style.cNavSelected

                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: item.tag
                        color: item.style.cTextOnSurface
                        font.pixelSize: 12
                    }
                }
            }

            Text {
                width: parent.width
                height: 17
                text: item.subtitle
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 12
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
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
                onClicked: {
                    var p = rightButtons.mapToItem(item, rightButtons.width, rightButtons.height / 2)
                    item.manageRequested(p.x, p.y)
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: item.style.cBorder
            opacity: 0.75
        }
    }

    component HmclRadioCircle: Item {
        id: radio
        required property var style
        property bool checked: false
        signal clicked()

        width: 28
        height: 28

        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.width: 2
            border.color: radio.checked ? radio.style.cPrimary : radio.style.cTextOnSurfaceVariant
        }

        Rectangle {
            anchors.centerIn: parent
            width: 9
            height: 9
            radius: 5
            visible: radio.checked
            color: radio.style.cPrimary
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: radio.clicked()
        }
    }

    component IconButton: Item {
        id: button
        required property var style
        property string iconKind: "MORE_VERT"
        signal clicked()

        width: 30
        height: 30

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

    component MenuRow: Item {
        id: row
        required property var style
        property string title: ""
        property string iconKind: "SETTINGS"
        signal clicked()

        width: parent ? parent.width : 250
        height: 32

        Rectangle {
            anchors.fill: parent
            color: mouse.containsMouse ? row.style.cNavHover : "transparent"
        }

        HmclSvgIcon {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            icon: row.iconKind
            iconSize: 18
            iconColor: row.style.cTextOnSurface
            animationsEnabled: row.style.animationsEnabled
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 42
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.title
            color: row.style.cTextOnSurface
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    component MenuSeparator: Rectangle {
        required property var style
        width: parent ? parent.width : 250
        height: 1
        color: style.cBorder
        opacity: 0.75
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
            }

            onAngleChanged: requestPaint()
        }
    }
}
