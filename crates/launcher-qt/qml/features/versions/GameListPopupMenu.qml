import QtQuick
import "../../Hmcl/controls"

PopupMenu {
    id: root
    property var style
    property string instanceId: ""
    signal manageRequested()
    signal selectRequested()
    signal duplicateRequested()
    signal deleteRequested()
    signal folderRequested()

    Column {
        anchors.fill: parent
        IconedMenuItem { style: root.style; title: "管理"; iconKind: "SETTINGS"; onClicked: root.manageRequested() }
        IconedMenuItem { style: root.style; title: "设为当前实例"; iconKind: "CHECK"; onClicked: root.selectRequested() }
        IconedMenuItem { style: root.style; title: "复制"; iconKind: "CONTENT_COPY"; onClicked: root.duplicateRequested() }
        IconedMenuItem { style: root.style; title: "文件夹"; iconKind: "FOLDER_OPEN"; onClicked: root.folderRequested() }
        IconedMenuItem { style: root.style; title: "删除"; iconKind: "DELETE"; onClicked: root.deleteRequested() }
    }
}
