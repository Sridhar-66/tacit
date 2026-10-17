import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// One menu row: glyph, label, then a count or a chevron. `open` marks the row whose panel is out.
RippleButton {
    id: root
    property string glyph: ""
    property string label: ""
    property string hint: ""
    property string trail: ""
    property bool open: false

    Layout.fillWidth: true
    implicitHeight: 38
    buttonRadius: 19
    colBackground: root.open ? Appearance.colors.colLayer2 : "transparent"
    colBackgroundHover: root.open ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1Hover

    contentItem: RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 10
        MaterialSymbol {
            text: root.glyph
            iconSize: 20
            color: root.open ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            visible: root.hint.length > 0
            text: root.hint
            font.family: Appearance.font.family.numbers
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
        MaterialSymbol {
            visible: root.trail.length > 0
            text: root.trail
            iconSize: 18
            color: Appearance.colors.colSubtext
        }
    }
}
