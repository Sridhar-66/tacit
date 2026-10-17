import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// A control-panel row in a card: hairline above (not on the first row), glyph, 15 px label, and
// whatever the row needs after the label.
ColumnLayout {
    id: root
    property string glyph: ""
    property string label: ""
    property bool first: false
    property real rowHeight: 34
    // A fixed label width leaves the rest of the row to what follows it.
    property real labelWidth: -1
    default property alias trailing: rowLayout.data
    readonly property alias labelItem: labelText
    Layout.fillWidth: true
    spacing: 0

    TacitHair {
        visible: !root.first
        Layout.fillWidth: true
    }
    RowLayout {
        id: rowLayout
        Layout.fillWidth: true
        Layout.preferredHeight: root.rowHeight
        spacing: 8
        MaterialSymbol {
            visible: root.glyph.length > 0
            text: root.glyph
            iconSize: 18
            color: Appearance.colors.colSubtext
        }
        StyledText {
            id: labelText
            Layout.fillWidth: root.labelWidth < 0
            Layout.preferredWidth: root.labelWidth
            text: root.label
            font.pixelSize: 16
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer0
        }
    }
}
