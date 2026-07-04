import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

HmclSettingLine {
    id: root
    property real fromValue: 0
    property real toValue: 100
    property real valueNumber: 0
    property string suffix: ""
    signal movedValue(real value)

    implicitHeight: 58

    RowLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(360, parent.width * 0.50)
        spacing: 10

        Slider {
            id: slider
            Layout.fillWidth: true
            enabled: root.enabledRow
            from: root.fromValue
            to: root.toValue
            value: root.valueNumber
            onMoved: root.movedValue(value)
        }

        Text {
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignRight
            text: String(Math.round(slider.value)) + root.suffix
            color: root.styleValue("cTextOnSurfaceVariant", "#454651")
            font.pixelSize: 12
        }
    }
}
