import QtQuick
import Quickshell
import Quickshell.Io

/**
 * One language server for one project, through scripts/code/lsp-bridge.py (a JSON message per line each way).
 * Started when the first file of its language opens; what is sent before the server has answered `initialize`
 * waits in order. Requests carry a callback; the server's diagnostics come out as a signal.
 */
Item {
    id: srv

    required property var command          // the server, e.g. ["/usr/lib/qt6/bin/qmlls"]
    required property string root          // the project folder
    property bool ready: false
    property bool dead: false
    property var queue: []
    property var waiting: ({})              // request id -> callback
    property int nextId: 1
    signal diagnostics(string uri, var list)

    function uriOf(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/"); }
    function pathOf(uri) { return decodeURIComponent(String(uri).replace(/^file:\/\//, "")); }

    function write(msg) {
        if (srv.dead) return;
        if (!srv.ready && msg.method !== "initialize") { srv.queue.push(msg); return; }
        proc.write(JSON.stringify(msg) + "\n");
    }
    function notify(method, params) { srv.write({ method: method, params: params }); }
    function request(method, params, cb) {
        const id = srv.nextId++;
        if (cb) { const w = Object.assign({}, srv.waiting); w[id] = cb; srv.waiting = w; }
        srv.write({ id: id, method: method, params: params });
        return id;
    }

    Process {
        id: proc
        workingDirectory: srv.root
        command: ["python3", Quickshell.shellPath("scripts/code/lsp-bridge.py")].concat(srv.command)
        stdinEnabled: true
        running: true
        stdout: SplitParser {
            onRead: data => {
                let m;
                try { m = JSON.parse(data); } catch (e) { return; }
                if (m.bridge === "exit") { srv.dead = true; return; }
                if (m.id !== undefined && srv.waiting[m.id]) {
                    const cb = srv.waiting[m.id];
                    const w = Object.assign({}, srv.waiting); delete w[m.id]; srv.waiting = w;
                    cb(m.result ?? null, m.error ?? null);
                } else if (m.method === "textDocument/publishDiagnostics") {
                    srv.diagnostics(m.params.uri, m.params.diagnostics || []);
                }
            }
        }
        onExited: srv.dead = true
    }

    Component.onCompleted: {
        const uri = srv.uriOf(srv.root);
        srv.request("initialize", {
            processId: null,
            rootUri: uri,
            workspaceFolders: [{ uri: uri, name: srv.root.split("/").pop() }],
            capabilities: {
                textDocument: {
                    synchronization: { didSave: true },
                    publishDiagnostics: {},
                    completion: { completionItem: { snippetSupport: false, documentationFormat: ["plaintext"] } },
                    definition: {}
                },
                workspace: { configuration: true, workspaceFolders: true }
            }
        }, () => {
            proc.write(JSON.stringify({ method: "initialized", params: {} }) + "\n");
            srv.ready = true;
            const q = srv.queue; srv.queue = [];
            for (const m of q) proc.write(JSON.stringify(m) + "\n");
        });
    }
    Component.onDestruction: if (!srv.dead) { proc.write(JSON.stringify({ id: 0, method: "shutdown" }) + "\n"); proc.write(JSON.stringify({ method: "exit" }) + "\n"); }
}
