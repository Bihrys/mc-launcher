import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../components"

// HMCL MicrosoftAccountLoginPane equivalent. It keeps the HMCL 650 px maximum
// width, 24/16 px dialog insets, 20 px heading and 200 ms state transitions.
Item {
    id: root

    required property var style
    required property var backend

    property var configuration: ({})
    property var task: ({ "active": false, "state": "idle" })
    property string stateName: "init"
    property string errorText: ""
    property string authorizationUrl: ""
    property string verificationUri: ""
    property string scanUri: ""
    property string userCode: ""
    property string qrCodeSource: ""
    property string loginFlow: "device" // device | browser
    property int beginGeneration: 0
    property bool bodyOnly: false

    signal completed()
    signal canceled()

    function begin() {
        beginGeneration += 1
        var generation = beginGeneration
        backend.cancelMicrosoftLogin()
        taskPoller.stop()
        task = ({ "active": false, "state": "idle" })
        errorText = ""
        authorizationUrl = ""
        verificationUri = ""
        scanUri = ""
        userCode = ""
        qrCodeSource = ""
        loginFlow = "device"
        try {
            configuration = JSON.parse(backend.microsoftClientConfiguration())
        } catch (e) {
            configuration = ({ "configured": false })
        }

        if (!configuration.configured) {
            stateName = "missingConfiguration"
            stateChange.restart()
            return
        }

        // HMCL device-code path: clicking Microsoft immediately requests a code,
        // opens the system browser, and waits for the user to enter that code.
        stateName = "requestingDeviceCode"
        stateChange.restart()
        Qt.callLater(function() {
            if (generation !== root.beginGeneration
                    || !root.visible
                    || root.stateName !== "requestingDeviceCode")
                return
            root.startDevice()
        })
    }

    function startBrowser() {
        loginFlow = "browser"
        errorText = ""
        stateName = "startingBrowser"
        backend.loginMicrosoftBrowser()
        taskPoller.restart()
        stateChange.restart()
    }

    function startDevice() {
        loginFlow = "device"
        errorText = ""
        stateName = "requestingDeviceCode"
        backend.loginMicrosoftDeviceCode()
        taskPoller.restart()
        stateChange.restart()
    }

    function cancelLogin() {
        beginGeneration += 1
        backend.cancelMicrosoftLogin()
        taskPoller.stop()
        task = ({ "active": false, "state": "cancelled" })
        authorizationUrl = ""
        verificationUri = ""
        scanUri = ""
        userCode = ""
        qrCodeSource = ""
        stateName = "cancelled"
        canceled()
    }

    function pollTask() {
        var raw = backend.pollMicrosoftLoginTask()
        if (!raw || raw.length === 0)
            return
        try {
            var next = JSON.parse(raw)
            task = next
            authorizationUrl = next.authorizationUrl || authorizationUrl
            verificationUri = next.verificationUri || verificationUri
            scanUri = next.scanUri || scanUri
            userCode = next.userCode || userCode
            if (next.scanUri && next.scanUri.length > 0)
                qrCodeSource = backend.qrCodeDataUrl(next.scanUri)
            stateName = next.state || stateName
            if (stateName === "failed" || stateName === "missingConfiguration") {
                errorText = next.message || "Microsoft 登录失败。"
                taskPoller.stop()
            } else if (stateName === "completed" && next.success) {
                taskPoller.stop()
                completed()
            } else if (!next.active && stateName === "cancelled") {
                taskPoller.stop()
            }
            stateChange.restart()
        } catch (e) {
            taskPoller.stop()
            stateName = "failed"
            errorText = "Microsoft 登录状态解析失败。"
            stateChange.restart()
        }
    }

    function openCurrentUrl() {
        // The QR code may contain the prefilled OTC URL, while the browser button
        // follows HMCL and opens the verification page where the user enters the code.
        var target = stateName === "waitForDevice" ? verificationUri : authorizationUrl
        if (target && target.length > 0)
            backend.openUrl(target)
    }

    function copyCode() {
        codeClipboard.text = userCode
        codeClipboard.selectAll()
        codeClipboard.copy()
        codeClipboard.deselect()
    }

    Timer {
        id: taskPoller
        interval: 100
        repeat: true
        onTriggered: root.pollTask()
    }

    SequentialAnimation {
        id: stateChange
        running: false
        NumberAnimation {
            target: bodyContent
            property: "opacity"
            from: 0.45
            to: 1
            duration: root.style.animationsEnabled ? root.style.motionShort4 : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
        }
    }

    TextEdit {
        id: codeClipboard
        visible: false
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        opacity: root.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0 }
        }
    }

    MouseArea { anchors.fill: parent }

    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: Math.min(root.width - 64, 650)
        height: Math.min(root.height - 48,
                         root.stateName === "waitForDevice" ? 450
                         : root.stateName === "missingConfiguration" ? 420
                         : 340)
        radius: 4
        color: root.style.cSurfaceContainerHigh
        border.color: root.style.cBorder
        border.width: 1
        scale: root.visible ? 1 : 0.97
        opacity: root.visible ? 1 : 0
        clip: true

        Behavior on width {
            NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.InOutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.InOutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 24
            anchors.bottomMargin: 16
            spacing: 10

            Text {
                visible: !root.bodyOnly
                Layout.fillWidth: true
                text: "添加 Microsoft 账户"
                color: root.style.cTextOnSurface
                font.pixelSize: 20
                font.bold: true
                elide: Text.ElideRight
            }

            Item {
                id: bodyContent
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    HintPane {
                        visible: root.stateName === "init"
                        style: root.style
                        kind: "info"
                        text: "使用 Microsoft 账户登录正版 Minecraft。授权过程在系统浏览器中完成，启动器不会读取或保存 Microsoft 密码。"
                    }

                    HintPane {
                        visible: root.stateName === "missingConfiguration"
                        style: root.style
                        kind: "warning"
                        text: "当前构建未配置 Microsoft Public Client ID，因此正版登录不可用。请先在 Microsoft Entra 注册桌面公共客户端，并把 Application (client) ID 写入下方配置文件。设备代码登录不需要 Client Secret。"
                    }

                    ColumnLayout {
                        visible: root.stateName === "missingConfiguration"
                        Layout.fillWidth: true
                        spacing: 8

                        LabelValue { style: root.style; label: "配置文件"; value: root.configuration.configPath || "~/.config/mc-launcher-qt-cpp/microsoft-oauth.json" }
                        LabelValue { style: root.style; label: "配置键"; value: "clientId" }
                        LabelValue { style: root.style; label: "账户类型"; value: "仅个人 Microsoft 账户" }
                        LabelValue { style: root.style; label: "公共客户端"; value: "Allow public client flows = Yes" }
                        Text {
                            Layout.fillWidth: true
                            text: "浏览器授权备用回调：\n" + ((root.configuration.redirectUris || []).join("\n"))
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    BusyBody {
                        visible: root.stateName === "startingBrowser"
                                 || root.stateName === "requestingDeviceCode"
                                 || root.stateName === "authenticating"
                        style: root.style
                        title: root.stateName === "authenticating" ? "正在验证正版账户" : "正在准备 Microsoft 登录"
                        message: root.task.message || "正在连接 Microsoft 服务…"
                    }

                    HintPane {
                        visible: root.stateName === "waitForBrowser"
                        style: root.style
                        kind: "info"
                        text: root.task.message || "请在浏览器中完成 Microsoft 授权。浏览器未自动打开时，可以点击下方按钮重新打开。"
                    }

                    ColumnLayout {
                        visible: root.stateName === "waitForDevice"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        HintPane {
                            Layout.fillWidth: true
                            style: root.style
                            kind: "info"
                            text: "浏览器已打开。请在 Microsoft 页面输入下方代码，再使用拥有 Minecraft Java 版的 Microsoft 账户完成登录。启动器不会读取或保存账户密码。"
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18

                            Rectangle {
                                visible: root.qrCodeSource.length > 0
                                Layout.preferredWidth: 154
                                Layout.preferredHeight: 154
                                radius: 4
                                color: "white"
                                border.color: root.style.cBorder
                                border.width: 1

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    source: root.qrCodeSource
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    smooth: false
                                }
                            }

                            ColumnLayout {
                                spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Math.max(220, codeLabel.implicitWidth + 40)
                            Layout.preferredHeight: 58
                            radius: 6
                            color: root.style.cSurfaceContainer
                            border.color: codeMouse.containsMouse ? root.style.cButtonSelected : root.style.cBorder
                            border.width: 1

                            Text {
                                id: codeLabel
                                anchors.centerIn: parent
                                text: root.userCode
                                color: root.style.cButtonSelected
                                font.pixelSize: 22
                                font.bold: true
                                font.family: "monospace"
                                font.letterSpacing: 1.5
                            }
                            MouseArea {
                                id: codeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyCode()
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "点击代码可复制"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 10
                        }

                                Text {
                                    visible: root.qrCodeSource.length === 0
                                    Layout.preferredWidth: 260
                                    text: "当前系统未安装 libqrencode，仍可使用上方设备代码完成登录。"
                                    color: root.style.cTextOnSurfaceVariant
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    HintPane {
                        visible: root.stateName === "failed"
                        style: root.style
                        kind: "error"
                        text: root.errorText.length > 0 ? root.errorText : "Microsoft 登录失败。"
                    }

                    Item { Layout.fillHeight: true }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 16

                        LinkLabel {
                            style: root.style
                            text: root.loginFlow === "device" ? "改用浏览器授权" : "改用设备代码"
                            visible: root.configuration.configured
                                     && root.stateName !== "missingConfiguration"
                                     && root.stateName !== "authenticating"
                            onClicked: {
                                if (root.loginFlow === "device") root.startBrowser()
                                else root.startDevice()
                            }
                        }
                        LinkLabel {
                            style: root.style
                            text: "编辑 Microsoft 个人资料"
                            onClicked: root.backend.openUrl("https://account.live.com/editprof.aspx")
                        }
                        LinkLabel {
                            style: root.style
                            text: "购买 Minecraft"
                            onClicked: root.backend.openUrl("https://www.minecraft.net/store/minecraft-java-bedrock-edition-pc")
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 0
                spacing: 8

                Item { Layout.fillWidth: true }

                PaneButton {
                    style: root.style
                    text: root.stateName === "waitForBrowser" || root.stateName === "waitForDevice"
                          ? "打开浏览器" : "重试"
                    primary: true
                    visible: root.stateName === "waitForBrowser"
                             || root.stateName === "waitForDevice"
                             || root.stateName === "failed"
                    enabled: root.configuration.configured
                    onClicked: {
                        if (root.stateName === "waitForBrowser" || root.stateName === "waitForDevice") {
                            root.openCurrentUrl()
                        } else if (root.loginFlow === "device") {
                            root.startDevice()
                        } else {
                            root.startBrowser()
                        }
                    }
                }

                PaneButton {
                    style: root.style
                    text: "取消"
                    onClicked: root.cancelLogin()
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 3
            visible: root.task.active
            color: root.style.cButtonSelected

            Rectangle {
                width: Math.max(36, parent.width * Math.max(0.08, (root.task.percent || 10) / 100))
                height: parent.height
                color: root.style.cButtonSelected
                opacity: 0.72
                Behavior on width {
                    NumberAnimation { duration: root.style.animationsEnabled ? root.style.motionShort4 : 0 }
                }
            }
        }
    }

    component HintPane: Rectangle {
        id: hint
        required property var style
        property string kind: "info"
        property string text: ""
        implicitHeight: hintText.implicitHeight + 20
        radius: 4
        color: style.cSurfaceContainer
        border.width: 1
        border.color: kind === "error" ? "#b3261e"
                      : kind === "warning" ? "#b26a00"
                      : style.cBorder
        Text {
            id: hintText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            text: hint.text
            color: hint.kind === "error" ? "#b3261e"
                   : hint.kind === "warning" ? "#8a5100"
                   : hint.style.cTextOnSurfaceVariant
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    component BusyBody: ColumnLayout {
        required property var style
        property string title: ""
        property string message: ""
        spacing: 12
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            BusyIndicator { anchors.fill: parent; running: true }
        }
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: parent.style.cTextOnSurface
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: parent.message
            color: parent.style.cTextOnSurfaceVariant
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    component LabelValue: RowLayout {
        id: labelValue
        required property var style
        property string label: ""
        property string value: ""
        spacing: 15
        Text {
            Layout.preferredWidth: 100
            text: labelValue.label
            color: labelValue.style.cTextOnSurfaceVariant
            font.pixelSize: 12
        }
        Text {
            Layout.fillWidth: true
            text: labelValue.value
            color: labelValue.style.cTextOnSurface
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere
        }
    }

    component LinkLabel: Text {
        id: link
        required property var style
        signal clicked()
        color: style.cButtonSelected
        font.pixelSize: 12
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
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
        color: primary ? style.cButtonSelected
                       : (mouse.containsMouse ? style.cNavHover : "transparent")
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
