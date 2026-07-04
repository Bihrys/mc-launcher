import QtQuick
import QtQuick.Controls

HmclSettingLine {
    id: root
    property bool checkedValue: false
    signal changedValue(bool value)

    Switch {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.enabledRow
        checked: root.checkedValue
        onToggled: root.changedValue(checked)
    }
}
