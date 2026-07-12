import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Qt Quick port of HMCL ClassicAccountLoginDialog.
Item {
    id: root
    required property var style
    property string username: ""
    property string password: ""
    property string errorText: ""
    property bool busy: false
    signal accepted(string password)
    signal canceled()

    function begin(name) {
        username = name
        password = ""
        errorText = ""
        busy = false
        passwordField.forceActiveFocus()
    }

    Rectangle { anchors.fill: parent; color: "#80000000" }
    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(root.width - 64, 500)
        height: 230
        radius: 4
        color: root.style.cSurface
        border.color: root.style.cBorder
        border.width: 1

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 3; visible: root.busy; color: root.style.cButtonSelected }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 17
            spacing: 15
            Text { Layout.fillWidth: true; text: "请输入密码"; color: root.style.cTextOnSurface; font.pixelSize: 18; font.bold: true }
            Text { Layout.fillWidth: true; text: root.username; color: root.style.cTextOnSurface; font.pixelSize: 13; elide: Text.ElideRight }
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "密码"
                echoMode: TextInput.Password
                passwordCharacter: "●"
                text: root.password
                enabled: !root.busy
                onTextEdited: root.password = text
                onAccepted: if (root.password.length > 0) root.accepted(root.password)
            }
            Text { visible: root.errorText.length > 0; Layout.fillWidth: true; text: root.errorText; color: "#d32f2f"; font.pixelSize: 11; wrapMode: Text.WordWrap }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button { text: "确定"; enabled: !root.busy && root.password.length > 0; onClicked: root.accepted(root.password) }
                Button { text: "取消"; enabled: !root.busy; onClicked: root.canceled() }
            }
        }
    }
}
