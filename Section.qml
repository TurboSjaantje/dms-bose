import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: section

    default property alias rows: content.data

    width: parent ? parent.width : 0
    height: content.implicitHeight + Theme.spacingS * 2
    color: Theme.surfaceContainerHigh

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
    }
}
