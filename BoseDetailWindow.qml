import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

DFloatingWindow {
    id: window

    readonly property var headset: BoseService.headset

    title: "Headphones"
    implicitWidth: 480
    implicitHeight: heightWithin(header.implicitHeight + rows.implicitHeight + Theme.spacingL * 2 + Theme.windowInset * 2, 80)
    visible: false

    onClosed: visible = false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.windowInset
        spacing: 0

        DWindowHeader {
            id: header

            Layout.fillWidth: true
            controls: windowControls
            title: window.headset.name ?? "Headphones"
            subtitle: BoseService.connected ? window.headset.battery + "% battery" : "Not connected"
            onCloseRequested: window.visible = false
        }

        DFlickable {
            id: scroller

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: rows.implicitHeight + Theme.spacingL * 2

            Column {
                id: rows

                x: Theme.spacingL
                y: Theme.spacingL
                width: scroller.width - Theme.spacingL * 2
                enabled: BoseService.connected
                opacity: BoseService.connected ? 1 : 0.5

                SettingRow {
                    label: "Name"
                    verticalPadding: Theme.spacingM

                    DTextField {
                        id: nameField

                        width: 240
                        text: window.headset.name ?? ""
                        onAccepted: {
                            if (text.trim() && text !== window.headset.name)
                                BoseService.change("name", text.trim(), "set_name", [text.trim()]);
                        }
                    }
                }

                SettingRow {
                    label: "Hear your own voice"
                    verticalPadding: Theme.spacingM

                    ChoiceChips {
                        field: "sidetone"
                        options: [{ label: "Off", value: "off" }, { label: "Low", value: "low" }, { label: "Medium", value: "medium" }, { label: "High", value: "high" }]
                        current: window.headset.sidetone
                        onChosen: value => BoseService.change("sidetone", value, "set_sidetone", [value])
                    }
                }

                SettingRow {
                    label: "Connect to two devices"
                    verticalPadding: Theme.spacingM

                    BoseToggle {
                        field: "multipoint"
                        command: "set_multipoint"
                    }
                }

                SettingRow {
                    label: "Pause when taken off"
                    verticalPadding: Theme.spacingM

                    BoseToggle {
                        field: "autoPause"
                        command: "set_auto_pause"
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.spacingL
                }

                CustomModes {}

                Item {
                    width: parent.width
                    height: Theme.spacingL
                }

                SettingRow {
                    label: "Firmware"
                    verticalPadding: Theme.spacingM

                    StyledText {
                        text: window.headset.firmware ?? ""
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }

                SettingRow {
                    label: "Turn off headphones"
                    verticalPadding: Theme.spacingM

                    DButton {
                        text: "Turn off"
                        variant: "outlined"
                        danger: true
                        onClicked: BoseService.powerOff()
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !!window.headset.error
                    topPadding: Theme.spacingS
                    text: window.headset.error ?? ""
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls

        targetWindow: window
    }
}
