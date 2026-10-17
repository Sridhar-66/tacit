pragma Singleton
import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Tacit's updates as the person sees them (2026-10-16, "like a Mac"): tacit-fetch-updates keeps the package list fresh
 * and downloads what is waiting (session/updates). Once all of it is here the notch says so once, with Tonight and
 * Restart, and the next start installs it (tacit-update). After that start the notch says how it went. Settings reads
 * the same state from updates.json.
 */
Singleton {
    id: root

    property bool available: true
    property alias checking: waitingProc.running
    property int count: 0
    property bool downloaded: false
    // Tacit's own new version when it is among them ("" when only other parts change)
    property string tacitVersion: ""
    property bool lastCheckFailed: false
    readonly property bool ready: root.count > 0 && root.downloaded
    // turned on in Settings: look now, not at the next half hour
    readonly property bool enabled: Config.options.updates.enableCheck
    onEnabledChanged: if (root.enabled) root.refresh()

    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    function load() {}
    function refresh() {
        if (!waitingProc.running)
            waitingProc.running = true;
    }
    // the next start installs them; no password (50-tacit-updates.rules)
    function restartNow() {
        Quickshell.execDetached(["bash", "-c", "systemctl start tacit-update@now.service && systemctl reboot"]);
    }
    function tonight() {
        Quickshell.execDetached(["systemctl", "start", "tacit-update@tonight.service"]);
        IslandController.request("copied", { "icon": "schedule", "text": "Tonight, on the charger" }, 65);
    }

    // a look two minutes after start (the night's result, and what the last download left) and every half hour
    Timer {
        interval: 2 * 60 * 1000
        running: Config.ready
        onTriggered: {
            resultFile.reload();
            root.refresh();
        }
    }
    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: Config.ready
        onTriggered: root.refresh()
    }

    Process {
        id: waitingProc
        // what is waiting ("name old -> new"), then where each of its files is: file:// once downloaded
        // (only where Tacit installs its updates itself, tacit-session's tacit-update: not on a computer set up by hand,
        // as the owner's Book4 with its held Qt)
        command: ["bash", "-c", "[ -x /usr/lib/tacit/tacit-update ] || { echo unmanaged; exit 0; }; pacman -Qu 2>/dev/null; echo ---; pacman -Sup --print-format %l 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "unmanaged") {
                    root.available = false;
                    return;
                }
                const halves = text.split("---\n");
                if (halves.length < 2) {
                    root.lastCheckFailed = true;
                    return;
                }
                root.lastCheckFailed = false;
                const waiting = halves[0].split("\n").filter(l => l.includes(" -> "));
                const files = halves[1].split("\n").filter(l => l.length > 0 && !l.startsWith(":"));
                root.count = waiting.length;
                root.downloaded = files.length > 0 && files.every(f => f.startsWith("file://"));
                const tacit = waiting.find(l => l.startsWith("tacit "));
                const ver = tacit ? tacit.split(" ") : [];
                // only a new Tacit release counts (1.4 over 1.3), not a rebuild of the same one
                root.tacitVersion = ver.length === 4 && ver[1].split("-")[0] !== ver[3].split("-")[0] ? ver[3].split("-")[0] : "";
                stateFile.setText(JSON.stringify({ "count": root.count, "ready": root.ready, "tacitVersion": root.tacitVersion }));
                if (root.ready)
                    root.announce(waiting.join("\n"));
            }
        }
    }

    // said once for each set of waiting updates
    FileView {
        id: announcedFile
        blockLoading: true
        path: `${Directories.userStateDir}/updates-announced`
        printErrors: false
    }
    function announce(key) {
        if (!Config.options.updates.enableCheck || announcedFile.text().trim() === key.trim())
            return;
        root.say("update", {
            "icon": "system_update",
            "text": root.tacitVersion.length > 0 ? `Tacit ${root.tacitVersion} is ready` : "Updates are ready"
        }, () => announcedFile.setText(key));
    }

    // A line waits until the notch can say it: it drops lines while the screen is locked, and the first look runs about
    // when the boot lock is still up (the VM install test: the result was marked said and never shown). Marked said only
    // once it is handed over.
    property var pending: []
    function say(name, data, mark) {
        root.pending = root.pending.filter(p => p.name !== name).concat([{ "name": name, "data": data, "mark": mark }]);
        root.flush();
    }
    function flush() {
        if (root.pending.length === 0 || !IslandController.enabled || IslandController.suppressed || !IslandController.warmedUp)
            return;
        if (!bootLockProc.running)
            bootLockProc.running = true;
    }
    // the boot lock is a program of its own, so the shell's own lock state misses it: a line handed over under it was
    // never seen (the VM test, "Updated"). It leaves martida-lock-ready once someone has signed in (bootlock.qml); [b] keeps pgrep off this very
    // command line.
    Process {
        id: bootLockProc
        command: ["bash", "-c", '[ -e "$XDG_RUNTIME_DIR/martida-lock-ready" ] || ! pgrep -f "[b]ootlock[.]qml" >/dev/null']
        onExited: (code, status) => {
            if (code !== 0 || root.pending.length === 0)
                return;
            const lines = root.pending;
            root.pending = [];
            for (const p of lines) {
                p.mark();
                IslandController.request(p.name, p.data, 60);
            }
        }
    }
    Timer {
        interval: 15000
        repeat: true
        running: root.pending.length > 0
        onTriggered: root.flush()
    }

    FileView {
        id: stateFile
        path: `${Directories.userStateDir}/updates.json`
        printErrors: false
    }

    // how the last install went (tacit-update install), said once
    FileView {
        id: resultFile
        path: "/var/lib/tacit/update-result"
        printErrors: false
        onLoaded: {
            let r = null;
            try {
                r = JSON.parse(resultFile.text());
            } catch (e) {
                return;
            }
            if (!r || `${r.at}` === seenFile.text().trim())
                return;
            if (r.ok && r.untouched) {
                seenFile.setText(`${r.at}`);
                return;     // there was nothing to install
            }
            // a failed one is offered again when it is downloaded again
            if (!r.ok)
                announcedFile.setText("");
            root.say("updated", {
                "icon": r.ok ? "check" : "error",
                "text": r.ok ? (r.version ? `Updated · Tacit ${r.version.split("-")[0]}` : "Updated")
                    : r.untouched ? "The update didn't install · nothing changed"
                    : "The update stopped partway · it tries again"
            }, () => seenFile.setText(`${r.at}`));
        }
    }
    FileView {
        id: seenFile
        blockLoading: true
        path: `${Directories.userStateDir}/updates-seen`
        printErrors: false
    }
}
