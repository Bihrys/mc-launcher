import QtQuick
import "../../../components"
Item {
        id: button

        required property var style
        property string text: ""
        property bool primary: false
        property bool buttonEnabled: true

        signal clicked()

        implicitHeight: 36
        height: 36
        opacity: button.buttonEnabled ? 1.0 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: button.primary
                   ? button.style.cPrimary
                   : (mouse.containsMouse ? button.style.cButtonHover : button.style.cButtonSurface)
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? button.style.cButtonSelectedText : button.style.cTextOnSurface
            font.pixelSize: 12
            font.bold: button.primary
            z: 2
        }

        HmclRipple {
            id: buttonRipple
            hoverColor: button.style.cTextOnSurface
            rippleColor: button.primary ? button.style.cButtonSelectedText : button.style.cPrimary
            hovered: mouse.containsMouse && button.buttonEnabled
            animationsEnabled: button.style.animationsEnabled
            z: 1
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.buttonEnabled
            cursorShape: button.buttonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: function(pointer) {
                buttonRipple.press(pointer.x, pointer.y)
            }
            onReleased: buttonRipple.release()
            onCanceled: buttonRipple.cancel()
            onClicked: button.clicked()
        }
    }
