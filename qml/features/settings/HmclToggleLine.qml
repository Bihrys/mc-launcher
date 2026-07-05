import QtQuick

HmclSettingLine {
    id: root
    property bool checkedValue: false
    clickable: true
    signal changedValue(bool value)

    onClicked: root.changedValue(!root.checkedValue)

    HmclSwitch {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        style: root.style
        checked: root.checkedValue
        enabledControl: root.enabledRow
        interactive: false
    }
}
