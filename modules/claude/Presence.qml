import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * What is open on the desktop, for the folders' live marks and "Open here": terminal, Graphis
 * and Pinax windows with their folders, and the agents running here (scripts/praxis/presence.sh).
 * Polls every 15 s while `running`, and on refresh(). A result that changed only window titles
 * or focus order assigns nothing (take()).
 * Focus goes by exact address; unknown windows and special workspaces are refused. With `dryRun`
 * the dispatch and the Graphis call are recorded in `lastDispatch` instead of run.
 * The root is a Scope, not an Item: Item's `focus` property would hide focus().
 */
Scope {
    id: pres

    property bool running: false
    property int pollInterval: 15000
    property var windows: []
    property var agents: []
    property bool dryRun: false
    property string lastDispatch: ""

    readonly property string script: Quickshell.shellPath("scripts/praxis/presence.sh")
    readonly property string codeQml: `${Quickshell.env("HOME")}/.config/quickshell/tacit/code.qml`
    property string seenWindows: "[]"
    property string seenAgents: "[]"

    function refresh() {
        if (!proc.running)
            proc.running = true;
    }

    // true when the window is known and not on a special workspace
    function focus(address) {
        const w = pres.windows.find(x => x.address === address);
        if (!w || w.special)
            return false;
        const d = `hl.dsp.focus({ window = "address:${w.address}" })`;
        if (pres.dryRun)
            pres.lastDispatch = d;
        else
            Hyprland.dispatch(d);
        return true;
    }
    // Focuses Graphis, then opens `rel` (relative to its root) in it.
    function openGraphis(rel) {
        const g = pres.windows.find(x => x.kind === "graphis" && !x.special);
        if (!g || !pres.focus(g.address))
            return false;
        const cmd = ["qs", "-p", pres.codeQml, "ipc", "call", "code", "file", rel];
        if (pres.dryRun)
            pres.lastDispatch += "\n" + cmd.join(" ");
        else
            Quickshell.execDetached(cmd);
        return true;
    }

    // windows is reassigned only when a window, folder, program, workspace or Graphis doc changed.
    // Title and focus change on their own (Claude animates its terminal title) and are written
    // into the current objects without a notify.
    function take(text) {
        let o;
        try { o = JSON.parse(text); } catch (e) { return; }
        const windows = o?.windows ?? [], agents = o?.agents ?? [];
        const w = JSON.stringify(windows, (k, v) => k === "title" || k === "focus" ? undefined : v);
        const a = JSON.stringify(agents);
        if (w !== pres.seenWindows) {
            pres.seenWindows = w;
            pres.windows = windows;
        } else {
            const cur = pres.windows;
            windows.forEach((x, i) => {
                cur[i].title = x.title;
                cur[i].focus = x.focus;
            });
        }
        if (a !== pres.seenAgents) {
            pres.seenAgents = a;
            pres.agents = agents;
        }
    }

    Process {
        id: proc
        command: ["bash", pres.script]
        stdout: StdioCollector {
            onStreamFinished: pres.take(this.text)
        }
    }
    Timer {
        running: pres.running
        interval: pres.pollInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: pres.refresh()
    }
}
