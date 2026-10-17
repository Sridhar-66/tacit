import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// A choice with its name under a glyph: the control panel's pill language (a quiet ground and a
// primary glyph when it is the one) with a label, since nine colour schemes have no names to learn.
RippleButton {
    id: root
    property string glyph: ""
    property string label: ""
    property bool on: false

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 54
    buttonRadius: 16
    toggled: root.on
    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colBackgroundToggled: Appearance.colors.colLayer2
    colBackgroundToggledHover: Appearance.colors.colLayer2Hover

    contentItem: Column {
        anchors.centerIn: parent
        spacing: 3
        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.glyph
            fill: root.on ? 1 : 0
            iconSize: 22
            color: root.on ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.pixelSize: Appearance.font.pixelSize.tiny
            color: root.on ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
        }
    }
}
