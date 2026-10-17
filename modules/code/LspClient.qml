import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Language smarts for one project: which server speaks which file, started when a file of its kind opens, and
 * what the servers say back, kept per file. Only servers that are installed are used; a file whose language
 * has none is plain text with nothing missing on screen (Tacit shows no plumbing).
 */
Item {
    id: lsp

    property string root: ""
    // kind -> the first installed server of the list (found at start)
    readonly property var table: [
        { kind: "qml", match: /\.qml$/i, id: () => "qml", servers: [["/usr/lib/qt6/bin/qmlls"], ["qmlls"]] },
        { kind: "c", match: /\.(c|h|cc|cpp|cxx|hpp|hh|hxx)$/i, id: p => /\.(c|h)$/i.test(p) ? "c" : "cpp", servers: [["clangd", "--background-index=false", "--log=error"]] },
        { kind: "python", match: /\.pyi?$/i, id: () => "python", servers: [["basedpyright-langserver", "--stdio"], ["pyright-langserver", "--stdio"], ["pylsp"], ["jedi-language-server"]] },
        { kind: "ts", match: /\.(js|jsx|mjs|cjs|ts|tsx)$/i, id: p => /\.tsx$/i.test(p) ? "typescriptreact" : /\.ts$/i.test(p) ? "typescript" : /\.jsx$/i.test(p) ? "javascriptreact" : "javascript", servers: [["typescript-language-server", "--stdio"]] },
        { kind: "rust", match: /\.rs$/i, id: () => "rust", servers: [["rust-analyzer"]] },
        { kind: "go", match: /\.go$/i, id: () => "go", servers: [["gopls"]] },
        { kind: "kotlin", match: /\.kts?$/i, id: () => "kotlin", servers: [["kotlin-language-server"]] },
        { kind: "shell", match: /\.(sh|bash)$/i, id: () => "shellscript", servers: [["bash-language-server", "start"]] }
    ]
    property var installed: ({})            // kind -> command
    property var servers: ({})              // kind -> LspServer
    property var problems: ({})             // path -> [diagnostic]
    property int problemsTick: 0
    property var versions: ({})             // path -> version sent
    signal serversKnown()                   // files opened before this are announced again

    function kindOf(path) { return lsp.table.find(t => t.match.test(path)) ?? null; }
    function serverFor(path) {
        const t = lsp.kindOf(path);
        if (!t || !lsp.installed[t.kind] || !lsp.root.length) return null;
        if (!lsp.servers[t.kind]) {
            const s = serverComp.createObject(lsp, { command: lsp.installed[t.kind], root: lsp.root });
            s.diagnostics.connect((uri, list) => {
                const p = Object.assign({}, lsp.problems); p[s.pathOf(uri)] = list; lsp.problems = p; lsp.problemsTick++;
            });
            const m = Object.assign({}, lsp.servers); m[t.kind] = s; lsp.servers = m;
        }
        return lsp.servers[t.kind];
    }
    function speaks(path) { const t = lsp.kindOf(path); return !!t && !!lsp.installed[t.kind]; }

    // the file's life, as the server hears it
    function opened(path, text) {
        const s = lsp.serverFor(path);
        if (!s) return;
        const v = Object.assign({}, lsp.versions); v[path] = 1; lsp.versions = v;
        s.notify("textDocument/didOpen", { textDocument: { uri: s.uriOf(path), languageId: lsp.kindOf(path).id(path), version: 1, text: text } });
    }
    function changed(path, text) {
        const s = lsp.serverFor(path);
        if (!s || !lsp.versions[path]) return;
        const v = Object.assign({}, lsp.versions); v[path] = v[path] + 1; lsp.versions = v;
        s.notify("textDocument/didChange", { textDocument: { uri: s.uriOf(path), version: v[path] }, contentChanges: [{ text: text }] });
    }
    function saved(path) { const s = lsp.serverFor(path); if (s && lsp.versions[path]) s.notify("textDocument/didSave", { textDocument: { uri: s.uriOf(path) } }); }
    function closed(path) {
        const s = lsp.servers[lsp.kindOf(path)?.kind ?? ""];
        if (!s || !lsp.versions[path]) return;
        s.notify("textDocument/didClose", { textDocument: { uri: s.uriOf(path) } });
        const v = Object.assign({}, lsp.versions); delete v[path]; lsp.versions = v;
        const p = Object.assign({}, lsp.problems); delete p[path]; lsp.problems = p; lsp.problemsTick++;
    }

    // questions: where is this defined, what could go here
    function definition(path, line, character, cb) {
        const s = lsp.serverFor(path);
        if (!s) { cb(null); return; }
        s.request("textDocument/definition", { textDocument: { uri: s.uriOf(path) }, position: { line: line, character: character } }, r => {
            const loc = Array.isArray(r) ? r[0] : r;
            if (!loc) { cb(null); return; }
            const uri = loc.targetUri ?? loc.uri, range = loc.targetSelectionRange ?? loc.range;
            cb({ path: s.pathOf(uri), line: range.start.line, character: range.start.character });
        });
    }
    function complete(path, line, character, cb) {
        const s = lsp.serverFor(path);
        if (!s) { cb([]); return; }
        s.request("textDocument/completion", { textDocument: { uri: s.uriOf(path) }, position: { line: line, character: character } }, r => {
            cb(Array.isArray(r) ? r : (r?.items ?? []));
        });
    }

    // a new project: the old servers go, the new project's start as its files open
    onRootChanged: {
        for (const k in lsp.servers) lsp.servers[k].destroy();
        lsp.servers = ({}); lsp.problems = ({}); lsp.versions = ({}); lsp.problemsTick++;
    }

    // which servers are on this computer: asked once, at start
    Process {
        running: true
        command: ["sh", "-c", 'for c in "$@"; do command -v "$c" >/dev/null 2>&1 && echo "$c"; done', "sh"].concat(
            lsp.table.reduce((a, t) => a.concat(t.servers.map(s => s[0])), []))
        stdout: StdioCollector {
            onStreamFinished: {
                const found = this.text.split("\n").filter(l => l.length);
                const m = {};
                for (const t of lsp.table) {
                    const s = t.servers.find(s => found.includes(s[0]));
                    if (s) m[t.kind] = s;
                }
                lsp.installed = m;
                lsp.serversKnown();
            }
        }
    }

    Component { id: serverComp; LspServer {} }
}
