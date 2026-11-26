import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

Flow {
    id: chips

    property string field: ""
    property var options: []
    property var current: null
    property real maximumWidth: Infinity
    readonly property real singleLineWidth: {
        let total = 0;
        for (let index = 0; index < chipRepeater.count; index++) {
            const chip = chipRepeater.itemAt(index);
            if (chip)
                total += chip.width + (index > 0 ? spacing : 0);
        }
        return total;
    }

    signal chosen(var value)

    width: Math.min(singleLineWidth, maximumWidth)
    spacing: Theme.spacingXS

    Repeater {
        id: chipRepeater

        model: chips.options

        Rectangle {
            id: chip

            required property var modelData
            readonly property bool selected: BoseService.sameValue(chips.current, modelData.value)
            readonly property bool applying: BoseService.isApplying(chips.field, modelData.value)
            readonly property bool justApplied: BoseService.isJustApplied(chips.field, modelData.value)
            readonly property color contentColor: selected ? Theme.onPrimary : Theme.onSecondaryContainer

            width: content.implicitWidth + Theme.spacingM * 2
            height: 30
            radius: height / 2
            color: selected ? Theme.primary : chipArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : Theme.secondaryContainer
            border.width: applying ? 1.5 : 0
            border.color: Theme.primary

            Behavior on width {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DSpinner {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.applying
                    size: 14
                    color: Theme.primary
                }

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.justApplied
                    name: "check"
                    size: 16
                    color: chip.contentColor
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.label
                    color: chip.contentColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: chipArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!chip.selected && !chip.applying)
                        chips.chosen(chip.modelData.value);
                }
            }
        }
    }
}
