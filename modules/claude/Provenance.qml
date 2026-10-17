import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * Where a dropped file came from, in one plain line: "report.pdf — downloaded from Opsis, page
 * 'Q3 report', 2h ago". Reads Files' origins index (read only; Praxis never loads the Origins
 * singleton, which writes it) and Opsis's own download records, because origins keeps Opsis's
 * downloads with an empty app. Both files are watched; each is parsed only when a line is asked
 * for after it changed.
 */
Item {
    id: prov
    visible: false

    property string originsPath: `${Directories.state}/user/files/origins.json`
    property string threadsPath: `${FileUtils.trimFileProtocol(Directories.home)}/.local/share/browser/threads.json`

    // "report.pdf — downloaded from Opsis, page 'X', 2h ago", or "" when nothing is known
    function describe(path) {
        const p = prov.pathOf(path);
        return p ? prov.line(p, prov.nameOf(p)) : "";
    }
    function lines(paths) {
        return (paths ?? []).map(p => prov.describe(p)).filter(l => l.length > 0);
    }
    // The notch's block (services/Claude.qml), one line per known file, led by its full path;
    // "" when none is known. The caller puts it after the message, as the notch does.
    function contextBlock(paths) {
        const out = (paths ?? []).map(x => {
            const p = prov.pathOf(x);
            return p ? prov.line(p, p) : "";
        }).filter(l => l.length > 0);
        return out.length ? `<desktop-context>\n${out.join("\n")}\n</desktop-context>` : "";
    }

    // ── reading ─────────────────────────────────────────────────────────────
    property var originsIndex: null     // path -> {kind, app, title, device, session, at}
    property var downloadsIndex: null   // path -> {title, url, at}: Opsis's newest record of it

    FileView {
        id: originsFile
        path: prov.originsPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: prov.originsIndex = null
    }
    FileView {
        id: threadsFile
        path: prov.threadsPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: prov.downloadsIndex = null
    }

    function origins() {
        if (prov.originsIndex === null) {
            let idx = {};
            try { const d = JSON.parse(originsFile.text() || "{}"); idx = d.index ?? d; } catch (e) {}
            prov.originsIndex = idx;
        }
        return prov.originsIndex;
    }
    function downloads() {
        if (prov.downloadsIndex === null) {
            const by = {};
            try {
                for (const d of JSON.parse(threadsFile.text() || "{}").downloads ?? []) {
                    if (!d?.path)
                        continue;
                    const at = d.finished || d.started || 0;
                    if (!by[d.path] || at >= by[d.path].at)
                        by[d.path] = { title: d.from?.title ?? "", url: d.from?.url ?? "", at: at };
                }
            } catch (e) {}
            prov.downloadsIndex = by;
        }
        return prov.downloadsIndex;
    }

    // ── phrasing ────────────────────────────────────────────────────────────
    // a file:// URL from a drop; a literal % that is not an escape stays as it is
    function pathOf(x) {
        let s = String(x ?? "");
        if (s.startsWith("file://")) {
            s = s.slice(7);
            try { s = decodeURIComponent(s); } catch (e) {}
        }
        return s;
    }
    function nameOf(p) {
        const parts = p.split("/").filter(x => x.length);
        return parts.length ? parts[parts.length - 1] : p;
    }
    // Origins' app names; Opsis's appId is "browser"
    function appName(id) {
        const a = (id ?? "").toLowerCase();
        if (a === "browser")
            return "Thyris";
        if (a.startsWith("zen"))
            return "zen";
        if (a.includes("firefox"))
            return "firefox";
        if (a.includes("chrom") || a.includes("thorium"))
            return a.includes("thorium") ? "thorium" : "chromium";
        return a.split(".").pop();
    }
    function host(url) {
        const m = /^[a-z]+:\/\/([^/?#]+)/i.exec(url ?? "");
        return m ? m[1] : "";
    }
    // Voice.age's words: "just now", "12m ago", "yesterday", "Sep 2"
    function ago(at) {
        const a = Voice.age(at);
        return a === "now" ? "just now" : /^\d+[mhd]$/.test(a) ? `${a} ago` : a;
    }
    // a screenshot by the clock when it is from today
    function clock(at) {
        const d = new Date(at), now = new Date();
        return d.toDateString() === now.toDateString() ? Qt.formatDateTime(d, "hh:mm") : prov.ago(at);
    }
    function line(p, lead) {
        const o = prov.origins()[p];
        const dl = prov.downloads()[p];
        let parts = [];
        if (dl && (!o || (o.kind === "download" && !o.app))) {
            const page = dl.title || prov.host(dl.url);
            parts = ["downloaded from Thyris", page ? `page '${page}'` : "", (o?.at || dl.at) ? prov.ago(o?.at || dl.at) : ""];
        } else if (!o) {
            return "";
        } else if (o.kind === "screenshot") {
            parts = [o.app ? `screenshot of ${prov.appName(o.app)}` : "screenshot", o.title ? `window '${o.title}'` : "", o.at ? prov.clock(o.at) : ""];
        } else if (o.kind === "agent") {
            const who = ({ claude: "Claude", codex: "Codex", pi: "pi", opencode: "opencode" })[o.app || "claude"] ?? o.app;
            parts = [o.title ? `written by ${who} in ${o.title}` : `written by ${who}`];
        } else if (o.kind === "phone") {
            parts = [`from ${o.device || "your phone"}`, o.at ? prov.ago(o.at) : ""];
        } else if (o.kind === "clipboard") {
            if (!o.app)
                return "";
            parts = [`copied in ${prov.appName(o.app)}`, o.at ? prov.ago(o.at) : ""];
        } else {
            parts = [o.app ? `downloaded from ${prov.appName(o.app)}` : "downloaded", o.title ? `page '${o.title}'` : "", o.at ? prov.ago(o.at) : ""];
        }
        return `${lead} — ${parts.filter(x => x.length > 0).join(", ")}`;
    }
}
