import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

Column {
    id: customModes

    readonly property var spatialNumbers: ({ off: 0, room: 1, head: 2 })
    readonly property var spatialLabels: ({ off: "Spatial off", room: "Room", head: "Head tracking" })
    readonly property var allModes: BoseService.headset.modes ?? []
    readonly property var editableModes: allModes.filter(mode => mode.editable)
    readonly property int cncMax: BoseService.headset.cncMax ?? 10
    readonly property bool saving: "customMode" in BoseService.applying

    property bool editorOpen: false
    property string originalName: ""
    property string confirmDeleteName: ""

    width: parent ? parent.width : 0
    spacing: Theme.spacingXS

    function summary(mode) {
        const parts = ["Noise " + (cncMax - mode.cnc), spatialLabels[mode.spatial] ?? mode.spatial];
        if (mode.wind)
            parts.push("Wind block");
        if (!mode.anc)
            parts.push("ANC off");
        return parts.join(" · ");
    }

    function openEditor(mode) {
        originalName = mode ? mode.name : "";
        nameField.text = mode ? mode.name : "";
        cncSlider.value = cncMax - (mode ? mode.cnc : 0);
        ancToggle.checked = mode ? mode.anc : true;
        windToggle.checked = mode ? mode.wind : false;
        spatialChips.current = mode ? mode.spatial : "off";
        confirmDeleteName = "";
        editorOpen = true;
        nameField.forceActiveFocus();
    }

    function nameProblem(name) {
        if (!name)
            return "Give the mode a name.";
        const taken = allModes.some(mode => mode.name.toLowerCase() === name.toLowerCase() && mode.name !== originalName);
        return taken ? "A mode with this name already exists." : "";
    }

    function save() {
        const name = nameField.text.trim();
        if (nameProblem(name))
            return;
        const settings = {
            cnc_level: cncMax - cncSlider.value,
            spatial: spatialNumbers[spatialChips.current],
            wind_block: windToggle.checked ? 1 : 0,
            anc_toggle: ancToggle.checked ? 1 : 0
        };
        if (originalName) {
            settings.rename = name !== originalName ? name : null;
            BoseService.change("customMode", name, "update_profile", [originalName], settings);
        } else {
            BoseService.change("customMode", name, "create_profile", [name, settings.cnc_level, settings.spatial, settings.wind_block, settings.anc_toggle]);
        }
    }

    function remove(name) {
        if (confirmDeleteName !== name) {
            confirmDeleteName = name;
            confirmReset.restart();
            return;
        }
        confirmDeleteName = "";
        BoseService.change("customMode", name, "delete_profile", [name]);
    }

    Connections {
        target: BoseService

        function onChangeConfirmed(field) {
            if (field === "customMode")
                customModes.editorOpen = false;
        }
    }

    Timer {
        id: confirmReset

        interval: 3000
        onTriggered: customModes.confirmDeleteName = ""
    }

    Item {
        width: parent.width
        height: addButton.height

        StyledText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Custom modes"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
        }

        DButton {
            id: addButton

            anchors.right: parent.right
            visible: !customModes.editorOpen
            text: "Add mode"
            iconName: "add"
            variant: "tonal"
            onClicked: customModes.openEditor(null)
        }
    }

    StyledText {
        width: parent.width
        visible: customModes.editableModes.length === 0 && !customModes.editorOpen
        topPadding: Theme.spacingS
        bottomPadding: Theme.spacingS
        text: "No custom modes yet. Modes you add are saved on the headphones and show up next to Quiet, Aware, Immersion and Cinema."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: customModes.editableModes

        Item {
            id: modeRow

            required property var modelData
            readonly property bool confirmingDelete: customModes.confirmDeleteName === modelData.name

            width: customModes.width
            height: Math.max(modeText.implicitHeight, rowActions.height) + Theme.spacingS * 2

            Column {
                id: modeText

                anchors.left: parent.left
                anchors.right: rowActions.left
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: modeRow.modelData.name
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: customModes.summary(modeRow.modelData)
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            Row {
                id: rowActions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                DSpinner {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BoseService.isApplying("customMode", modeRow.modelData.name) && !customModes.editorOpen
                    size: 16
                }

                DIconButton {
                    iconName: "edit"
                    tooltipText: "Edit mode"
                    enabled: !customModes.saving
                    onClicked: customModes.openEditor(modeRow.modelData)
                }

                DButton {
                    visible: modeRow.confirmingDelete
                    text: "Delete"
                    variant: "tonal"
                    danger: true
                    onClicked: customModes.remove(modeRow.modelData.name)
                }

                DIconButton {
                    visible: !modeRow.confirmingDelete
                    iconName: "delete"
                    tooltipText: "Delete mode"
                    enabled: !customModes.saving
                    onClicked: customModes.remove(modeRow.modelData.name)
                }
            }
        }
    }

    Section {
        visible: customModes.editorOpen

        SettingRow {
            label: "Name"

            DTextField {
                id: nameField

                width: 220
                maximumLength: 31
                isError: !!customModes.nameProblem(text.trim()) && text.length > 0
                onAccepted: customModes.save()
            }
        }

        SettingRow {
            label: "Noise cancellation"

            DSlider {
                id: cncSlider

                width: 220
                minimum: 0
                maximum: customModes.cncMax
            }
        }

        SettingRow {
            label: "Active noise cancelling"

            DToggle {
                id: ancToggle

                hideText: true
                onToggled: checked => ancToggle.checked = checked
            }
        }

        SettingRow {
            label: "Wind block"

            DToggle {
                id: windToggle

                hideText: true
                onToggled: checked => windToggle.checked = checked
            }
        }

        SettingRow {
            label: "Spatial audio"

            ChoiceChips {
                id: spatialChips

                field: "customModeSpatial"
                options: [{ label: "Off", value: "off" }, { label: "Room", value: "room" }, { label: "Head", value: "head" }]
                current: "off"
                onChosen: value => spatialChips.current = value
            }
        }

        Item {
            width: parent.width
            height: editorButtons.height + Theme.spacingS * 2

            StyledText {
                anchors.left: parent.left
                anchors.right: editorButtons.left
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                text: customModes.nameProblem(nameField.text.trim())
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                visible: nameField.text.length > 0
            }

            Row {
                id: editorButtons

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DButton {
                    text: "Cancel"
                    variant: "text"
                    enabled: !customModes.saving
                    onClicked: customModes.editorOpen = false
                }

                DButton {
                    text: customModes.originalName ? "Save" : "Add mode"
                    busy: customModes.saving
                    enabled: !customModes.saving && !customModes.nameProblem(nameField.text.trim())
                    onClicked: customModes.save()
                }
            }
        }
    }
}
