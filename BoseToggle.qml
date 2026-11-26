import QtQuick
import qs.DCommon.Widgets

DToggle {
    id: toggle

    property string field: ""
    property string command: ""
    readonly property bool applying: field in BoseService.applying

    hideText: true
    checked: (applying ? BoseService.applying[field] : BoseService.headset[field]) === true
    toggling: applying
    onToggled: checked => BoseService.change(field, checked, command, [checked])
}
