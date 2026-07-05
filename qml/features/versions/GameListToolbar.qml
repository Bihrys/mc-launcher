import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls"

Item {
    id: root
    property var style
    property bool searchMode: false
    property string searchText: ""
    signal refreshRequested()
    signal searchTextEdited(string text)
    signal searchModeChangedByUser(bool searchMode)

    height: 48

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            visible: !root.searchMode
            Layout.fillWidth: true
            text: "实例列表"
            color: root.style.cTextOnSurface
            font.pixelSize: 16
            font.bold: true
        }

        TextField {
            visible: root.searchMode
            Layout.fillWidth: true
            text: root.searchText
            placeholderText: "搜索实例"
            selectByMouse: true
            onTextChanged: root.searchTextEdited(text)
            background: Item {}
        }

        ToolbarButton {
            style: root.style
            iconKind: root.searchMode ? "CLOSE" : "SEARCH"
            onClicked: root.searchModeChangedByUser(!root.searchMode)
        }

        ToolbarButton {
            visible: !root.searchMode
            style: root.style
            iconKind: "REFRESH"
            onClicked: root.refreshRequested()
        }
    }
}
