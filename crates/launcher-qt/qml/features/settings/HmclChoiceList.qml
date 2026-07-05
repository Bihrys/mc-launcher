import QtQuick

Column {
    id: root

    property var style
    property var options: []
    property string value: ""
    signal selected(string value)

    width: parent ? parent.width : 800
    spacing: 0

    Repeater {
        model: root.options
        delegate: HmclRadioOptionLine {
            required property var modelData
            required property int index
            style: root.style
            title: String(modelData.text || "")
            subtitle: String(modelData.subtitle || "")
            rightText: String(modelData.rightText || "")
            checked: String(modelData.value) === root.value
            showTopBorder: index > 0
            onClicked: root.selected(String(modelData.value))
        }
    }
}
