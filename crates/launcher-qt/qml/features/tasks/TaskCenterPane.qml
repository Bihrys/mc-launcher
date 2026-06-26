import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Hmcl/controls"

Item {
    id: root
    property var style
    property string tasksJson: "{\"tasks\":[]}"
    property var tasks: []

    onTasksJsonChanged: {
        try { tasks = JSON.parse(tasksJson).tasks || [] } catch (e) { tasks = [] }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Text {
            Layout.margins: 12
            text: "任务中心"
            color: root.style.cTextOnSurface
            font.pixelSize: 16
            font.bold: true
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.tasks
            delegate: MDListCell {
                style: root.style
                required property var modelData
                width: ListView.view.width
                height: 56
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    SpinnerPane { visible: modelData.active; style: root.style; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: modelData.title || "任务"; color: root.style.cTextOnSurface; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: modelData.message || modelData.status || ""; color: root.style.cTextOnSurfaceVariant; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Text { text: Math.round(modelData.percent || 0) + "%"; color: root.style.cTextOnSurfaceVariant; font.pixelSize: 12 }
                }
            }
        }
    }
}
