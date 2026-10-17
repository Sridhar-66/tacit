import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.tacit

// What an edit changed, line by line, in the notch's way: tone on the text and the sign, a 2 px
// rail beside a changed line, no filled rows (filled at a low alpha they read as muddy grey on the
// warm window), unchanged context quiet. With startLine, the file's line numbers run down the left.
// An Edit gives both sides, a Write only the new text, a Codex apply_patch its own +/- lines under
// per-file headers.
Item {
    id: diff
    // Diff colours that read at a glance on the near-black panel, as Claude Desktop's do: the calm
    // palette's success/error containers are grey-greens that sank into it.
    // calm: Tacit's own reading for the side panel's trail - added lines on a sand tint with a sand
    // mark, removed ones dimmed, no green or red (owner, 2026-10-07: those read harsh and generic)
    property bool calm: false
    readonly property color addFill: diff.calm ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.91) : "#234A2D"
    readonly property color delFill: diff.calm ? ColorUtils.transparentize("#0c0a09", 0.72) : "#4E2428"
    readonly property color addInk: diff.calm ? Appearance.colors.colInkMain : "#E6F4E8"
    readonly property color delInk: diff.calm ? Appearance.colors.colInkFaint : "#FBE3E1"
    readonly property color addMark: diff.calm ? Appearance.colors.colPrimary : "#7BD88F"
    readonly property color delMark: diff.calm ? Appearance.colors.colInkFaint : "#F28B82"
    property var item: ({})
    // Review: a line can be commented on. startLine is the new file's line of the first row
    // (the hunk's start), so each row knows its line; a removed line reports where it was.
    property bool commentable: false
    property int startLine: 0
    signal commentRequested(int line, string text)
    // the file's line for each row of a patch (0 where there is none)
    function numbered(rows) {
        let n = diff.startLine;
        for (const r of rows) {
            if (r.kind === "same" || r.kind === "add") r.line = n++;
            else if (r.kind === "del") r.line = n;
            else r.line = 0;
        }
        return rows;
    }
    readonly property var rows: diff.numbered((() => {
        const it = diff.item;
        const out = [];
        if (it.patch) {
            for (const l of it.patch.split("\n")) {
                if (l.startsWith("*** Begin Patch") || l.startsWith("*** End Patch")) continue;
                const file = /^\*\*\* (Update|Add|Delete) File: (.*)$/.exec(l);
                if (file) out.push({ kind: "file", text: file[2] });
                else if (l.startsWith("@@")) out.push({ kind: "gap", text: l.substring(2).trim() });
                else if (l.startsWith("+")) out.push({ kind: "add", text: l.substring(1) });
                else if (l.startsWith("-")) out.push({ kind: "del", text: l.substring(1) });
                else out.push({ kind: "same", text: l.startsWith(" ") ? l.substring(1) : l });
            }
            return out;
        }
        const a = (it.old ?? "").length ? it.old.split("\n") : [];
        const b = (it.new ?? "").split("\n");
        let p = 0;
        while (p < a.length && p < b.length && a[p] === b[p]) p++;
        let q = 0;
        while (q < a.length - p && q < b.length - p && a[a.length - 1 - q] === b[b.length - 1 - q]) q++;
        for (const l of a.slice(Math.max(0, p - 2), p)) out.push({ kind: "same", text: l });
        for (const l of a.slice(p, a.length - q)) out.push({ kind: "del", text: l });
        for (const l of b.slice(p, b.length - q)) out.push({ kind: "add", text: l });
        for (const l of b.slice(b.length - q, Math.min(b.length, b.length - q + 2))) out.push({ kind: "same", text: l });
        return out;
    })())
    implicitHeight: Math.min(column.implicitHeight, 360)

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        // its own touchpad scroll, as the conversation has: Qt's leaves a pad's gesture to the
        // conversation under it, so a long Write could not be scrolled in place
        GlideWheel { view: flick; chain: true; gain: 1.6; gainPerSpeed: 3; gainMax: 6 }
        Column {
            id: column
            width: parent.width
            Repeater {
                model: diff.rows
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: column.width
                    height: Math.max(22, line.implicitHeight + 3)
                    HoverHandler { id: rowHover; enabled: diff.commentable && row.modelData.line > 0 }
                    MaterialSymbol {
                        visible: rowHover.hovered
                        z: 1
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: "add_comment"
                        iconSize: 15
                        color: commentArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
                        MouseArea { id: commentArea; anchors { fill: parent; margins: -4 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: diff.commentRequested(row.modelData.line, row.modelData.text) }
                    }
                    // filled as Claude Desktop draws a diff: the success container, a muted red
                    color: modelData.kind === "add" ? diff.addFill
                        : modelData.kind === "del" ? diff.delFill : "transparent"
                    Rectangle {
                        visible: modelData.kind === "add" || modelData.kind === "del"
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: modelData.kind === "add" ? diff.addMark : diff.delMark
                    }
                    StyledText {
                        id: number
                        visible: diff.startLine > 0
                        anchors { left: parent.left; top: parent.top; topMargin: 1 }
                        width: visible ? 40 : 0
                        horizontalAlignment: Text.AlignRight
                        text: modelData.line > 0 && modelData.kind !== "del" ? `${modelData.line}` : ""
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 13
                        color: Appearance.colors.colInkMeta
                    }
                    StyledText {
                        id: sign
                        anchors { left: number.right; leftMargin: 6; top: parent.top; topMargin: 1 }
                        width: 14
                        text: modelData.kind === "add" ? "+" : modelData.kind === "del" ? "−" : modelData.kind === "gap" ? "⋯" : ""
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 14
                        color: modelData.kind === "add" ? diff.addMark : modelData.kind === "del" ? diff.delMark : Appearance.colors.colInkSecondary
                    }
                    StyledText {
                        id: line
                        anchors { left: sign.right; leftMargin: 4; right: parent.right; rightMargin: diff.commentable ? 26 : 6; top: parent.top; topMargin: 1 }
                        text: modelData.text.length ? modelData.text : " "
                        wrapMode: Text.WrapAnywhere
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 14
                        font.weight: modelData.kind === "file" ? Font.DemiBold : Font.Normal
                        color: modelData.kind === "add" ? diff.addInk
                            : modelData.kind === "del" ? diff.delInk
                            : modelData.kind === "same" ? Appearance.colors.colInkSecondary : modelData.kind === "gap" ? Appearance.colors.colInkFaint : Appearance.colors.colInkMain
                    }
                }
            }
        }
    }
}
