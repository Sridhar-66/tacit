import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// A setting that is on or off, read as the control panel reads a pill: the glyph on a quiet disc,
// primary when on, and the state in words at the right.
RippleButton {
    id: root
    property string glyph: ""
    property string label: ""
    property bool on: false
    signal flipped(bool value)

    Layout.fillWidth: true
    implicitHeight: 38
    buttonRadius: 19
    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer1Hover
    onClicked: root.flipped(!root.on)

    contentItem: RowLayout {
        anchors { fill: parent; leftMargin: 4; rightMargin: 12 }
        spacing: 8
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: root.on ? Appearance.colors.colLayer2 : "transparent"
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.glyph
                fill: root.on ? 1 : 0
                iconSize: 20
                color: root.on ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.label
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            text: root.on ? "On" : "Off"
            font.pixelSize: Appearance.font.pixelSize.smallie
            color: root.on ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
        }
    }
}
