import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls"

// HMCL GameListSkin toolbar: normal/search panes switch with a fade transition.
Item {
    id: root

    property var style
    property bool searchMode: false
    property string searchText: ""

    signal refreshRequested()
    signal searchTextEdited(string text)
    signal searchModeChangedByUser(bool searchMode)

    implicitHeight: 48
    height: 48
    clip: true

    RowLayout {
        id: normalPane
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8
        visible: opacity > 0
        opacity: root.searchMode ? 0 : 1
        enabled: !root.searchMode

        Behavior on opacity {
            NumberAnimation {
                duration: root.style && root.style.animationsEnabled ? 160 : 0
                easing.type: Easing.InOutCubic
            }
        }

        Text {
            Layout.fillWidth: true
            text: "实例列表"
            color: root.style ? root.style.cTextOnSurface : "#222222"
            font.pixelSize: 16
            font.bold: true
        }

        ToolbarButton {
            style: root.style
            iconKind: "REFRESH"
            onClicked: root.refreshRequested()
        }

        ToolbarButton {
            style: root.style
            iconKind: "SEARCH"
            onClicked: root.searchModeChangedByUser(true)
        }
    }

    RowLayout {
        id: searchPane
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 12
        spacing: 8
        visible: opacity > 0
        opacity: root.searchMode ? 1 : 0
        enabled: root.searchMode

        Behavior on opacity {
            NumberAnimation {
                duration: root.style && root.style.animationsEnabled ? 160 : 0
                easing.type: Easing.InOutCubic
            }
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            text: root.searchText
            placeholderText: "搜索"
            selectByMouse: true
            color: root.style ? root.style.cTextOnSurface : "#222222"
            background: Item {}
            onTextChanged: root.searchTextEdited(text)
            Keys.onEscapePressed: root.searchModeChangedByUser(false)
        }

        ToolbarButton {
            style: root.style
            iconKind: "CLOSE"
            onClicked: root.searchModeChangedByUser(false)
        }
    }

    onSearchModeChanged: {
        if (searchMode) {
            searchField.forceActiveFocus()
        } else {
            searchField.text = ""
        }
    }
}
