import QtQuick
import QtQuick.Controls

HmclSettingLine {
    id: root
    property var options: []
    property string value: ""
    signal selected(string value)

    ComboBox {
        id: combo
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(260, parent.width * 0.48)
        height: 32
        enabled: root.enabledRow
        model: root.options
        textRole: "text"
        valueRole: "value"
        currentIndex: {
            for (var i = 0; i < root.options.length; ++i) {
                if (String(root.options[i].value) === root.value)
                    return i
            }
            return root.options.length > 0 ? 0 : -1
        }
        onActivated: function(index) {
            if (index >= 0 && index < root.options.length)
                root.selected(String(root.options[index].value))
        }
    }
}
