import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: row

    property string label: ""
    property real verticalPadding: Theme.spacingS
    default property alias control: controlSlot.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, controlSlot.height) + verticalPadding * 2

    StyledText {
        id: labelText

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
    }

    Item {
        id: controlSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
