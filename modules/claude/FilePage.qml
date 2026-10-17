import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * A file on the trail, with the panel widened for it: its name and folder, how much changed, then each
 * edit to it as its whole diff, marked with the agent and step that made it (a mark goes to that step).
 * The edits are those of the agents whose steps the panel has read, the one you came from first.
 * Open the file shows it in Files.
 */
PanelPage {
    id: fp
    bodyHeight: col.implicitHeight
    readonly property var p: fp.pane
    readonly property string path: fp.entry.id ?? ""
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string from: fp.entry.f.from ?? ""

    // every read edit to this file: { agent, name, i, item, add, del }
    readonly property var edits: {
        const out = [];
        const ids = Object.keys(fp.p.stepsBy).sort((x, y) => (y === fp.from) - (x === fp.from));
        for (const id of ids) {
            const a = fp.p.findAgent(fp.p.info, id);
            let i = -1;
            for (const it of fp.p.stepsBy[id]?.items ?? []) {
                if (it.kind !== "tool") continue;
                i++;
                const f = (it.files ?? []).find(x => x.path === fp.path);
                if (!f) continue;
                out.push({ agent: id, name: a?.description || a?.label || "Agent", i: i, item: it, add: f.add ?? 0, del: f.del ?? 0 });
            }
        }
        return out;
    }
    readonly property int adds: fp.edits.reduce((n, e) => n + e.add, 0)
    readonly property int dels: fp.edits.reduce((n, e) => n + e.del, 0)
    readonly property int agentCount: new Set(fp.edits.map(e => e.agent)).size

    component Quiet: Item {
        id: q
        property string text: ""
        property string glyph: ""
        signal clicked()
        width: qRow.implicitWidth + 16
        height: 30
        Rectangle { anchors.fill: parent; radius: 8; color: qArea.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.94) : "transparent" }
        Row {
            id: qRow
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            MaterialSymbol { visible: q.glyph.length > 0; anchors.verticalCenter: parent.verticalCenter; text: q.glyph; iconSize: 16; color: Appearance.colors.colInkSecondary }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: q.text; font.pixelSize: 15; color: Appearance.colors.colInkSecondary }
        }
        MouseArea { id: qArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: q.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 4
        StyledText {
            width: parent.width
            topPadding: 6
            wrapMode: Text.Wrap
            text: fp.path.split("/").pop()
            font.pixelSize: 24
            font.weight: Font.DemiBold
            color: Appearance.colors.colInkMain
        }
        StyledText {
            width: parent.width
            elide: Text.ElideMiddle
            text: fp.path.split("/").slice(0, -1).join("/").split(fp.home).join("~")
            font.pixelSize: 14
            color: Appearance.colors.colInkMeta
        }
        Row {
            spacing: 6
            StyledText { visible: fp.adds > 0; text: `+${fp.adds}`; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: "#7BD88F" }
            StyledText { visible: fp.dels > 0; text: `−${fp.dels}`; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: "#F28B82" }
            StyledText {
                text: `· ${fp.edits.length} ${fp.edits.length === 1 ? "edit" : "edits"}${fp.agentCount > 1 ? ` by ${fp.agentCount} agents` : ""}`
                font.pixelSize: 14
                color: Appearance.colors.colInkMeta
            }
        }
        Row {
            x: -8
            topPadding: 6
            Quiet { glyph: "description"; text: "Open the file"; onClicked: { if (fp.p.files) fp.p.files.openFile(fp.path, 0, ""); } }
        }
        Repeater {
            model: fp.edits
            Column {
                id: ed
                required property var modelData
                required property int index
                width: col.width
                topPadding: 14
                spacing: 6
                // who made it: goes to that step
                Item {
                    width: parent.width
                    height: 24
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        StyledText { text: ed.modelData.name; font.pixelSize: 14; color: markArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary }
                        StyledText { text: `step ${ed.modelData.i + 1}`; font.pixelSize: 14; font.features: { "tnum": 1 }; color: Appearance.colors.colInkFaint }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        StyledText { visible: ed.modelData.add > 0; text: `+${ed.modelData.add}`; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: "#7BD88F" }
                        StyledText { visible: ed.modelData.del > 0; text: `−${ed.modelData.del}`; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: "#F28B82" }
                    }
                    MouseArea { id: markArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fp.p.openStep(ed.modelData.agent, ed.modelData.i) }
                }
                Item {
                    width: parent.width
                    height: dv.implicitHeight
                    Rectangle { anchors.fill: parent; radius: 10; color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.96) }
                    DiffView { id: dv; width: parent.width; item: ed.modelData.item }
                }
            }
        }
    }
}
