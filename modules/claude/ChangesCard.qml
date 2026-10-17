import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * What one turn changed, at its end: files edited with their line counts, View changes (the
 * Review panel) and, on the newest turn, Undo, which puts those files back as they were before
 * the turn (Claude Code's rewind_files; the conversation stays). Undo asks once before it acts.
 */
Rectangle {
    id: card
    property var files: []            // [{ path, add, del }]
    property int add: 0
    property int del: 0
    property string cwd: ""
    property bool canUndo: false
    property bool open: false
    property string undo: ""          // "" | "ask" | "busy" | "done"
    signal viewChanges()
    signal undoAsked(var done)        // done(ok)

    readonly property var shown: card.open ? card.files : card.files.slice(0, 3)
    function rel(p) {
        const home = Quickshell.env("HOME");
        if (card.cwd.length && p.startsWith(card.cwd + "/")) return p.substring(card.cwd.length + 1);
        return p.startsWith(home + "/") ? "~" + p.substring(home.length) : p;
    }

    implicitHeight: head.height + list.implicitHeight + (more.visible ? more.height : 0) + 14
    radius: 18
    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95)

    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 10 }
        height: 46
        MaterialSymbol { id: glyph; anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: card.undo === "done" ? "undo" : "edit_note"; iconSize: 17; color: Appearance.colors.colInkSecondary }
        StyledText {
            id: title
            anchors { left: glyph.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: card.undo === "done" ? "Changes undone" : `Edited ${card.files.length} ${card.files.length === 1 ? "file" : "files"}`
            font.pixelSize: 15
            font.weight: Font.Medium
            color: Appearance.colors.colInkMain
        }
        Row {
            anchors { left: title.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
            visible: card.undo !== "done"
            spacing: 6
            StyledText { text: `+${card.add}`; visible: card.add > 0; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: Appearance.m3colors.m3success }
            StyledText { text: `−${card.del}`; visible: card.del > 0; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: Appearance.m3colors.m3error }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            PillButton {
                visible: card.canUndo && card.undo !== "done"
                text: card.undo === "ask" ? `Undo ${card.files.length === 1 ? "this file" : card.files.length + " files"}?` : card.undo === "busy" ? "Undoing…" : "Undo"
                onClicked: {
                    if (card.undo === "") card.undo = "ask";
                    else if (card.undo === "ask") {
                        card.undo = "busy";
                        card.undoAsked(ok => card.undo = ok ? "done" : "");
                    }
                }
            }
            PillButton { text: "View changes"; onClicked: card.viewChanges() }
        }
    }
    Column {
        id: list
        anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 14; rightMargin: 14 }
        Repeater {
            model: card.shown
            Item {
                required property var modelData
                width: list.width
                height: 28
                StyledText {
                    anchors { left: parent.left; right: nums.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideMiddle
                    textFormat: Text.StyledText
                    // the folder quiet, the file name in full tone
                    text: {
                        const r = card.rel(modelData.path);
                        const cut = r.lastIndexOf("/");
                        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                        return cut < 0 ? esc(r) : `<font color="${Appearance.colors.colInkSecondary}">${esc(r.substring(0, cut + 1))}</font>${esc(r.substring(cut + 1))}`;
                    }
                    font.pixelSize: 14
                    color: Appearance.colors.colInkMain
                }
                Row {
                    id: nums
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    StyledText { text: `+${modelData.add}`; visible: modelData.add > 0; font.family: Appearance.font.family.numbers; font.pixelSize: 13; color: Appearance.m3colors.m3success }
                    StyledText { text: `−${modelData.del}`; visible: modelData.del > 0; font.family: Appearance.font.family.numbers; font.pixelSize: 13; color: Appearance.m3colors.m3error }
                }
            }
        }
    }
    Item {
        id: more
        visible: card.files.length > 3
        anchors { left: parent.left; right: parent.right; top: list.bottom; leftMargin: 14 }
        height: 30
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            StyledText {
                text: card.open ? "Show fewer" : `Show ${card.files.length - 3} more ${card.files.length - 3 === 1 ? "file" : "files"}`
                font.pixelSize: 14
                color: moreArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            MaterialSymbol { text: card.open ? "expand_less" : "expand_more"; iconSize: 16; color: Appearance.colors.colInkSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: moreArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.open = !card.open }
    }
}
