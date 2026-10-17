pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs

/**
 * The shell's half of the system dialogs. tacit-portal listens on $XDG_RUNTIME_DIR/tacit-dialogs.sock
 * and brokers every request for a dialog (keyring, share picker, open with, ...); this connects as the
 * "ui", queues what arrives and answers. Protocol: ~/dev/tacit-portal/DIALOGS.md.
 *
 * Each dialog builder owns the sheet for its kinds: show it while `current.kind` is yours and
 * `asking` is true, then call answer(id, result) or refuse(id, reason). Nothing is answered here.
 * The portal rejects an ask at once when this is not connected, and rejects everything we still
 * held if we go away, so a caller is never left waiting on a dead shell.
 */
Singleton {
    id: root

    // Waiting asks, oldest first: { id, kind, params, t }. Only the first is shown.
    property var queue: []
    readonly property var current: root.queue.length > 0 ? root.queue[0] : null
    // Dialogs wait while the screen is locked: a sheet must not sit behind or over the lock.
    readonly property bool asking: root.current !== null && !GlobalStates.screenLocked
    readonly property bool connected: root.link?.connected ?? false

    // Kinds a loaded sheet answers: each sheet claims its kinds when it loads. An ask for a kind nobody claims
    // (sheet not installed, failed to load, older shell) is rejected "unsupported" after a short grace for startup,
    // so the portal call falls back instead of hanging.
    property var claimed: ({})
    function claim(kind: string): void {
        const c = Object.assign({}, root.claimed);
        c[kind] = (c[kind] ?? 0) + 1;
        root.claimed = c;
    }
    function unclaim(kind: string): void {
        const c = Object.assign({}, root.claimed);
        if ((c[kind] ?? 0) > 1) c[kind]--;
        else delete c[kind];
        root.claimed = c;
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.queue.some(a => !root.claimed[a.kind])
        onTriggered: {
            const now = Date.now();
            for (const a of root.queue.filter(a => !root.claimed[a.kind] && now - a.t > 3000))
                root.refuse(a.id, "unsupported");
        }
    }

    // Quickshell's Socket does not try again after a failed connect (setting `connected` false and
    // back to true does nothing), so a socket that is not connected is rebuilt until tacit-portal
    // answers. The portal is D-Bus activated, so it may start after the shell.
    property int gen: 0
    property var link: null
    Instantiator {
        model: [root.gen]
        delegate: Socket {
            path: Quickshell.env("TACIT_DIALOGS_SOCK") || `${Quickshell.env("XDG_RUNTIME_DIR")}/tacit-dialogs.sock`
            connected: true
            parser: SplitParser {
                onRead: line => root.receive(line)
            }
            onConnectedChanged: {
                if (connected) {
                    write(`${JSON.stringify({ op: "hello", role: "ui", proto: 1 })}\n`);
                    flush();
                } else {
                    // the portal went away: it has rejected these for their callers already
                    root.queue = [];
                }
            }
        }
        onObjectAdded: (index, object) => root.link = object
        onObjectRemoved: (index, object) => {
            if (root.link === object) root.link = null;
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: !root.connected
        onTriggered: root.gen++
    }

    function receive(line: string): void {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.op === "ask") {
            root.queue = root.queue.concat([{ id: m.id, kind: m.kind, params: m.params ?? {}, t: Date.now() }]);
        } else if (m.op === "cancel") {
            root.queue = root.queue.filter(a => a.id !== m.id);
        }
    }

    function send(o: var): void {
        if (!root.connected) return;
        root.link.write(`${JSON.stringify(o)}\n`);
        root.link.flush();
    }

    function answer(id: string, result: var): void {
        root.queue = root.queue.filter(a => a.id !== id);
        root.send({ op: "answer", id: id, result: result ?? {} });
    }

    // `reason` is what the caller is told: "cancelled" for a dismissed sheet, "refused" for an explicit no.
    function refuse(id: string, reason: string): void {
        root.queue = root.queue.filter(a => a.id !== id);
        root.send({ op: "reject", id: id, reason: reason || "cancelled" });
    }
}
