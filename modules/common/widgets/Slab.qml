import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// A button in Tacit's kit for decisions, in the installer's language (modules/setup Act/Quiet; the owner's go,
// 2026-10-08): a pill drawn as a ring, no fill at rest. `tone`: "default" (the way forward, Enter: a 1.5 px ring in
// the accent, its word in the main ink, Medium, and wider), "risk" (a quiet ring in the error colour, its word in
// that colour after a warning glyph) or "" (the quiet ring: 1 px of the main ink at 42 %, its word in the secondary
// ink). The item is always the forward ring's height, so rings of both kinds centre on one line. Hover and focus lift
// it with a faint neutral fill; the ring stays. Compact for app surfaces; `large` for a full-page moment. What the
// default does is said once under the row, by the page; the way forward sits on the right. Enter or Space picks it.
Item {
    id: slab
    property string text
    // kept for callers; rings draw no key cap
    property string key: ""
    property string tone: ""
    property bool large: false
    // kept for callers: a ring needs no surface to measure from
    property color on: Tacit.ground
    signal picked()

    readonly property bool accent: tone === "default"
    readonly property bool risky: tone === "risk"
    readonly property bool lifted: area.containsMouse || activeFocus
    readonly property color ink: accent ? Tacit.inkMain : risky ? Tacit.risk : lifted ? Tacit.inkMain : Tacit.inkSec
    readonly property int forwardHeight: large ? 50 : 40
    readonly property int quietHeight: large ? 44 : 36

    implicitWidth: accent ? Math.max(large ? 190 : 104, row.implicitWidth + (large ? 72 : 52)) : row.implicitWidth + (large ? 52 : 36)
    implicitHeight: forwardHeight
    activeFocusOnTab: true
    scale: area.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Keys.onReturnPressed: slab.picked()
    Keys.onEnterPressed: slab.picked()
    Keys.onSpacePressed: slab.picked()

    Rectangle {
        width: parent.width
        height: slab.accent ? slab.forwardHeight : slab.quietHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: ColorUtils.transparentize(Tacit.inkMain, slab.activeFocus ? 0.91 : area.containsMouse ? 0.95 : 1)
        border.width: slab.accent ? 1.5 : 1
        border.color: slab.accent ? ColorUtils.transparentize(Tacit.accent, 0.25)
                    : slab.risky ? ColorUtils.transparentize(Tacit.risk, 0.45)
                    : ColorUtils.transparentize(Tacit.inkMain, 0.58)
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        // a risk is said by its glyph too, not by colour alone
        MaterialSymbol {
            visible: slab.risky
            anchors.verticalCenter: word.verticalCenter
            text: "warning"
            iconSize: slab.large ? 17 : 15
            color: slab.ink
        }
        StyledText {
            id: word
            text: slab.text
            font.pixelSize: slab.accent && slab.large ? 17 : Tacit.size.row
            font.weight: slab.accent ? Font.Medium : Font.Normal
            color: slab.ink
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: slab.picked()
    }
}
