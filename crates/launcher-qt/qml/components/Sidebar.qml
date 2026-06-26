import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    required property var style
    required property var backend

    property string currentPage: "main"
    property bool sidebarHovered: false
    readonly property string iconBase: "qrc:/qt/qml/com/bihrys/launcher/qml/assets/img/"

    signal navigate(string page)
    signal navigateSettingsSection(string section)
    signal prepareAccount
    signal prepareSettings
    signal prepareDownload
    signal prepareVersion

    width: 200
    color: "transparent"

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: root.sidebarHovered ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: root.sidebarHovered = true
            onExited: root.sidebarHovered = false
        }

        Column {
            width: root.width
            spacing: 0

            Item {
                width: 1
                height: 12
            }

            HmclClassTitle {
                style: root.style
                title: "账户"
            }

            HmclAccountItem {
                style: root.style
                accountName: root.backend.currentAccountName.length > 0 ? root.backend.currentAccountName : "未登录"
                accountType: root.backend.currentAccountKind.length > 0 ? root.backend.currentAccountKind : "添加账户"
                avatarUrl: root.backend.currentAccountAvatarUrl
                active: root.currentPage === "account"
                onEntered: root.prepareAccount()
                onClicked: root.navigate("account")
            }

            HmclClassTitle {
                style: root.style
                title: "游戏"
            }

            HmclListItem {
                style: root.style
                title: root.backend.selectedGameVersion.length > 0 ? "实例管理" : "未安装游戏"
                subtitle: root.backend.selectedGameVersion.length > 0 ? root.backend.selectedGameVersion : "安装新游戏"
                imageSource: root.selectedVersionIconSource()
                active: root.currentPage === "main"
                onEntered: root.prepareVersion()
                onClicked: root.navigate("versions")
            }

            HmclListItem {
                style: root.style
                title: "实例列表"
                iconKind: "FORMAT_LIST_BULLETED"
                active: root.currentPage === "versions"
                onEntered: root.prepareVersion()
                onClicked: root.navigate("versions")
            }

            HmclListItem {
                style: root.style
                title: "下载"
                iconKind: "DOWNLOAD"
                active: root.currentPage === "download"
                onEntered: root.prepareDownload()
                onClicked: root.navigate("download")
            }

            HmclClassTitle {
                style: root.style
                title: "通用"
            }

            HmclListItem {
                style: root.style
                title: "设置"
                iconKind: "SETTINGS"
                active: root.currentPage === "settings"
                onEntered: root.prepareSettings()
                onClicked: {
                    root.prepareSettings();
                    root.navigateSettingsSection("global");
                }
            }

            HmclListItem {
                style: root.style
                title: "Terracotta"
                imageSource: root.iconBase + "terracotta.png"
                active: root.currentPage === "terracotta"
                onClicked: root.navigate("terracotta")
            }

            HmclListItem {
                style: root.style
                title: "聊天"
                iconKind: "CHAT"
                active: root.currentPage === "feedback"
                onEntered: root.prepareSettings()
                onClicked: {
                    root.prepareSettings();
                    root.navigateSettingsSection("feedback");
                }
            }
        }
    }

    function selectedVersionIconSource() {
        var fallback = root.iconBase + "grass.png";
        var selected = root.backend.selectedGameVersion;

        if (!selected || selected.length === 0) {
            return fallback;
        }

        try {
            var payload = JSON.parse(root.backend.installedVersionsJson || "{}");
            var versions = payload.versions || [];

            for (var i = 0; i < versions.length; i++) {
                var version = versions[i];
                if (version.id === selected || version.selected === true) {
                    return root.iconBase + String(version.iconName || "grass") + ".png";
                }
            }
        } catch (e) {}

        return fallback;
    }

    component HmclClassTitle: Item {
        id: titleItem

        required property var style
        property string title: ""

        width: parent ? parent.width : 200
        height: 34

        Column {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 0

            Text {
                width: parent.width
                height: 16
                text: titleItem.title
                color: titleItem.style.cTextOnSurface
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: 1
                color: titleItem.style.cTextOnSurfaceVariant
            }
        }
    }

    component HmclAccountItem: Item {
        id: item

        required property var style
        property string accountName: ""
        property string accountType: ""
        property string avatarUrl: ""
        property bool active: false

        signal clicked
        signal entered

        width: parent ? parent.width : 200
        height: 58
        clip: true

        Rectangle {
            anchors.fill: parent
            color: item.active ? item.style.cNavSelected : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: item.style.animationsEnabled ? item.style.motionShort4 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }

        HmclRipple {
            id: accountRipple
            anchors.fill: parent
            hovered: mouseArea.containsMouse
            hoverColor: item.style.cTextOnSurface
            hoverOpacity: 0.04
            rippleColor: item.active ? item.style.cTextOnSurface : item.style.cTextOnSurfaceVariant
            rippleOpacity: 0.10
            animationsEnabled: item.style.animationsEnabled
            hoverDuration: item.style.motionShort4
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function (event) {
                accountRipple.press(event.x, event.y);
            }
            onEntered: item.entered()
            onClicked: item.clicked()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 6
            color: item.style.cButtonSurface
            clip: true

            Image {
                id: avatarImage
                anchors.fill: parent
                source: item.avatarUrl
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: true
                visible: item.avatarUrl.length > 0 && status !== Image.Error
            }

            Text {
                anchors.centerIn: parent
                visible: !avatarImage.visible
                text: item.accountName.length > 0 ? item.accountName.substring(0, 1).toUpperCase() : "?"
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 16
                font.bold: true
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: item.accountName
                color: item.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: item.active
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: item.accountType
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    component HmclListItem: Item {
        id: item

        required property var style
        property string title: ""
        property string subtitle: ""
        property string iconKind: ""
        property string imageSource: ""
        property bool active: false

        signal clicked
        signal entered

        width: parent ? parent.width : 200
        height: subtitle.length > 0 ? 58 : 52
        clip: true

        Rectangle {
            anchors.fill: parent
            color: item.active ? item.style.cNavSelected : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: item.style.animationsEnabled ? item.style.motionShort4 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }

        HmclRipple {
            id: ripple
            anchors.fill: parent
            hovered: mouseArea.containsMouse
            hoverColor: item.style.cTextOnSurface
            hoverOpacity: 0.04
            rippleColor: item.active ? item.style.cTextOnSurface : item.style.cTextOnSurfaceVariant
            rippleOpacity: 0.10
            animationsEnabled: item.style.animationsEnabled
            hoverDuration: item.style.motionShort4
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: item.entered()
            onPressed: function (event) {
                ripple.press(event.x, event.y);
            }
            onClicked: item.clicked()
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32

            HmclImageContainer {
                anchors.centerIn: parent
                visible: item.imageSource.length > 0
                style: item.style
                source: item.imageSource
                imageSize: 32
                animationsEnabled: item.style.animationsEnabled
            }

            HmclSvgIcon {
                anchors.centerIn: parent
                visible: item.imageSource.length === 0
                icon: item.iconKind
                iconSize: 20
                iconColor: item.style.cTextOnSurface
                animationsEnabled: item.style.animationsEnabled
                animationDuration: item.style.motionShort4
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: item.title
                color: item.style.cTextOnSurface
                font.pixelSize: 13
                font.bold: item.active
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: item.subtitle.length > 0
                text: item.subtitle
                color: item.style.cTextOnSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
}
