import QtQuick

HmclSettingLine {
    id: root
    property string firstText: "执行"
    property string secondText: "执行"
    signal first()
    signal second()

    Row {
        enabled: root.effectiveEnabled
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        HmclTextButton { style: root.style; text: root.firstText; onClicked: root.first() }
        HmclTextButton { style: root.style; text: root.secondText; onClicked: root.second() }
    }
}
