import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.tacit

/**
 * The agent menu's content: one line per account, with its facts and, when it needs one, the
 * step word. Choosing a ready line chooses that agent and account; a line with a step is chosen
 * too and opens AgentSteps under it, and the account turning ready chooses it again. Used by the
 * message box and the preferences sheet. Keys: ↑↓, Enter, Ctrl+Enter (choose and keep for the
 * folder), Esc.
 */
FocusScope {
    id: ch
    property var model: null           // AccountsModel
    property var current: ({ agent: "", account: "" })
    property string keepFolder: ""     // "" leaves out the keep line
    property bool setup: false
    property bool fixed: false         // only the current account (a started session's), on its step
    property real maxHeight: 420
    signal chosen(string agent, string account, bool keep)
    signal closed()
    signal settingsRequested(string anchor)

    readonly property string currentId: ch.current.account || (ch.model?.defaultAccount(ch.current.agent)?.id ?? "")
    // the line whose AgentSteps are open: "agent|account"
    property string expanded: ""
    property int pick: 0
    property bool inSteps: false       // the keyboard is in the open steps' choices

    // what the line says, per account the host knows (an agent with none has one line)
    readonly property var lines: {
        const m = ch.model;
        if (!m) return [];
        const out = [];
        for (const a of m.agentOrder) {
            if (!m.agents[a] || (ch.fixed && a !== ch.current.agent)) continue;
            const list = m.accountsOf(a);
            for (const x of (list.length ? list : [{ id: "", label: "" }])) {
                if (ch.fixed && x.id !== ch.currentId) continue;
                const step = m.stepOf(a, x.id);
                out.push({ agent: a, account: x.id, key: `${a}|${x.id}`,
                           label: m.agentName(a) + (list.length > 1 ? ` · ${x.label}` : ""),
                           note: m.factsOf(a, x.id), word: m.stepWord(step),
                           ready: step === "ready" || step === "",
                           on: a === ch.current.agent && x.id === ch.currentId });
            }
        }
        return out;
    }
    // the folder's kept agent and account are these
    readonly property bool kept: {
        const f = ch.model?.defaults?.folders?.[ch.keepFolder];
        if (!f || f.agent !== ch.current.agent) return false;
        const acct = f.run?.[ch.current.agent]?.account;
        return !acct || acct === ch.currentId;
    }
    readonly property bool showKeep: !ch.fixed && !ch.setup && ch.keepFolder.startsWith("/")
    readonly property string folderName: ch.keepFolder.split("/").filter(s => s.length).pop() ?? ""
    // lines, then the keep line and Settings: the keyboard walks them as one list
    readonly property int count: ch.lines.length + (ch.fixed ? 0 : (ch.showKeep ? 2 : 1))

    function reset() {
        const i = ch.lines.findIndex(l => l.on);
        ch.pick = Math.max(0, i);
        ch.inSteps = false;
        ch.expanded = ch.fixed && ch.lines.length ? ch.lines[0].key : "";
        flick.contentY = 0;
    }
    function openStep(agent, account) {
        const l = ch.lines.find(x => x.agent === agent && (!account || x.account === account)) ?? null;
        if (!l) return;
        ch.pick = ch.lines.indexOf(l);
        ch.expanded = l.ready ? "" : l.key;
    }
    function choose(i, keep) {
        if (i < ch.lines.length) {
            const l = ch.lines[i];
            ch.pick = i;
            ch.expanded = l.ready ? "" : l.key;
            ch.inSteps = false;
            if (!ch.fixed) ch.chosen(l.agent, l.account, keep);
        } else if (ch.showKeep && i === ch.lines.length) {
            ch.chosen(ch.current.agent, ch.currentId, true);
        } else {
            ch.settingsRequested("");
        }
    }
    function stepsAt(i) { return rows.itemAt(i)?.steps ?? null; }
    // the picked line, and its steps when open, scrolled into view
    function reveal() {
        const it = ch.pick < ch.lines.length ? rows.itemAt(ch.pick) : (ch.pick === ch.lines.length && ch.showKeep ? keepLine : settingsLine);
        if (!it || flick.height <= 0) return;
        const y = it.mapToItem(col, 0, 0).y, h = it.height;
        const max = Math.max(0, flick.contentHeight - flick.height);
        if (y + h > flick.contentY + flick.height) flick.contentY = Math.min(max, y + h - flick.height);
        if (y < flick.contentY) flick.contentY = Math.max(0, y);
    }
    onPickChanged: Qt.callLater(ch.reveal)
    onExpandedChanged: Qt.callLater(ch.reveal)
    function move(d) {
        const s = ch.stepsAt(ch.pick);
        if (ch.inSteps && s) {
            if (s.move(d)) return;
            ch.inSteps = false;
            if (d < 0) return;          // back up onto the line that holds them
        } else if (d > 0 && s && s.choices.length && s.move(1)) {
            ch.inSteps = true;
            return;
        }
        const next = Math.max(0, Math.min(ch.count - 1, ch.pick + d));
        if (d < 0 && next !== ch.pick) {
            const t = ch.stepsAt(next);
            if (t && t.choices.length && t.move(-1)) ch.inSteps = true;
        }
        ch.pick = next;
    }

    // the width the lines ask for, from their words (no frame at a guessed width)
    FontMetrics { id: big; font.family: Appearance.font.family.compact; font.pixelSize: 15 }
    FontMetrics { id: small; font.family: Appearance.font.family.compact; font.pixelSize: 13 }
    FontMetrics { id: num; font.family: Appearance.font.family.numbers; font.pixelSize: 13 }
    readonly property real want: {
        let w = ch.fixed ? 0 : 20 + big.advanceWidth("Accounts in Settings");
        if (ch.showKeep) w = Math.max(w, 20 + big.advanceWidth(`Use for new sessions in ${ch.folderName}`) + 12 + num.advanceWidth("Ctrl+↵"));
        for (const l of ch.lines)
            w = Math.max(w, 20 + big.advanceWidth(l.label) + (l.word ? 24 + small.advanceWidth(l.word) : 0) + (l.on ? 22 : 0),
                         20 + Math.min(small.advanceWidth(l.note), 300));
        return Math.ceil(w);
    }
    implicitWidth: Math.max(ch.want, ch.expanded ? 300 : 0)
    implicitHeight: Math.min(col.implicitHeight, ch.maxHeight)

    Keys.onPressed: e => {
        e.accepted = true;
        if (e.key === Qt.Key_Escape) ch.closed();
        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) ch.move(1);
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) ch.move(-1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            const s = ch.stepsAt(ch.pick);
            if (ch.inSteps && s) s.activate();
            else ch.choose(ch.pick, (e.modifiers & Qt.ControlModifier) !== 0);
        } else e.accepted = false;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight
        interactive: contentHeight > height + 1
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds
        GlideWheel { view: flick; gain: 1.6; gainPerSpeed: 3; gainMax: 6 }
        Column {
            id: col
            width: flick.width
            Repeater {
                id: rows
                // by count: a state push rebuilds `lines`, and rebuilt rows would drop the open
                // steps' sign-in in progress
                model: ch.lines.length
                delegate: Column {
                    id: row
                    required property int index
                    readonly property var modelData: ch.lines[row.index] ?? ({ key: "", label: "", note: "", word: "", on: false })
                    readonly property var steps: stepsLoader.item
                    width: col.width
                    onHeightChanged: if (ch.pick === row.index) Qt.callLater(ch.reveal)
                    BoxShape.Line {
                        id: line
                        width: parent.width
                        label: row.modelData.label
                        note: row.modelData.note
                        tail: row.modelData.word
                        dot: row.modelData.word !== ""
                        on: row.modelData.on
                        picked: ch.pick === row.index && !ch.inSteps
                        onEntered: { ch.pick = row.index; ch.inSteps = false; }
                        onClicked: ch.choose(row.index, false)
                    }
                    Loader {
                        id: stepsLoader
                        active: ch.expanded === row.modelData.key
                        width: parent.width
                        height: stepsLoader.item ? stepsLoader.item.implicitHeight : 0   // an unloaded Loader keeps its last height
                        sourceComponent: AgentSteps {
                            width: row.width
                            model: ch.model
                            agent: row.modelData.agent
                            account: row.modelData.account
                            setup: ch.setup
                            inset: 10
                            onSettingsRequested: anchor => ch.settingsRequested(anchor)
                            onDone: ch.fixed ? ch.closed() : ch.chosen(row.modelData.agent, row.modelData.account, false)
                        }
                    }
                }
            }
            Item {
                visible: !ch.fixed
                width: parent.width
                height: 9
                Rectangle { x: 8; y: 4; width: parent.width - 16; height: 1; color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.9) }
            }
            BoxShape.Line {
                id: keepLine
                visible: ch.showKeep
                width: parent.width
                label: ch.kept ? `The default in ${ch.folderName}` : `Use for new sessions in ${ch.folderName}`
                detail: ch.kept ? "" : "Ctrl+↵"
                still: ch.kept
                ink: ch.kept ? Appearance.colors.colInkMeta : Appearance.colors.colInkSecondary
                picked: ch.pick === ch.lines.length
                onEntered: { ch.pick = ch.lines.length; ch.inSteps = false; }
                onClicked: ch.choose(ch.lines.length, true)
            }
            BoxShape.Line {
                id: settingsLine
                visible: !ch.fixed
                width: parent.width
                label: "Accounts in Settings"
                ink: Appearance.colors.colInkSecondary
                picked: ch.pick === ch.count - 1
                onEntered: { ch.pick = ch.count - 1; ch.inSteps = false; }
                onClicked: ch.choose(ch.count - 1, false)
            }
        }
    }
}
