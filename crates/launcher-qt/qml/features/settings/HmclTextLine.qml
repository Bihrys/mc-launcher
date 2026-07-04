import QtQuick
import QtQuick.Controls

HmclSettingLine {
    id: root
    property string valueText: ""
    property string placeholderText: ""
    property bool password: false
    signal accepted(string value)

    TextField {
        id: input
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(400, parent.width * 0.50)
        height: 32
        enabled: root.enabledRow
        text: root.valueText
        placeholderText: root.placeholderText
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        selectByMouse: true
        color: root.styleValue("cTextOnSurface", "#1B1B21")
        font.pixelSize: 13
        background: Rectangle {
            color: "transparent"
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: input.activeFocus ? root.styleValue("cButtonSelected", "#4352A5") : root.styleValue("cTextOnSurfaceVariant", "#454651")
                opacity: input.activeFocus ? 1 : 0.55
            }
        }
        onAccepted: root.accepted(text)
        onEditingFinished: root.accepted(text)
    }
}
