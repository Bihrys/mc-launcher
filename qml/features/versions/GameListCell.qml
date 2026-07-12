import QtQuick
import QtQuick.Layouts
import "../../Hmcl/controls"

// HMCL GameListCell.java port. Geometry follows the JavaFX control:
// 8 px top/right/bottom padding, 32 px icon, 8 px center spacing and
// 30 px toggle-icon4 buttons.
MDListCell {
    id: root

    required property string instanceId
    required property string title
    required property string subtitle
    required property string tag
    required property string iconName
    required property bool selected
    required property bool canUpdate

    property string iconBase: ""

    signal selectRequested()
    signal openRequested()
    signal launchRequested()
    signal updateRequested()
    signal manageRequested(real x, real y)

    height: 49
    implicitHeight: 49
    onClicked: root.openRequested()

    Rectangle {
        anchors.fill: parent
        z: -1
        visible: root.selected
        color: root.styleValue("cNavSelected", "transparent")
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        spacing: 0

        RadioButton {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            style: root.style
            checked: root.selected
            onClicked: root.selectRequested()
        }

        Item { Layout.preferredWidth: 8 }

        Image {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            fillMode: Image.PreserveAspectFit
            smooth: false
            sourceSize.width: 32
            sourceSize.height: 32
            source: root.iconBase + (root.iconName.length > 0 ? root.iconName : "grass") + ".png"
        }

        Item { Layout.preferredWidth: 8 }

        TwoLineListItem {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            title: root.title
            subtitle: root.subtitle
            tag: root.tag
            titleFontSize: 13
            subtitleFontSize: 10
            titleBold: root.selected
            style: root.style
        }

        ToolbarButton {
            visible: root.canUpdate
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            style: root.style
            iconKind: "UPDATE"
            onClicked: root.updateRequested()
        }

        ToolbarButton {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            style: root.style
            iconKind: "ROCKET_LAUNCH"
            onClicked: root.launchRequested()
        }

        ToolbarButton {
            id: menuButton
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            style: root.style
            iconKind: "MORE_VERT"
            onClicked: {
                var p = menuButton.mapToItem(root, menuButton.width / 2, menuButton.height)
                root.manageRequested(p.x, p.y)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: function(mouse) { root.manageRequested(mouse.x, mouse.y) }
    }
}
