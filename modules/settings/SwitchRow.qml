import QtQuick
import qs.modules.common.widgets

/** A setting that is on or off. The row itself is the target, so the whole line is clickable. */
SettingRow {
    id: root
    property bool checked: false
    signal toggled(bool value)
    // the row is the target: a click anywhere on it, or Enter/Space, flips the switch
    onActivated: root.toggled(!root.checked)

    control: Toggle {
        focusPolicy: Qt.NoFocus   // the row takes the focus; a second tab stop on the switch said nothing new
        enabled: root.enabled
        checked: root.checked
        onClicked: {
            root.toggled(!root.checked);
            checked = Qt.binding(() => root.checked);
        }
    }
}
