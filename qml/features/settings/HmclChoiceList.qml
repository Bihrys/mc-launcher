import QtQuick

Column {
    id: root

    // HMCL RadioChoiceList：VBox + spacing 8；不是一排排带分割线的 options-list-item。
    property var style
    property var options: []
    property string value: ""
    signal selected(string value)

    width: parent ? parent.width : 800
    spacing: 8

    Repeater {
        model: root.options
        delegate: HmclRadioOptionLine {
            required property var modelData
            style: root.style
            title: String(modelData.text || "")
            subtitle: String(modelData.subtitle || "")
            rightText: String(modelData.rightText || "")
            checked: String(modelData.value) === root.value
            showTopBorder: false
            onClicked: root.selected(String(modelData.value))
        }
    }
}
