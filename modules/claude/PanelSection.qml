import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * A section's name on the side panel's pages, with how many it holds, and at its right what the
 * section offers (Copy, or a progress bar put in `trailing`): one step below the page title and one
 * above the rows, in weight rather than in a fainter ink (the panel stands on glass, where a faint
 * ink fades into a bright wallpaper), with room above it so a section starts visibly.
 */
Item {
    id: sec
    property string text: ""
    property int count: -1            // shown after the name when 0 or more
    property string actionText: ""    // a quiet action at the right
    property string actionGlyph: ""
    property alias trailing: trail.data
    signal action()
    property int topPadding: 28
    width: parent ? parent.width : 0
    implicitHeight: topPadding + 22 + 8
    Row {
        y: sec.topPadding
        height: 22
        spacing: 8
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: sec.text
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Appearance.colors.colInkSecondary
        }
        StyledText {
            visible: sec.count >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: sec.count
            font.pixelSize: 14
            font.features: { "tnum": 1 }
            color: Appearance.colors.colInkMeta
        }
    }
    Item {
        id: trail
        anchors { right: parent.right; top: parent.top; topMargin: sec.topPadding }
        width: childrenRect.width
        height: 22
    }
    Item {
        visible: sec.actionText.length > 0
        anchors { right: parent.right; rightMargin: -8; top: parent.top; topMargin: sec.topPadding - 4 }
        width: actRow.implicitWidth + 16
        height: 30
        Rectangle { anchors.fill: parent; radius: 8; color: actArea.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.94) : "transparent" }
        Row {
            id: actRow
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            MaterialSymbol { visible: sec.actionGlyph.length > 0; anchors.verticalCenter: parent.verticalCenter; text: sec.actionGlyph; iconSize: 16; color: Appearance.colors.colInkSecondary }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: sec.actionText; font.pixelSize: 14; color: actArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary }
        }
        MouseArea { id: actArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sec.action() }
    }
}
