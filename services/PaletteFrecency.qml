pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Frecency for the command palette.
 *
 * score = count * 0.5^(days_since_last / halfLifeDays), i.e. a launch is worth a
 * whole point today and half a point a week later.
 *
 * Persistence copies services/Todo.qml exactly: one JSON blob under
 * ${Directories.state}/user (~/.local/state/quickshell/user), a FileView that
 * JSON.parses on load and setText()s on change, and a load failure that just means
 * "no history yet". Every read is wrapped so a truncated or hand-edited file can
 * never take the palette down - the worst case is an empty ranking.
 */
Singleton {
    id: root

    readonly property string fileDir: FileUtils.trimFileProtocol(`${Directories.state}/user`)
    readonly property string filePath: `${root.fileDir}/palette-frecency.json`

    readonly property bool enable: Config.options.commandPalette?.frecency?.enable ?? true
    readonly property real halfLifeDays: Config.options.commandPalette?.frecency?.halfLifeDays ?? 7
    // How many list positions one doubling of the score is worth, and the hard cap on
    // the climb. Bounded on purpose: frecency is a tiebreaker, never a replacement for
    // the fuzzy match, and it must not float an app above an open window.
    readonly property real boostWeight: Config.options.commandPalette?.frecency?.boost ?? 2
    readonly property real boostCap: Math.max(0, Config.options.commandPalette?.frecency?.boostCap ?? 8)
    readonly property int maxEntries: Math.max(1, Config.options.commandPalette?.frecency?.maxEntries ?? 200)

    readonly property real dayMs: 86400000

    // key -> { count: number, last: msSinceEpoch }. Replaced wholesale on every write
    // so the change signal actually fires and the app section re-sorts.
    property var stats: ({})
    property bool loaded: false

    // Anything that is not a well-formed {count, last} pair is treated as absent, so a
    // hand-edited or half-written file costs history, never correctness.
    function entryIn(table, key) {
        if (!table || !key || key.length === 0)
            return null;
        const entry = table[key];
        if (!entry || typeof entry.count !== "number" || typeof entry.last !== "number")
            return null;
        if (!Number.isFinite(entry.count) || !Number.isFinite(entry.last) || entry.count <= 0)
            return null;
        return entry;
    }

    function entryFor(key) {
        return root.entryIn(root.stats, key);
    }

    function scoreIn(table, key) {
        if (!root.enable)
            return 0;
        const entry = root.entryIn(table, key);
        if (entry === null)
            return 0;
        const halfLife = root.halfLifeDays > 0 ? root.halfLifeDays : 7;
        const days = Math.max(0, (Date.now() - entry.last) / root.dayMs);
        return entry.count * Math.pow(0.5, days / halfLife);
    }

    function score(key) {
        return root.scoreIn(root.stats, key);
    }

    // The reactive `stats` assignment is what makes every ranking binding re-run and
    // the apps section re-sort. Doing that in the same frame as a launch is exactly
    // the hitch you feel as the palette closes, so the two halves are split: the file
    // write stays synchronous (a recorded launch can be "Restart shell", and a
    // deferred write would simply be lost), while the property assignment waits until
    // the palette is gone.
    property var pendingStats: null

    function record(key) {
        if (!root.enable || !key || key.length === 0)
            return;
        const base = root.pendingStats ?? root.stats ?? {};
        const next = Object.assign({}, base);
        const existing = root.entryIn(base, key);
        next[key] = {
            count: (existing === null ? 0 : existing.count) + 1,
            last: Date.now()
        };
        root.pendingStats = root.prune(next);
        root.saveTable(root.pendingStats);
        commitTimer.restart();
    }

    Timer {
        id: commitTimer
        interval: 400
        onTriggered: {
            if (root.pendingStats === null)
                return;
            root.stats = root.pendingStats;
            root.pendingStats = null;
        }
    }

    function saveTable(table) {
        try {
            frecencyFileView.setText(JSON.stringify(table));
        } catch (error) {
            console.log("[PaletteFrecency] Could not write state file:", error);
        }
    }

    function save() {
        root.saveTable(root.stats);
    }

    // Keeps the file from growing without bound; drops the coldest keys first.
    function prune(table) {
        const keys = Object.keys(table);
        if (keys.length <= root.maxEntries)
            return table;
        const kept = keys.map(key => ({
            key: key,
            score: root.scoreIn(table, key)
        })).sort((a, b) => b.score - a.score).slice(0, root.maxEntries);
        const out = {};
        for (const item of kept) {
            out[item.key] = table[item.key];
        }
        return out;
    }

    /** Keys with any history left, hottest first. */
    function topKeys(limit) {
        if (!root.enable || !root.stats)
            return [];
        return Object.keys(root.stats).map(key => ({
            key: key,
            score: root.score(key)
        })).filter(item => item.score > 0).sort((a, b) => b.score - a.score).slice(0, limit).map(item => item.key);
    }

    /**
     * Re-orders an already-ranked list, using the frecency score only to let an entry
     * climb a bounded number of positions. Ties fall back to the original order, so a
     * list with no history at all comes back untouched.
     */
    function reorder(items, keyOf) {
        if (!root.enable || !items || items.length < 2)
            return items;
        const ranked = items.map((item, index) => {
            const value = root.score(keyOf(item));
            const boost = value <= 0 ? 0 : Math.min(root.boostCap, Math.log2(1 + value) * root.boostWeight);
            return {
                item: item,
                index: index,
                rank: index - boost
            };
        });
        ranked.sort((a, b) => (a.rank - b.rank) || (a.index - b.index));
        return ranked.map(entry => entry.item);
    }

    function load(text) {
        try {
            const parsed = JSON.parse(text);
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
                console.log("[PaletteFrecency] State file is not an object, starting empty.");
                root.stats = ({});
            } else {
                root.stats = parsed;
            }
        } catch (error) {
            console.log("[PaletteFrecency] Could not parse state file, starting empty:", error);
            root.stats = ({});
        }
        root.loaded = true;
    }

    Component.onCompleted: {
        // Directories.qml does not create ${state}/user; Todo.qml gets away with it
        // because something else already made the directory. Do not rely on that.
        Quickshell.execDetached(["mkdir", "-p", root.fileDir]);
        frecencyFileView.reload();
    }

    FileView {
        id: frecencyFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: root.load(frecencyFileView.text())
        onLoadFailed: error => {
            // Missing file is the normal first run; anything else still degrades to
            // "no history" rather than breaking the palette.
            if (error != FileViewError.FileNotFound)
                console.log("[PaletteFrecency] Error loading state file: " + error);
            root.stats = ({});
            root.loaded = true;
        }
    }
}
