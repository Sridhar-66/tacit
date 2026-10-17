import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * What the message box's choices open in (agent, model and effort, mode, folder, attach, `/` and
 * `@`): a small plain menu above the box, on the rail menu's ground with one hairline, sized by
 * what it holds. `Line` is its row, shared with AgentChooser and ModelChooser; its sizes, type and
 * hover fill are RailMenu's.
 */
Rectangle {
    id: slab
    property bool open: false
    property color ground: Appearance.m3colors.m3surfaceContainerLow
    readonly property int pad: 4
    // it rises out of the box on the spatial curve as it fades in, and leaves faster than it came
    property real shown: slab.open ? 1 : 0
    Behavior on shown { Anim { type: slab.open ? Anim.DefaultEffects : Anim.FastEffects } }
    property real rise: slab.open ? 0 : 1
    Behavior on rise { Anim { type: slab.open ? Anim.FastSpatial : Anim.FastEffects } }
    // settled open: from here a change of size or place eases instead of jumping
    readonly property bool settled: slab.open && slab.shown === 1
    visible: slab.shown > 0
    opacity: slab.shown
    scale: 0.98 + 0.02 * (1 - slab.rise)
    transformOrigin: Item.BottomLeft
    transform: Translate { y: 8 * slab.rise }
    clip: true
    radius: Appearance.rounding.small
    color: slab.ground
    border.width: 1
    border.color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.9)

    // its own ground takes clicks and wheels: none reach the conversation under it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: w => w.accepted = true
    }

    // One row: a label, then what it needs beside it (`after`), at the right a detail, a step word
    // or the current one's check; `note` (or `why`, for a row that can't be used) on a second line.
    component Line: Item {
        id: ln
        property string label: ""
        property string after: ""          // beside the label, elided
        property bool middle: false        // elide `after` in the middle (paths)
        property string detail: ""         // at the right, in the numbers face
        property string note: ""
        property string why: ""            // why it can't be used: its note, and the label faint
        property string tail: ""           // a step word at the right
        property bool dot: false           // the 6 px colPrimary dot before the tail
        property bool on: false            // the current one
        property bool picked: false        // under the pointer or the keyboard
        property bool strong: false
        property bool still: false         // a fact, not a choice: no fill, no pointer
        property color ink: Appearance.colors.colInkMain
        readonly property bool inert: ln.why !== "" || ln.still
        readonly property string sub: ln.why !== "" ? ln.why : ln.note
        readonly property real rightW: (ln.on ? 22 : 0) + (ln.detail ? detailText.implicitWidth + 12 : 0) + (ln.tail ? tailRow.implicitWidth + 12 : 0)
        // the width this line asks for; past the menu's width the label and `after` elide
        readonly property real want: Math.max(10 + labelText.implicitWidth + (ln.after ? 10 + afterText.implicitWidth : 0) + ln.rightW + 10,
                                              ln.sub ? 10 + Math.min(subText.implicitWidth, 300) + 10 : 0)
        signal clicked()
        signal entered()
        implicitHeight: ln.sub ? 27 + subText.implicitHeight + 8 : 34

        // hover fades in, a press deepens it at once: the rail's fill
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: ln.inert ? "transparent"
                 : lnArea.pressed ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.88)
                 : ln.picked ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93) : ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 1)
            Behavior on color { enabled: !lnArea.pressed; ColorAnimation { duration: 110 } }
        }
        StyledText {
            id: labelText
            x: 10
            y: (34 - height) / 2
            width: Math.min(implicitWidth, ln.width - 20 - ln.rightW)
            text: ln.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Appearance.font.family.compact
            font.pixelSize: 15
            font.weight: ln.strong ? Font.DemiBold : Font.Normal
            color: ln.why !== "" ? Appearance.colors.colInkFaint : ln.ink
        }
        StyledText {
            id: afterText
            visible: ln.after !== "" && width > 12
            anchors { left: labelText.right; leftMargin: 10; verticalCenter: labelText.verticalCenter }
            width: Math.min(implicitWidth, ln.width - labelText.width - 30 - ln.rightW)
            text: ln.after
            textFormat: Text.PlainText
            elide: ln.middle ? Text.ElideMiddle : Text.ElideRight
            font.family: Appearance.font.family.compact
            font.pixelSize: 13
            color: Appearance.colors.colInkMeta
        }
        StyledText {
            id: detailText
            visible: ln.detail !== ""
            anchors { right: parent.right; rightMargin: 10 + (ln.on ? 22 : 0) + (ln.tail ? tailRow.implicitWidth + 12 : 0); verticalCenter: labelText.verticalCenter }
            text: ln.detail
            font.family: Appearance.font.family.numbers
            font.pixelSize: 13
            color: Appearance.colors.colInkMeta
        }
        Row {
            id: tailRow
            visible: ln.tail !== ""
            anchors { right: parent.right; rightMargin: 10 + (ln.on ? 22 : 0); verticalCenter: labelText.verticalCenter }
            spacing: 6
            Rectangle {
                visible: ln.dot
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: Appearance.colors.colPrimary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: ln.tail
                font.family: Appearance.font.family.compact
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Appearance.colors.colInkMain
            }
        }
        MaterialSymbol {
            visible: ln.on
            anchors { right: parent.right; rightMargin: 8; verticalCenter: labelText.verticalCenter }
            text: "check"
            iconSize: 18
            color: Appearance.colors.colInkMain
        }
        StyledText {
            id: subText
            visible: ln.sub !== ""
            x: 10
            y: 27
            width: ln.width - 20
            text: ln.sub
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Appearance.font.family.compact
            font.pixelSize: 13
            color: Appearance.colors.colInkMeta
        }
        MouseArea {
            id: lnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: ln.inert ? Qt.ArrowCursor : Qt.PointingHandCursor
            onEntered: if (!ln.inert) ln.entered()
            onClicked: if (!ln.inert) ln.clicked()
        }
    }
}
