import QtQuick

HmclSettingLine {
    id: root
    property var options: []
    property string value: ""
    signal selected(string value)

    Row {
        enabled: root.effectiveEnabled
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Repeater {
            model: root.options
            delegate: HmclRadioTextOption {
                style: root.style
                text: modelData.text
                checked: String(modelData.value) === root.value
                onClicked: root.selected(String(modelData.value))
            }
        }
    }
}
