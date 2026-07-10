import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../../Hmcl/controls" as Hmcl
import "../../Hmcl/icons" as Icons
import "../../components"

Column {
    id: root

    property var style
    property var backend
    property var settingsPage
    property var appearanceOptions: ({"fonts": [], "builtinBackgrounds": [], "standardThemeColors": []})

    width: parent ? parent.width : 800
    spacing: 10

    function logAction(action, details) {
        if (root.backend)
            root.backend.logUiAction("ui.settings.appearance", action, JSON.stringify(details || {}))
    }

    Component.onCompleted: {
        root.logAction("panel_completed", {})
        root.reloadAppearanceOptions()
    }

    function reloadAppearanceOptions() {
        if (!root.backend || root.backend.refreshAppearanceOptions === undefined)
            return
        try {
            root.appearanceOptions = JSON.parse(root.backend.refreshAppearanceOptions() || "{}")
        } catch (e) {
            root.logAction("appearance_options_parse_failed", {"error": String(e)})
            root.appearanceOptions = {"fonts": [], "builtinBackgrounds": [], "standardThemeColors": []}
        }
    }

    function st(key, fallback) { return settingsPage ? settingsPage.settingText(key, fallback) : String(fallback || "") }
    function sb(key, fallback) { return settingsPage ? settingsPage.settingBool(key, fallback) : !!fallback }
    function set(key, value) { if (settingsPage) settingsPage.setSetting(key, String(value)) }
    function setb(key, value) { if (settingsPage) settingsPage.setBool(key, value) }

    function themeModeValue() {
        var v = root.st("themeBrightnessMode", root.st("themeMode", "auto"))
        if (v === "system") return "auto"
        return v
    }

    function colorTypeText(value) {
        if (value === "custom") return "自定义"
        if (value === "background") return "跟随背景图片"
        return "默认"
    }

    function builtinOptions() {
        var src = root.appearanceOptions.builtinBackgrounds || []
        var out = []
        for (var i = 0; i < src.length; ++i)
            out.push({"text": String(src[i].title || src[i].id), "value": String(src[i].id)})
        if (out.length === 0) {
            out.push({"text":"2021-08-26","value":"2021-08-26"})
            out.push({"text":"2016-02-25","value":"2016-02-25"})
            out.push({"text":"2015-06-22","value":"2015-06-22"})
        }
        return out
    }

    function fontOptions(includeDefault) {
        var out = includeDefault ? [{"text":"默认","value":""}] : []
        var src = root.appearanceOptions.fonts || []
        for (var i = 0; i < src.length; ++i)
            out.push({"text": String(src[i]), "value": String(src[i])})
        if (out.length <= (includeDefault ? 1 : 0)) {
            out.push({"text":"Noto Sans CJK SC","value":"Noto Sans CJK SC"})
            out.push({"text":"Sans Serif","value":"Sans Serif"})
            out.push({"text":"Monospace","value":"monospace"})
        }
        return out
    }

    FileDialog {
        id: backgroundFileDialog
        title: "选择背景图片"
        fileMode: FileDialog.OpenFile
        nameFilters: ["图片文件 (*.png *.jpg *.jpeg *.bmp *.gif *.webp)", "所有文件 (*)"]
        onAccepted: {
            var chosen = String(selectedFile)
            if (chosen.length === 0 && selectedFiles.length > 0)
                chosen = String(selectedFiles[0])
            if (chosen.indexOf("file://") === 0)
                chosen = decodeURIComponent(chosen.substring(7))
            root.logAction("background_file_selected", {"path": chosen})
            root.set("customBackgroundImagePath", chosen)
            root.set("backgroundImage", chosen)
            root.set("backgroundType", "custom")
        }
    }

    HmclSettingTitle { style: root.style; title: "外观" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "主题模式"
            value: root.themeModeValue()
            options: [
                {"text":"跟随系统","value":"auto"},
                {"text":"浅色模式","value":"light"},
                {"text":"深色模式","value":"dark"}
            ]
            onSelected: function(v) {
                root.set("themeBrightnessMode", v)
                root.set("themeMode", v === "auto" ? "system" : v)
                if (settingsPage) settingsPage.themeSelected(v === "auto" ? "system" : v)
            }
        }

        Hmcl.ComponentSublist {
            width: parent.width
            style: root.style
            title: "主题色"
            hasSubtitle: false
            trailingText: root.colorTypeText(root.st("themeColorType", "default"))

            HmclThemeColorChoiceList {
                width: parent.width
                style: root.style
                value: root.st("themeColorType", "default")
                colorValue: root.st("customThemeColor", root.st("themeColor", "#5C6BC0"))
                standardColors: root.appearanceOptions.standardThemeColors || []
                onSelected: function(v) {
                    root.set("themeColorType", v)
                    if (v === "default") {
                        root.set("themeColor", "default")
                        if (settingsPage) settingsPage.themeColorSelected("default")
                    } else if (v === "background") {
                        root.set("themeColor", "background")
                    } else if (v === "custom") {
                        var color = root.st("customThemeColor", root.st("themeColor", "#5C6BC0"))
                        if (color === "default" || color === "background" || color.length === 0)
                            color = "#5C6BC0"
                        root.set("themeColor", color)
                        if (settingsPage) settingsPage.themeColorSelected(color)
                    }
                }
                onColorSelected: function(v) {
                    root.set("themeColorType", "custom")
                    root.set("customThemeColor", v)
                    root.set("themeColor", v)
                    if (settingsPage) settingsPage.themeColorSelected(v)
                }
            }
        }

        HmclToggleLine {
            style: root.style
            title: "标题栏透明"
            checkedValue: root.sb("titleTransparent", false)
            onChangedValue: function(v) { root.setb("titleTransparent", v) }
        }

        HmclToggleLine {
            style: root.style
            title: "关闭动画"
            subtitle: "重启后生效"
            checkedValue: root.sb("animationDisabled", root.sb("turnOffAnimations", false))
            onChangedValue: function(v) { root.setb("animationDisabled", v); root.setb("turnOffAnimations", v) }
        }
    }

    HmclSettingTitle { style: root.style; title: "背景图片" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        Column {
            width: parent.width
            spacing: 8

            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "默认"
                subtitle: "使用主题背景；无主题背景时使用 HMCL 内置默认壁纸"
                checked: root.st("backgroundType", "default") === "default"
                onClicked: root.set("backgroundType", "default")
            }

            HmclRadioOptionLine {
                id: builtinBackgroundRow
                width: parent.width
                style: root.style
                title: "经典"
                checked: root.st("backgroundType", "default") === "builtin"
                onClicked: root.set("backgroundType", "builtin")

                InlineComboBox {
                    style: root.style
                    value: root.st("builtinBackgroundId", "2021-08-26")
                    options: root.builtinOptions()
                    enabledBox: builtinBackgroundRow.checked
                    onSelected: function(v) {
                        root.set("builtinBackgroundId", v)
                        root.set("backgroundType", "builtin")
                    }
                }
            }

            HmclRadioOptionLine {
                width: parent.width
                style: root.style
                title: "主题色"
                checked: root.st("backgroundType", "default") === "theme_color"
                onClicked: root.set("backgroundType", "theme_color")
            }

            HmclRadioOptionLine {
                id: customBackgroundRow
                width: parent.width
                style: root.style
                title: "自定义"
                checked: root.st("backgroundType", "default") === "custom"
                onClicked: root.set("backgroundType", "custom")

                InlineFileTextBox {
                    style: root.style
                    valueText: root.st("customBackgroundImagePath", root.st("backgroundImage", ""))
                    enabledBox: customBackgroundRow.checked
                    onAccepted: function(v) {
                        root.set("customBackgroundImagePath", v)
                        root.set("backgroundImage", v)
                        root.set("backgroundType", "custom")
                    }
                    onBrowse: backgroundFileDialog.open()
                }
            }

            HmclRadioOptionLine {
                id: networkBackgroundRow
                width: parent.width
                style: root.style
                title: "网络"
                checked: root.st("backgroundType", "default") === "network"
                onClicked: root.set("backgroundType", "network")

                InlineTextBox {
                    style: root.style
                    valueText: root.st("networkBackgroundImageUrl", root.st("backgroundImageUrl", ""))
                    enabledBox: networkBackgroundRow.checked
                    onAccepted: function(v) {
                        root.set("networkBackgroundImageUrl", v)
                        root.set("backgroundImageUrl", v)
                        root.set("backgroundType", "network")
                    }
                }
            }

            HmclRadioOptionLine {
                id: paintBackgroundRow
                width: parent.width
                style: root.style
                title: "纯色"
                checked: root.st("backgroundType", "default") === "paint"
                onClicked: root.set("backgroundType", "paint")

                InlineTextBox {
                    style: root.style
                    valueText: root.st("customBackgroundPaint", root.st("backgroundPaint", ""))
                    placeholderText: "#FFFFFF"
                    enabledBox: paintBackgroundRow.checked
                    onAccepted: function(v) {
                        root.set("customBackgroundPaint", v)
                        root.set("backgroundPaint", v)
                        root.set("backgroundType", "paint")
                    }
                }
            }
        }

        HmclSliderLine {
            style: root.style
            title: "不透明度"
            fromValue: 0
            toValue: 100
            valueNumber: Number(root.st("backgroundOpacity", "1")) * 100
            suffix: "%"
            onMovedValue: function(v) {
                var snapped = Math.round(v / 5) * 5
                root.set("backgroundOpacity", String(snapped / 100))
            }
        }
    }

    HmclSettingTitle { style: root.style; title: "日志" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "日志字体"
            value: root.st("logFontFamily", root.st("logFont", "monospace"))
            options: root.fontOptions(false)
            onSelected: function(v) { root.set("logFontFamily", v); root.set("logFont", v) }
        }

        HmclTextLine {
            style: root.style
            title: "日志字号"
            valueText: root.st("logFontSize", "12")
            onAccepted: function(v) { root.set("logFontSize", v) }
        }

        HmclFontPreviewLine {
            style: root.style
            text: "[23:33:33] [Client Thread/INFO] [WaterPower]: Loaded mod WaterPower."
            fontFamily: root.st("logFontFamily", root.st("logFont", "monospace"))
            fontSize: Number(root.st("logFontSize", "12"))
        }
    }

    HmclSettingTitle { style: root.style; title: "字体" }
    Hmcl.ComponentList {
        width: parent.width
        style: root.style

        HmclSelectLine {
            style: root.style
            title: "字体"
            value: root.st("launcherFontFamily", root.st("globalFontFamily", ""))
            options: root.fontOptions(true)
            onSelected: function(v) { root.set("launcherFontFamily", v); root.set("globalFontFamily", v) }
        }

        HmclFontPreviewLine {
            style: root.style
            text: "Hello Minecraft! Launcher"
            fontFamily: root.st("launcherFontFamily", root.st("globalFontFamily", ""))
            fontSize: 13
        }

        HmclSelectLine {
            style: root.style
            title: "抗锯齿"
            subtitle: "重启后生效"
            value: root.st("fontAntiAliasing", "auto")
            options: [
                {"text":"自动","value":"auto"},
                {"text":"LCD","value":"lcd"},
                {"text":"灰度","value":"gray"}
            ]
            onSelected: function(v) { root.set("fontAntiAliasing", v) }
        }
    }

    component InlineComboBox: Rectangle {
        id: combo

        required property var style
        property var options: []
        property string value: ""
        property bool enabledBox: true
        signal selected(string value)

        Layout.preferredWidth: 160
        Layout.preferredHeight: 32
        width: 160
        height: 32
        radius: 3
        color: mouse.containsMouse || popup.opened ? styleValue("cSurfaceContainerHigh", "#ECE9F1") : styleValue("cSurfaceContainer", "#F5F2FA")
        opacity: enabledBox ? 1.0 : 0.45

        function styleValue(name, fallback) {
            if (combo.style !== undefined && combo.style !== null) {
                var value = combo.style[name]
                if (value !== undefined && value !== null)
                    return value
            }
            return fallback
        }

        function currentText() {
            for (var i = 0; i < combo.options.length; ++i) {
                if (String(combo.options[i].value) === combo.value)
                    return String(combo.options[i].text)
            }
            return combo.value.length > 0 ? combo.value : (combo.options.length > 0 ? String(combo.options[0].text) : "")
        }

        HmclRipple {
            id: comboRipple
            anchors.fill: parent
            hovered: mouse.containsMouse && combo.enabledBox
            hoverColor: combo.styleValue("cTextOnSurface", "#1B1B21")
            rippleColor: combo.styleValue("cTextOnSurface", "#1B1B21")
            animationsEnabled: !!combo.styleValue("animationsEnabled", true)
        }

        Text {
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            text: combo.currentText()
            color: combo.styleValue("cTextOnSurface", "#1B1B21")
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Icons.SvgIcon {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            icon: "KEYBOARD_ARROW_DOWN"
            iconSize: 20
            iconColor: combo.styleValue("cTextOnSurfaceVariant", "#454651")
            rotation: popup.opened ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: combo.enabledBox
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) { comboRipple.press(mouse.x, mouse.y) }
            onReleased: comboRipple.release()
            onCanceled: comboRipple.cancel()
            onClicked: {
                if (popup.opened) popup.close()
                else popup.open()
            }
        }

        Popup {
            id: popup
            x: 0
            y: combo.height
            width: Math.max(combo.width, 180)
            height: Math.min(Math.max(40, optionColumn.implicitHeight), 220)
            padding: 0
            modal: false
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            background: Rectangle {
                color: combo.styleValue("cSurface", "#FFFBFE")
                radius: 3
                border.color: combo.styleValue("cBorder", "#D9D7E2")
                border.width: 1
            }

            contentItem: Flickable {
                width: popup.width
                height: popup.height
                contentWidth: width
                contentHeight: optionColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: optionColumn
                    width: popup.width
                    Repeater {
                        model: combo.options
                        delegate: Rectangle {
                            required property var modelData
                            width: popup.width
                            height: 40
                            color: String(modelData.value) === combo.value
                                   ? combo.styleValue("cNavSelected", "#E7E7FF")
                                   : optionMouse.containsMouse ? combo.styleValue("cSurfaceContainer", "#F5F2FA") : combo.styleValue("cSurface", "#FFFBFE")

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: String(modelData.text)
                                color: String(modelData.value) === combo.value
                                       ? combo.styleValue("cLaunchButton", "#4352A5")
                                       : combo.styleValue("cTextOnSurface", "#1B1B21")
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: optionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    popup.close()
                                    combo.selected(String(modelData.value))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component InlineTextBox: Item {
        id: textBox

        required property var style
        property string valueText: ""
        property string placeholderText: ""
        property bool enabledBox: true
        signal accepted(string value)

        Layout.preferredWidth: 160
        Layout.preferredHeight: 32
        width: 160
        height: 32
        opacity: enabledBox ? 1.0 : 0.45

        function styleValue(name, fallback) {
            if (textBox.style !== undefined && textBox.style !== null) {
                var value = textBox.style[name]
                if (value !== undefined && value !== null)
                    return value
            }
            return fallback
        }

        TextField {
            id: input
            anchors.fill: parent
            enabled: textBox.enabledBox
            text: textBox.valueText
            placeholderText: textBox.placeholderText
            selectByMouse: true
            color: textBox.styleValue("cTextOnSurface", "#1B1B21")
            placeholderTextColor: textBox.styleValue("cTextOnSurfaceVariant", "#454651")
            font.pixelSize: 13
            background: Rectangle {
                color: "transparent"
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: input.activeFocus ? textBox.styleValue("cButtonSelected", "#4352A5") : textBox.styleValue("cTextOnSurfaceVariant", "#454651")
                    opacity: input.activeFocus ? 1 : 0.35
                }
            }
            onAccepted: textBox.accepted(text)
            onEditingFinished: textBox.accepted(text)
        }
    }

    component InlineFileTextBox: Rectangle {
        id: fileBox

        required property var style
        property string valueText: ""
        property string placeholderText: ""
        property bool enabledBox: true
        signal accepted(string value)
        signal browse()

        Layout.preferredWidth: 176
        Layout.preferredHeight: 32
        width: 176
        height: 32
        radius: 3
        color: styleValue("cSurfaceContainerHigh", "#ECE9F1")
        opacity: enabledBox ? 1.0 : 0.45

        function styleValue(name, fallback) {
            if (fileBox.style !== undefined && fileBox.style !== null) {
                var value = fileBox.style[name]
                if (value !== undefined && value !== null)
                    return value
            }
            return fallback
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 6

            TextField {
                id: fileInput
                Layout.fillWidth: true
                enabled: fileBox.enabledBox
                text: fileBox.valueText
                placeholderText: fileBox.placeholderText
                selectByMouse: true
                font.pixelSize: 12
                color: fileBox.styleValue("cTextOnSurface", "#1B1B21")
                placeholderTextColor: fileBox.styleValue("cTextOnSurfaceVariant", "#454651")
                background: Item {}
                onAccepted: fileBox.accepted(text)
                onEditingFinished: fileBox.accepted(text)
            }

            Icons.SvgIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                icon: "FOLDER_OPEN"
                iconSize: 18
                iconColor: fileBox.styleValue("cTextOnSurfaceVariant", "#454651")
                opacity: fileBox.enabledBox ? 1 : 0.4

                MouseArea {
                    anchors.fill: parent
                    enabled: fileBox.enabledBox
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fileBox.browse()
                }
            }
        }
    }
}
