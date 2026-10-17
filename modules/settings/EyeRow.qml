import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/**
 * Something that is shown or hidden, with the photo editor's eye instead of a switch: the open eye
 * in ink while it shows, the closed eye faint while it is hidden. SwitchRow's interface.
 */
SettingRow {
    id: root
    property bool checked: false
    signal toggled(bool value)
    muted: !root.checked
    onActivated: root.toggled(!root.checked)

    control: MaterialSymbol {
        text: root.checked ? "visibility" : "visibility_off"
        iconSize: 18
        color: root.checked ? Appearance.colors.colInkMain : Appearance.colors.colInkFaint
    }
}
