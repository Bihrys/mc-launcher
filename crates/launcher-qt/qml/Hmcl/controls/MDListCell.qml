import QtQuick
Item { id: root; required property var style; height: 49; Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.style.cBorder; opacity: 0.85 } }
