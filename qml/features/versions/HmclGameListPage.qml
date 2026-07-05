pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.bihrys.launcher
import "../../components"
import "../../Hmcl/controls"

// 实例列表页（对齐 HMCL GameListPage）。
//
// 瘦编排：数据来自真正的 cxx-qt 模型 GameListModel / ProfileListModel（QAbstractListModel），
// 不经过 JSON.parse。左侧游戏目录面板 + 安装/导入/全局设置；右侧工具栏（刷新/搜索）+ 列表。
Item {
    id: root

    required property var style
    required property var backend

    signal openInstance(string versionId)

    readonly property string iconBase: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/"
    property bool searchMode: false
    property string menuInstanceId: ""

    // 真模型：QML 元素，自动注册到 com.bihrys.launcher。
    GameListModel { id: gameListModel }
    ProfileListModel { id: profileListModel }

    Component.onCompleted: {
        gameListModel.refresh()
        profileListModel.refresh()
    }

    onVisibleChanged: {
        if (visible) {
            gameListModel.refresh()
            profileListModel.refresh()
        }
    }

    // 搜索防抖（对齐 HMCL 的 100ms PauseTransition）。
    property string pendingSearch: ""
    Timer {
        id: searchDebounce
        interval: 100
        repeat: false
        onTriggered: gameListModel.setSearch(root.pendingSearch)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // —— 左侧：游戏目录面板 ——
        Rectangle {
            Layout.preferredWidth: root.style.sidebarWidthValue
            Layout.fillHeight: true
            color: "transparent"

            ProfileListPane {
                anchors.fill: parent
                style: root.style
                profileModel: profileListModel

                onInstallRequested: root.backend.output = "请回到下载页安装新游戏。"
                onImportRequested: root.backend.output = "拖入整合包或在下载页安装整合包。"
                onGlobalSettingsRequested: root.backend.output = "全局设置位于设置页。"
            }
        }

        // —— 右侧：工具栏 + 列表 ——
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

                    GameListToolbar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        style: root.style
                        searchMode: root.searchMode

                        onRefreshRequested: {
                            gameListModel.refresh()
                            profileListModel.refresh()
                        }

                        onSearchTextEdited: function(text) {
                            root.pendingSearch = text
                            searchDebounce.restart()
                        }

                        onSearchModeChangedByUser: function(mode) {
                            root.searchMode = mode
                            if (!mode) {
                                root.pendingSearch = ""
                                gameListModel.setSearch("")
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // 加载中
                        SpinnerPane {
                            anchors.centerIn: parent
                            visible: gameListModel.loading
                            style: root.style
                        }

                        // 空状态（对齐 HMCL version.empty.hint -> 点击跳转下载页）
                        Item {
                            anchors.centerIn: parent
                            width: 360
                            height: emptyCol.implicitHeight
                            visible: !gameListModel.loading && gameListModel.isEmpty

                            ColumnLayout {
                                id: emptyCol
                                anchors.fill: parent
                                spacing: 12

                                HmclSvgIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    icon: "ADD_CIRCLE"
                                    iconSize: 48
                                    iconColor: root.style.cTextOnSurfaceVariant
                                    animationsEnabled: root.style.animationsEnabled
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "还没有游戏实例"
                                    color: root.style.cTextOnSurface
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "点击安装游戏，或导入已有整合包。"
                                    color: root.style.cTextOnSurfaceVariant
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.backend.output = "请回到下载页安装新游戏。"
                            }
                        }

                        // 实例列表
                        ListView {
                            id: listView
                            anchors.fill: parent
                            visible: !gameListModel.loading && !gameListModel.isEmpty
                            clip: true
                            model: gameListModel
                            spacing: 0
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: GameListCell {
                                width: listView.width
                                style: root.style
                                iconBase: root.iconBase

                                onSelectRequested: gameListModel.selectInstance(instanceId)
                                onOpenRequested: root.openInstance(instanceId)
                                onLaunchRequested: {
                                    gameListModel.selectInstance(instanceId)
                                    root.backend.startLaunchSelectedVersion("keep")
                                }
                                onUpdateRequested: root.openInstance(instanceId)
                                onManageRequested: function(x, y) {
                                    var pos = mapToItem(root, x, y)
                                    root.openMenu(instanceId, pos.x, pos.y)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // —— 右键上下文菜单 ——
    MouseArea {
        anchors.fill: parent
        visible: popupMenu.visible
        z: 900
        acceptedButtons: Qt.AllButtons
        onClicked: popupMenu.visible = false
    }

    GameListPopupMenu {
        id: popupMenu
        style: root.style
        visible: false
        z: 901
        instanceId: root.menuInstanceId

        onTestLaunchRequested: {
            popupMenu.visible = false
            gameListModel.selectInstance(root.menuInstanceId)
            root.backend.startLaunchSelectedVersion("keep")
        }
        onScriptRequested: {
            popupMenu.visible = false
            root.backend.generateInstanceLaunchCommand(root.menuInstanceId)
        }
        onManageRequested: {
            popupMenu.visible = false
            root.openInstance(root.menuInstanceId)
        }
        onRenameRequested: {
            popupMenu.visible = false
            renameDialog.open(root.menuInstanceId)
        }
        onDuplicateRequested: {
            popupMenu.visible = false
            duplicateDialog.open(root.menuInstanceId)
        }
        onDeleteRequested: {
            popupMenu.visible = false
            deleteDialog.open(root.menuInstanceId)
        }
        onSelectRequested: {
            popupMenu.visible = false
            gameListModel.selectInstance(root.menuInstanceId)
        }
        onFolderRequested: {
            popupMenu.visible = false
            gameListModel.openFolder(root.menuInstanceId)
        }
    }

    // —— 重命名对话框 ——
    InputDialog {
        id: renameDialog
        style: root.style
        title: "重命名实例"
        confirmText: "确定"
        onAccepted: function(id, value) {
            if (value.length > 0) {
                gameListModel.renameInstance(id, value)
            }
        }
    }

    // —— 复制对话框 ——
    InputDialog {
        id: duplicateDialog
        style: root.style
        title: "复制实例"
        confirmText: "复制"
        showCopySaves: true
        onAcceptedWithSaves: function(id, value, copySaves) {
            if (value.length > 0) {
                gameListModel.duplicateInstance(id, value, copySaves)
            }
        }
    }

    // —— 删除确认对话框 ——
    ConfirmDialog {
        id: deleteDialog
        style: root.style
        title: "删除实例"
        message: "确定要删除该实例吗？此操作不可撤销。"
        onConfirmed: function(id) {
            gameListModel.removeInstance(id)
        }
    }

    function openMenu(instanceId, x, y) {
        root.menuInstanceId = instanceId
        popupMenu.x = Math.max(8, Math.min(x - popupMenu.width, root.width - popupMenu.width - 8))
        popupMenu.y = Math.max(8, Math.min(y, root.height - popupMenu.height - 8))
        popupMenu.visible = true
    }

    // —— 内联输入对话框（重命名/复制） ——
    component InputDialog: Item {
        id: dlg
        required property var style
        property string title: ""
        property string confirmText: "确定"
        property bool showCopySaves: false
        property string targetId: ""

        signal accepted(string id, string value)
        signal acceptedWithSaves(string id, string value, bool copySaves)

        anchors.fill: parent
        visible: false
        z: 1000

        function open(id) {
            dlg.targetId = id
            input.text = id
            copySavesCheck.checked = true
            dlg.visible = true
            input.forceActiveFocus()
            input.selectAll()
        }

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            MouseArea { anchors.fill: parent; onClicked: dlg.visible = false }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: card.implicitHeight + 32
            radius: 4
            color: dlg.style.cSurfaceContainerHigh

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            ColumnLayout {
                id: card
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                Text {
                    text: dlg.title
                    color: dlg.style.cTextOnSurface
                    font.pixelSize: 15
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 3
                    color: dlg.style.cButtonSurface
                    border.width: 1
                    border.color: input.activeFocus ? dlg.style.cButtonSelected : dlg.style.cBorder

                    TextField {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        color: dlg.style.cTextOnSurface
                        selectByMouse: true
                        background: Item {}
                        Keys.onReturnPressed: confirmBtn.activate()
                        Keys.onEscapePressed: dlg.visible = false
                    }
                }

                RowLayout {
                    visible: dlg.showCopySaves
                    Layout.fillWidth: true
                    spacing: 8

                    CheckBox {
                        id: copySavesCheck
                        checked: true
                    }

                    Text {
                        text: "同时复制存档"
                        color: dlg.style.cTextOnSurface
                        font.pixelSize: 13
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        style: dlg.style
                        text: "取消"
                        onClicked: dlg.visible = false
                    }

                    DialogButton {
                        id: confirmBtn
                        style: dlg.style
                        text: dlg.confirmText
                        primary: true
                        function activate() {
                            if (dlg.showCopySaves) {
                                dlg.acceptedWithSaves(dlg.targetId, input.text, copySavesCheck.checked)
                            } else {
                                dlg.accepted(dlg.targetId, input.text)
                            }
                            dlg.visible = false
                        }
                        onClicked: activate()
                    }
                }
            }
        }
    }

    // —— 确认对话框（删除） ——
    component ConfirmDialog: Item {
        id: cdlg
        required property var style
        property string title: ""
        property string message: ""
        property string targetId: ""

        signal confirmed(string id)

        anchors.fill: parent
        visible: false
        z: 1000

        function open(id) {
            cdlg.targetId = id
            cdlg.visible = true
        }

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
            MouseArea { anchors.fill: parent; onClicked: cdlg.visible = false }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: ccard.implicitHeight + 32
            radius: 4
            color: cdlg.style.cSurfaceContainerHigh

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            ColumnLayout {
                id: ccard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                Text {
                    text: cdlg.title
                    color: cdlg.style.cTextOnSurface
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: cdlg.message
                    color: cdlg.style.cTextOnSurfaceVariant
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        style: cdlg.style
                        text: "取消"
                        onClicked: cdlg.visible = false
                    }

                    DialogButton {
                        style: cdlg.style
                        text: "删除"
                        primary: true
                        onClicked: {
                            cdlg.confirmed(cdlg.targetId)
                            cdlg.visible = false
                        }
                    }
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: btn
        required property var style
        property string text: ""
        property bool primary: false
        signal clicked()

        implicitWidth: Math.max(72, label.implicitWidth + 28)
        implicitHeight: 32
        radius: 2
        color: mouse.containsMouse
               ? btn.style.cButtonHover
               : (btn.primary ? btn.style.cButtonSurface : "transparent")
        border.width: btn.primary ? 0 : 1
        border.color: btn.style.cBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.style.cTextOnSurface
            font.pixelSize: 13
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
