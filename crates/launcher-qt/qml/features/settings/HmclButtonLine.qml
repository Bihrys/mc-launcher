import QtQuick

HmclSettingLine {
    id: root
    property string buttonText: "执行"
    signal action()

    HmclTextButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        style: root.style
        text: root.buttonText
        enabledButton: root.enabledRow
        onClicked: root.action()
    }
}
