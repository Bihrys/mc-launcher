import QtQuick

HmclSettingLine {
    id: root
    property string valueText: ""

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(420, parent.width * 0.52)
        horizontalAlignment: Text.AlignRight
        text: root.valueText.length > 0 ? root.valueText : root.subtitle
        color: root.styleValue("cTextOnSurfaceVariant", "#454651")
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
