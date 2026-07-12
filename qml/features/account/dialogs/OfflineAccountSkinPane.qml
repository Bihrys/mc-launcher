import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../../../components"

// Qt Quick port of HMCL OfflineAccountSkinPane dimensions and interaction.
Item {
    id: root

    required property var style
    required property var backend

    property int accountIndex: -1
    property string username: ""
    property string uuid: ""
    property string currentAvatarUrl: ""
    property string skinType: "default"
    property string localSkinUrl: ""
    property string localCapeUrl: ""
    property string textureModel: "wide"
    property string cslApi: ""

    signal accepted(int index, string fileUrl, string capeFileUrl, string model, string cslApi, string skinType)
    signal canceled()

    function begin(index, name, uuidValue, avatarUrl, currentType, currentModel, skinPath, capePath, currentCslApi) {
        accountIndex = index
        username = name
        uuid = uuidValue
        currentAvatarUrl = avatarUrl
        skinType = currentType || "default"
        localSkinUrl = skinPath && skinPath.length > 0 ? "file://" + skinPath : ""
        localCapeUrl = capePath && capePath.length > 0 ? "file://" + capePath : ""
        textureModel = currentModel === "slim" ? "slim" : "wide"
        cslApi = currentCslApi || ""
        var values = ["default", "steve", "alex", "local", "littleskin", "csl"]
        var found = values.indexOf(skinType)
        skinTypeList.currentIndex = found >= 0 ? found : 0
    }

    FileDialog {
        id: skinDialog
        title: "选择皮肤文件"
        nameFilters: ["Minecraft skin (*.png)", "PNG images (*.png)"]
        onAccepted: {
            root.localSkinUrl = String(selectedFile)
            root.skinType = "local"
            skinTypeList.currentIndex = 3
        }
    }

    FileDialog {
        id: capeDialog
        title: "选择披风文件"
        nameFilters: ["Minecraft cape (*.png)", "PNG images (*.png)"]
        onAccepted: root.localCapeUrl = String(selectedFile)
    }

    Rectangle { anchors.fill: parent; color: "#80000000" }
    MouseArea { anchors.fill: parent }

    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: Math.min(root.width - 48, 740)
        height: Math.min(root.height - 48, 390)
        radius: 4
        color: root.style.cSurface
        border.color: root.style.cBorder
        border.width: 1
        scale: root.visible ? 1 : 0.97
        opacity: root.visible ? 1 : 0
        Behavior on scale {
            NumberAnimation {
                duration: root.style.animationsEnabled ? root.style.motionShort4 : 0
                easing.type: Easing.OutCubic
            }
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
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "皮肤"
                color: root.style.cTextOnSurface
                font.pixelSize: 20
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20

                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 260
                    Layout.alignment: Qt.AlignTop
                    color: root.style.cSurfaceContainer
                    border.color: root.style.cBorder
                    border.width: 1
                    radius: 4
                    clip: true

                    Image {
                        id: bigPreview
                        anchors.centerIn: parent
                        width: 224
                        height: 224
                        source: root.localSkinUrl.length > 0 ? root.localSkinUrl : root.currentAvatarUrl
                        fillMode: root.localSkinUrl.length > 0 ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                        smooth: false
                        mipmap: false
                        cache: false
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: root.username
                        color: root.style.cTextOnSurfaceVariant
                        font.pixelSize: 11
                    }
                }

                ListView {
                    id: skinTypeList
                    Layout.preferredWidth: 170
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: [
                        { "title": "默认", "value": "default" },
                        { "title": "Steve", "value": "steve" },
                        { "title": "Alex", "value": "alex" },
                        { "title": "本地文件", "value": "local" },
                        { "title": "LittleSkin", "value": "littleskin" },
                        { "title": "CustomSkinLoader API", "value": "csl" }
                    ]

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: skinTypeList.width
                        height: 42
                        radius: 3
                        color: root.skinType === modelData.value
                               ? root.style.cNavSelected
                               : (typeMouse.containsMouse ? root.style.cNavHover : "transparent")

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title
                            color: root.style.cTextOnSurface
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: typeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.skinType = modelData.value
                                skinTypeList.currentIndex = index
                                if (modelData.value === "local" && root.localSkinUrl.length === 0)
                                    skinDialog.open()
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 230
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 12
                    visible: root.skinType === "local" || root.skinType === "littleskin" || root.skinType === "csl"

                    Rectangle {
                        visible: root.skinType === "littleskin"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 78
                        radius: 4
                        color: root.style.cSurfaceContainer
                        border.color: root.style.cBorder
                        border.width: 1
                        Text {
                            anchors.fill: parent
                            anchors.margins: 10
                            text: "LittleSkin 可根据玩家名读取皮肤。点击左下角链接可以打开 LittleSkin。"
                            color: root.style.cTextOnSurfaceVariant
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    Text {
                        visible: root.skinType === "local"
                        text: "皮肤模型"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 12
                    }
                    ComboBox {
                        visible: root.skinType === "local"
                        Layout.fillWidth: true
                        model: ["宽臂（Steve）", "细臂（Alex）"]
                        currentIndex: root.textureModel === "slim" ? 1 : 0
                        onActivated: root.textureModel = currentIndex === 1 ? "slim" : "wide"
                    }

                    Text {
                        visible: root.skinType === "local"
                        text: "皮肤"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 12
                    }
                    RowLayout {
                        visible: root.skinType === "local"
                        Layout.fillWidth: true
                        TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.localSkinUrl
                            placeholderText: "选择 PNG 文件"
                        }
                        PaneButton { style: root.style; text: "浏览"; onClicked: skinDialog.open() }
                    }

                    Text {
                        visible: root.skinType === "local"
                        text: "披风"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 12
                    }
                    RowLayout {
                        visible: root.skinType === "local"
                        Layout.fillWidth: true
                        TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            text: root.localCapeUrl
                            placeholderText: "可选"
                        }
                        PaneButton { style: root.style; text: "浏览"; onClicked: capeDialog.open() }
                    }

                    Text {
                        visible: root.skinType === "csl"
                        text: "CustomSkinLoader API 地址"
                        color: root.style.cTextOnSurface
                        font.pixelSize: 12
                    }
                    TextField {
                        visible: root.skinType === "csl"
                        Layout.fillWidth: true
                        placeholderText: "https://example.com/skin/{username}.json"
                        text: root.cslApi
                        onTextEdited: root.cslApi = text
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "LittleSkin"
                    color: root.style.cButtonSelected
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backend.openUrl("https://littleskin.cn/")
                    }
                }

                Item { Layout.fillWidth: true }

                PaneButton {
                    style: root.style
                    text: "确定"
                    primary: true
                    enabled: root.skinType !== "local" || root.localSkinUrl.length > 0
                    onClicked: root.accepted(root.accountIndex,
                                             root.skinType === "local" ? root.localSkinUrl : "",
                                             root.skinType === "local" ? root.localCapeUrl : "",
                                             root.textureModel,
                                             root.skinType === "csl" ? root.cslApi : "",
                                             root.skinType)
                }
                PaneButton { style: root.style; text: "取消"; onClicked: root.canceled() }
            }
        }
    }

    component PaneButton: Rectangle {
        id: button
        required property var style
        property string text: ""
        property bool primary: false
        signal clicked()
        implicitWidth: Math.max(68, label.implicitWidth + 22)
        implicitHeight: 34
        radius: 3
        color: primary ? style.cButtonSelected : (mouse.containsMouse ? style.cNavHover : "transparent")
        opacity: enabled ? 1 : 0.45
        Text { id: label; anchors.centerIn: parent; text: button.text; color: button.primary ? "white" : button.style.cTextOnSurface; font.pixelSize: 12 }
        MouseArea { id: mouse; anchors.fill: parent; enabled: button.enabled; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: button.clicked() }
    }
}
