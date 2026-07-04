import QtQuick

HmclSettingLine {
    id: root
    property bool checkedValue: false
    signal changedValue(bool value)

    HmclSwitch {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        style: root.style
        checked: root.checkedValue
        enabledControl: root.enabledRow
        onToggled: function(value) { root.changedValue(value) }
    }
}
