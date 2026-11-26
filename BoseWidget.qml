import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property var headset: BoseService.headset
    readonly property bool connected: BoseService.connected
    readonly property int battery: headset.battery ?? 0
    readonly property color batteryColor: battery <= 20 ? Theme.warning : Theme.surfaceText
    readonly property int cncMax: headset.cncMax ?? 10

    popoutWidth: 420

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "headphones"
                size: root.iconSize
                color: root.connected ? Theme.surfaceText : Theme.surfaceVariantText
                opacity: root.connected ? 1 : 0.5
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.connected
                text: root.battery + "%"
                color: root.batteryColor
                font.pixelSize: root.textSize
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "headphones"
                size: root.iconSize
                color: root.connected ? Theme.surfaceText : Theme.surfaceVariantText
                opacity: root.connected ? 1 : 0.5
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.connected
                text: root.battery
                color: root.batteryColor
                font.pixelSize: root.textSize
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: root.connected ? (root.headset.name ?? "Headphones") : "Headphones"
            detailsText: root.connected ? root.battery + "% battery" : ""

            headerActions: Component {
                DIconButton {
                    visible: root.connected
                    iconName: "tune"
                    tooltipText: "Device settings"
                    onClicked: {
                        BoseService.openDetails();
                        popout.closePopout?.();
                    }
                }
            }

            Column {
                width: parent.width
                visible: !root.connected
                topPadding: Theme.spacingL
                bottomPadding: Theme.spacingL
                spacing: Theme.spacingS

                StyledText {
                    width: parent.width
                    text: "Not connected"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    width: parent.width
                    text: "Turn the headphones on, or connect them in Bluetooth settings."
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            Column {
                width: parent.width
                visible: root.connected
                spacing: Theme.spacingM

                Section {
                    Column {
                        width: parent.width
                        topPadding: Theme.spacingS
                        bottomPadding: Theme.spacingS
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Mode"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        ChoiceChips {
                            field: "mode"
                            maximumWidth: parent.width
                            options: BoseService.modeNames.map(name => ({ label: name, value: name }))
                            current: root.headset.mode
                            onChosen: value => BoseService.change("mode", value, "set_mode", [value])
                        }
                    }
                }

                Section {
                    SettingRow {
                        label: "Noise cancellation"

                        DSlider {
                            id: cncSlider

                            readonly property int headsetValue: root.cncMax - (root.headset.cnc ?? 0)

                            width: popout.width * 0.5
                            minimum: 0
                            maximum: root.cncMax
                            value: headsetValue
                            onHeadsetValueChanged: {
                                if (!isDragging && !cncDebounce.running)
                                    value = headsetValue;
                            }
                            onSliderValueChanged: newValue => cncDebounce.restart()

                            Timer {
                                id: cncDebounce

                                interval: 400
                                onTriggered: BoseService.change("cnc", root.cncMax - cncSlider.value, "set_cnc", [root.cncMax - cncSlider.value])
                            }
                        }
                    }

                    SettingRow {
                        label: "Active noise cancelling"
                        visible: root.headset.anc !== null && root.headset.anc !== undefined

                        BoseToggle {
                            field: "anc"
                            command: "set_anc"
                        }
                    }

                    SettingRow {
                        label: "Wind block"
                        visible: root.headset.wind !== null && root.headset.wind !== undefined

                        BoseToggle {
                            field: "wind"
                            command: "set_wind"
                        }
                    }
                }

                Section {
                    visible: !!root.headset.spatial

                    SettingRow {
                        label: "Spatial audio"

                        ChoiceChips {
                            field: "spatial"
                            options: [{ label: "Off", value: "off" }, { label: "Room", value: "room" }, { label: "Head", value: "head" }]
                            current: root.headset.spatial
                            onChosen: value => BoseService.change("spatial", value, "set_spatial", [value])
                        }
                    }
                }

                Section {
                    EqualizerCurve {
                        headsetValues: root.headset.eq ?? [0, 0, 0]
                        onChangeRequested: bands => BoseService.change("eq", bands, "set_eq", bands)
                    }
                }

                StyledText {
                    width: parent.width
                    visible: !!root.headset.error
                    topPadding: Theme.spacingS
                    text: root.headset.error ?? ""
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
