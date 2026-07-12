import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../components"

// Qt Quick port of HMCL AddAuthlibInjectorServerPane.
Item {
    id: root

    required property var style
    required property var backend

    property int step: 0
    property string enteredUrl: ""
    property string serverUrl: ""
    property string serverName: ""
    property string errorText: ""
    property bool httpWarning: false
    property bool busy: false

    signal completed(string name, string url)
    signal canceled()

    function begin() {
        step = 0
        enteredUrl = ""
        serverUrl = ""
        serverName = ""
        errorText = ""
        httpWarning = false
        busy = false
        urlField.forceActiveFocus()
    }

    function next() {
        if (busy || enteredUrl.trim().length === 0)
            return
        errorText = ""
        busy = true
        backend.startProbeAuthServer(enteredUrl.trim())
        probePoller.restart()
    }

    function pollProbe() {
        var raw = backend.pollAuthServerProbeTask()
        if (!raw || raw.length === 0)
            return
        try {
            var status = JSON.parse(raw)
            busy = !!status.active
            if (status.active)
                return
            probePoller.stop()
            if (!status.success) {
                errorText = status.message || "无法连接认证服务器。"
                return
            }
            serverUrl = status.url || enteredUrl.trim()
            serverName = status.name || status.host || serverUrl
            httpWarning = !!status.httpWarning
            step = 1
        } catch (e) {
            busy = false
            probePoller.stop()
            errorText = "认证服务器信息解析失败。"
        }
    }

    Timer {
        id: probePoller
        interval: 100
        repeat: true
        onTriggered: root.pollProbe()
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    MouseArea { anchors.fill: parent }

    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: Math.min(root.width - 64, 560)
        height: step === 0 ? 214 : 252
        radius: 4
        color: root.style.cSurface
        border.color: root.style.cBorder
        border.width: 1
        scale: root.visible ? 1 : 0.97
        opacity: root.visible ? 1 : 0

        Behavior on scale { NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 17
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: "添加认证服务器"
                color: root.style.cTextOnSurface
                font.pixelSize: 18
                font.bold: true
            }

            Item {
                id: transitionBody
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: transitionBody.width
                    height: transitionBody.height
                    y: 0
                    spacing: 8
                    enabled: root.step === 0
                    visible: opacity > 0.001
                    opacity: root.step === 0 ? 1 : 0
                    x: root.step === 0 ? 0 : -transitionBody.width * 0.2

                    Behavior on opacity { NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.InOutCubic } }
                    Behavior on x { NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.InOutCubic } }

                    TextField {
                        id: urlField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        placeholderText: "服务器 API 根地址"
                        text: root.enteredUrl
                        selectByMouse: true
                        enabled: !root.busy
                        onTextEdited: root.enteredUrl = text
                        onAccepted: root.next()
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.errorText.length > 0
                        text: root.errorText
                        color: "#d32f2f"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }
                }

                GridLayout {
                    width: transitionBody.width
                    height: transitionBody.height
                    y: 0
                    columns: 2
                    columnSpacing: 15
                    rowSpacing: 15
                    enabled: root.step === 1
                    visible: opacity > 0.001
                    opacity: root.step === 1 ? 1 : 0
                    x: root.step === 1 ? 0 : transitionBody.width * 0.2

                    Behavior on opacity { NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.InOutCubic } }
                    Behavior on x { NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.InOutCubic } }

                    Text {
                        Layout.preferredWidth: 100
                        text: "服务器地址"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.serverUrl
                        color: root.style.cTextOnSurface
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                    }

                    Text {
                        Layout.preferredWidth: 100
                        text: "服务器名称"
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.serverName
                        color: root.style.cTextOnSurface
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        visible: root.httpWarning
                        text: "此认证服务器使用 HTTP，登录凭据可能被窃听。"
                        color: "#d32f2f"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.columnSpan: 2; Layout.fillHeight: true }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PaneButton {
                    visible: root.step === 1
                    style: root.style
                    text: "上一步"
                    onClicked: {
                        root.step = 0
                        root.errorText = ""
                        urlField.forceActiveFocus()
                    }
                }

                Item { Layout.fillWidth: true }

                PaneButton {
                    style: root.style
                    text: "取消"
                    onClicked: root.canceled()
                }

                PaneButton {
                    style: root.style
                    primary: true
                    text: root.step === 0 ? (root.busy ? "正在连接" : "下一步") : "完成"
                    enabled: !root.busy && (root.step === 1 || root.enteredUrl.trim().length > 0)
                    onClicked: {
                        if (root.step === 0)
                            root.next()
                        else
                            root.completed(root.serverName, root.serverUrl)
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 3
            visible: root.busy
            color: root.style.cButtonSelected

        }
    }

    component PaneButton: Rectangle {
        id: button
        required property var style
        property string text: ""
        property bool primary: false
        signal clicked()
        implicitWidth: Math.max(72, label.implicitWidth + 24)
        implicitHeight: 34
        radius: 3
        color: primary ? style.cButtonSelected : (mouse.containsMouse ? style.cNavHover : "transparent")
        opacity: enabled ? 1 : 0.45

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? "white" : button.style.cTextOnSurface
            font.pixelSize: 12
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }
}
