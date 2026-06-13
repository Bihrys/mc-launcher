import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.bihrys.launcher

ApplicationWindow {
    id: root

    width: 760
    height: 520
    visible: true
    title: "MC Launcher - Java Detector"

    LauncherBackend {
        id: backend
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Label {
            text: "Java Runtime Detector"
            font.pixelSize: 22
            font.bold: true
        }

        Label {
            text: "点击按钮后，Qt/QML 会调用 Rust core 检测本机 Java。"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Button {
            text: "检测 Java"
            onClicked: backend.detectJava()
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextArea {
                text: backend.output
                placeholderText: "等待检测..."
                readOnly: true
                wrapMode: TextArea.NoWrap
                font.family: "monospace"
                selectByMouse: true
            }
        }
    }
}
