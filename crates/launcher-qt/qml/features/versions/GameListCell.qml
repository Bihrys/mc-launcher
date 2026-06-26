import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls"
import "../../Hmcl/icons"

MDListCell {
    id: root
    property alias iconSource: icon.source
    property string title: ""
    property string subtitle: ""
    property string tag: ""
    property bool selected: false
    property bool canUpdate: false
    property var style

    signal selectRequested()
    signal openRequested()
    signal launchRequested()
    signal updateRequested()
    signal manageRequested(real x, real y)

    height: 49
    implicitHeight: 49

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        RadioButton {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            checked: root.selected
            style: root.style
            onClicked: root.selectRequested()
        }

        Image {
            id: icon
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            fillMode: Image.PreserveAspectFit
            smooth: false
            sourceSize.width: 32
            sourceSize.height: 32
        }

        TwoLineListItem {
            Layout.fillWidth: true
            title: root.title
            subtitle: root.subtitle
            tag: root.tag
            style: root.style
        }

        ToolbarButton {
            visible: root.canUpdate
            style: root.style
            iconKind: "UPDATE"
            onClicked: root.updateRequested()
        }

        ToolbarButton {
            style: root.style
            iconKind: "ROCKET_LAUNCH"
            onClicked: root.launchRequested()
        }

        ToolbarButton {
            style: root.style
            iconKind: "MENU"
            onClicked: root.manageRequested(width / 2, height / 2)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        z: -1
        onDoubleClicked: root.openRequested()
    }
}
