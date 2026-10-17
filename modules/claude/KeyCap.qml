import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A key and what it does, as the notch's sheet draws them (Opsis's KeyCap): the key in a 20 px cap
// (onSurface 8 %, a 6 % edge), its word beside it in the quiet tone. Only keys that work go here.
Row {
    id: cap
    property string key: ""
    property string label: ""
    spacing: 6
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        height: 20
        width: Math.max(20, keyText.implicitWidth + 10)
        radius: 6
        color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.92)
        border.width: 1
        border.color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.94)
        StyledText {
            id: keyText
            anchors.centerIn: parent
            text: cap.key
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Appearance.colors.colInkMain
        }
    }
    StyledText {
        visible: text !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: cap.label
        font.pixelSize: 12
        color: Appearance.colors.colInkSecondary
    }
}
