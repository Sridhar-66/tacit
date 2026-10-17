import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * A setting that is a piece of text: a folder, a city, a key. It commits when you press Enter or
 * leave the field, never on every keystroke - each commit is a write of the whole config file,
 * and the shell reloads what reads it.
 */
SettingRow {
    id: root
    property string text: ""
    property string placeholder: ""
    property bool secret: false
    property int fieldWidth: 280
    // a one- or two-character value (a palette prefix): narrow, centred, monospace
    property bool compact: false
    signal committed(string value)
    // Tab goes straight into the text, not to the row around it
    activeFocusOnTab: false
    // puts the saved value back, for a caller that refuses what was typed
    function revert() {
        input.text = root.text;
    }
    clickable: false

    control: Rectangle {
        implicitWidth: root.compact ? 44 : root.fieldWidth
        implicitHeight: 34
        radius: 10
        color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95)
        border.width: 1
        border.color: input.activeFocus ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.15)
            : ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93)
        Behavior on border.color { ColorAnimation { duration: 120 } }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: root.compact ? TextInput.AlignHCenter : TextInput.AlignLeft
            font.pixelSize: root.compact ? 15 : 14
            font.family: root.compact ? Appearance.font.family.monospace : Appearance.font.family.main
            color: Appearance.colors.colInkMain
            selectionColor: Appearance.colors.colPrimary
            echoMode: root.secret && !activeFocus ? TextInput.Password : TextInput.Normal
            clip: true
            activeFocusOnTab: true
            text: root.text
            onEditingFinished: if (text !== root.text) root.committed(text.trim())
            // At rest a long value shows its start: a folder read "home/abdul/Pictures/Scr..."
            // with the leading slash scrolled off, because setting the text leaves the cursor at the end.
            onTextChanged: if (!activeFocus) cursorPosition = 0
            onActiveFocusChanged: if (!activeFocus) cursorPosition = 0
            Keys.onEscapePressed: { text = root.text; focus = false; }
        }
        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder
            font.pixelSize: 15
            color: Tacit.inkMeta
        }
    }
}
