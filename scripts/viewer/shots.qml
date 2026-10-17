import QtQuick
import QtQuick.Controls
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.modules.common
import "modules/viewer"

// Off-screen stills of the viewer on the desktop wallpaper, material and hairline as in the mocks.
ApplicationWindow {
    id: app
    visible: true; width: 1600; height: 1000; color: "transparent"
    readonly property string walks: Quickshell.env("VIEWER_WALKS") + "/"
    readonly property string out: Quickshell.env("VIEWER_OUT") + "/"
    readonly property string set: Quickshell.env("VIEWER_SET") || "main"
    readonly property string misc: Quickshell.env("VIEWER_MISC") + "/"
    readonly property string many: Quickshell.env("VIEWER_MANY") + "/"
    readonly property string base: Quickshell.env("HOME") + "/.cache/tacit-viewer/v1/"
    readonly property string ast: "file:///home/abdul/.cache/tacit-mocks/assets/"
    readonly property var only: (Quickshell.env("VIEWER_ONLY") || "").split(",").filter(s => s.length)

    Item {
        id: r
        width: 1600; height: 1000
        Image { anchors.fill: parent; source: app.ast + "bg.png" }
        Rectangle { x: 27; y: 27; width: 1546; height: 946; radius: 19; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08) }
        Item {
            id: win
            x: 28; y: 28; width: 1544; height: 944
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: Rectangle { width: win.width; height: win.height; radius: 18 } }
            Image { x: -28; y: -28; width: 1600; height: 1000; source: app.ast + "bgblur.png" }
            Rectangle { anchors.fill: parent; color: Qt.rgba(0x1D / 255, 0x1A / 255, 0x19 / 255, 0.85) }
            Viewer { id: v; anchors.fill: parent; muted: true }
        }
    }

    QtObject { id: stall; property real max: 0; property real last: Date.now() }
    Timer { interval: 16; running: true; repeat: true; onTriggered: { const n = Date.now(); stall.max = Math.max(stall.max, n - stall.last); stall.last = n; } }
    property var steps: []
    property int at: 0
    function scene(name, wait, setup, post) { steps.push({ name: name, wait: wait, setup: setup, post: post }); }
    function still(v_) { v.animate = false; }

    Timer {
        id: tick
        interval: 400
        running: true
        onTriggered: app.next()
    }
    function next() {
        if (app.at >= steps.length) { Qt.quit(); return; }
        const s = steps[app.at];
        if (!s.armed) {
            s.armed = true;
            if (s.setup) s.setup();
            tick.interval = s.wait; tick.restart();
            return;
        }
        app.at++;
        if (s.post) s.post();
        if (!s.name) { tick.interval = 10; tick.restart(); return; }
        r.grabToImage(g => { g.saveToFile(app.out + s.name + ".png"); console.log("SHOT " + s.name + " " + v.state()); tick.interval = 10; tick.restart(); });
    }

    function key(k, mods) { v.key({ key: k, modifiers: mods ?? 0, accepted: false }); }
    function check(label) { console.log("CHECK " + label + " " + v.state()); }
    function goName(n) { const i = v.entries.findIndex(e => e.name === n); v.cur = i; v.pos = i; }
    function restState() { v.animate = false; v.factsOn = false; v.folded = false; v.chromeOn = true; v.zoom = 1; v.panX = 0; v.panY = 0; v.settle = 0; v.fold = 0; v.facts = 0; }

    Component.onCompleted: {
        const f = n => app.walks + n;
        const m = n => app.misc + n;
        if (app.set === "main") {
        // ---- the photo: roll with facts, roll at rest, bare, the way between
        scene("", 800, () => { v.open(f("Cwm lake.jpg")); });
        scene("", 1200, () => { restState(); v.settle = 1; });
        scene("bare-photo-facts", 500, () => { v.factsOn = true; v.showChrome(); });
        scene("bare-photo-zoom", 900, () => { v.factsOn = false; v.setZoom(2.6); });
        scene("bare-photo-rest", 600, () => { v.setZoom(1); v.chromeOn = false; });
        scene("", 300, () => { v.chromeOn = true; });
        for (const n of [10, 30, 50, 70, 90]) scene("strip-settle-" + n, 450, () => { v.settle = n / 100; });
        scene("roll-photo-facts", 700, () => { v.settle = 0; v.factsOn = true; });
        scene("roll-photo-rest", 700, () => { v.factsOn = false; });
        for (const n of [25, 50, 75]) scene("strip-step-" + n, 450, () => { v.cur = 2; v.pos = 1 + n / 100; });
        scene("strip-bare-to-next", 500, () => { v.settle = 0.5; v.cur = 2; v.pos = 1.4; });
        scene("fold", 900, () => { v.settle = 0; v.cur = 1; v.pos = 1; v.folded = true; });
        scene("", 300, () => { v.folded = false; v.chromeOn = true; });
        // ---- the real motion, with the clock running (logged: settle value at each grab)
        scene("", 300, () => { restState(); v.animate = true; });
        scene("", 110, () => { v.key({ key: Qt.Key_Return, modifiers: 0, accepted: false }); }, () => check("t+110ms after Enter"));
        scene("", 110, () => { }, () => check("t+250ms"));
        scene("", 400, () => { }, () => check("t+600ms"));
        scene("", 100, () => { v.key({ key: Qt.Key_Right, modifiers: 0, accepted: false }); }, () => check("t+0 after Right"));
        scene("", 150, () => { }, () => check("t+150ms"));
        scene("", 1800, () => { }, () => check("after-arrow-and-dwell"));
        // ---- touchpad: a swipe that follows the fingers, then lands
        scene("", 900, () => {
            let t = 1000; v.swipe(0, Qt.ScrollBegin, t);
            for (let k = 0; k < 6; k++) { t += 16; v.swipe(70, Qt.ScrollUpdate, t); }
            v.swipe(0, Qt.ScrollEnd, t + 8);
        }, () => check("swipe-end"));
        scene("", 1500, () => { }, () => check("swipe-landed"));
        // ---- PDF
        scene("", 900, () => { v.open(f("Harbour Survey 2026.pdf")); });
        scene("", 1800, () => { restState(); });
        scene("", 3600, () => { v.openSearch(); v.setQuery("tidal"); });
        scene("roll-pdf-search", 1300, () => { v.reader.search.currentResult = 3; }, () => check("pdf-search"));
        scene("bare-pdf-search", 1400, () => { v.settle = 1; });
        scene("strip-settle-pdf-50", 900, () => { v.settle = 0.5; });
        // ---- video and audio
        scene("", 900, () => { v.closeSearch(); v.open(f("Night crossing.mp4")); });
        scene("", 1800, () => { restState(); v.seekTo(9 / 24); });
        scene("", 700, () => { if (v.playing) v.togglePlay(); });
        scene("bare-video", 800, () => { v.settle = 1; v.showChrome(); });
        scene("roll-video", 800, () => { v.settle = 0; }, () => check("video"));
        scene("", 900, () => { v.open(f("Slow Water.flac")); });
        scene("", 1800, () => { restState(); v.seekTo(72 / 214); });
        scene("", 700, () => { if (v.playing) v.togglePlay(); });
        scene("roll-audio", 800, () => { }, () => check("audio"));
        scene("bare-audio", 900, () => { v.settle = 1; v.showChrome(); });
        scene("", 500, () => { v.open(f("Tide pool.jpg")); });
        scene("", 1500, () => { restState(); v.folded = true; });
        scene("fold-from-tide-pool", 1000, () => { });
        } else if (app.set === "fixes") {
        // ---- plain errors, one per kind
        const b = n => app.base + "bad/" + n;
        scene("", 900, () => { v.open(b("good.jpg")); });
        scene("", 800, () => { restState(); goName("corrupt.jpg"); });
        scene("err-roll-image", 1200, () => { }, () => check("corrupt image roll"));
        scene("err-bare-image", 900, () => { v.settle = 1; });
        scene("", 100, () => { v.settle = 0; goName("damaged.pdf"); });
        scene("err-roll-pdf", 3000, () => { v.landed = v.cur; }, () => check("damaged pdf roll"));
        scene("err-bare-pdf", 900, () => { v.settle = 1; });
        scene("", 900, () => { v.settle = 0; v.open(b("notes.xyz")); });
        scene("err-roll-other", 1200, () => { restState(); }, () => check("unsupported roll"));
        scene("err-bare-other", 900, () => { v.settle = 1; });
        scene("", 100, () => { v.settle = 0; v.open(b("broken.mp3")); });
        scene("err-roll-audio", 2500, () => { }, () => check("broken mp3 roll err=" + v.mediaError));
        scene("err-bare-audio", 900, () => { v.settle = 1; });
        scene("", 100, () => { v.settle = 0; goName("good.jpg"); });
        scene("err-cleared-roll", 1200, () => { }, () => check("good again"));
        } else if (app.set === "long") {
        // ---- a 630-page PDF: UI stalls (longest gap between 16 ms ticks) while opening, zooming and searching
        scene("", 1500, () => { v.open(app.base + "big/Long report.pdf"); stall.max = 0; });
        scene("", 2500, () => { restState(); v.settle = 1; }, () => console.log("STALL open+settle ms " + stall.max));
        scene("", 100, () => { stall.max = 0; for (let k = 0; k < 8; k++) v.pdfZoom = 1 + k * 0.08; }, () => {});
        scene("", 900, () => { }, () => console.log("STALL zoom ms " + stall.max));
        scene("", 100, () => { stall.max = 0; v.openSearch(); v.setQuery("tidal"); });
        scene("", 4000, () => { }, () => console.log("STALL search ms " + stall.max + " matches " + v.reader.search.count + " marks " + v.reader.marks.length + " tally " + v.reader.counts.reduce((a,b)=>a+b,0) + " scanned " + v.reader.scanned));
        scene("long-pdf-search", 600, () => { v.reader.search.currentResult = 20; });
        } else if (app.set === "huge") {
        scene("", 100, () => { stall.max = 0; v.open(app.base + "huge/img-01500.jpg"); });
        scene("", 3000, () => { }, () => console.log("HUGE open: frames made " + v.framesMade + " entries " + v.entries.length + " stall ms " + stall.max));
        scene("", 100, () => { stall.max = 0; for (let k = 0; k < 8; k++) v.step(1); });
        scene("", 1500, () => { }, () => console.log("HUGE after 8 steps: frames made " + v.framesMade + " cur " + v.cur + " stall ms " + stall.max));
        scene("huge-roll", 100, () => { v.settle = 0; }, () => check("huge"));
        } else if (app.set === "keys") {
        let closed = 0;
        v.closeRequested.connect(() => closed++);
        scene("", 900, () => { v.muted = false; v.muted = true; v.open(f("Cwm lake.jpg")); });
        scene("", 1200, () => { }, () => check("open: bare"));
        scene("", 1000, () => key(Qt.Key_Left), () => check("Left: roll, index 0"));
        scene("", 1500, () => key(Qt.Key_End), () => check("End: index 5 (roll)"));
        scene("", 1500, () => key(Qt.Key_Home), () => check("Home then dwell: index 0 bare"));
        scene("", 1000, () => key(Qt.Key_Tab), () => check("Tab: fold"));
        scene("", 800, () => key(Qt.Key_Return), () => check("Enter in fold: bare"));
        scene("", 1000, () => key(Qt.Key_Right), () => check("Right: roll idx1"));
        scene("", 900, () => key(Qt.Key_I), () => check("i: facts on (factsOn=" + v.factsOn + ")"));
        scene("", 900, () => key(Qt.Key_Escape), () => check("Esc: facts off (factsOn=" + v.factsOn + ")"));
        scene("", 1800, () => { }, () => check("dwell -> bare"));
        scene("", 700, () => { key(Qt.Key_Equal); key(Qt.Key_Equal); }, () => check("zoom x" + v.zoom.toFixed(2)));
        scene("", 700, () => key(Qt.Key_Escape), () => check("Esc: zoom " + v.zoom));
        scene("", 1400, () => { v.goTo(v.entries.findIndex(e => e.name === "Night crossing.mp4")); }, () => check("video landed"));
        scene("", 1200, () => { v.settleNow(true); }, () => check("Enter-play"));
        scene("", 900, () => key(Qt.Key_Right, Qt.ShiftModifier), () => check("Shift+Right seek +5s, pos " + v.position));
        scene("", 700, () => key(Qt.Key_Space), () => check("Space: paused " + !v.playing));
        scene("", 500, () => key(Qt.Key_Down), () => check("Down: volume " + v.volume.toFixed(2)));
        scene("", 500, () => key(Qt.Key_BracketRight), () => check("] speed " + v.rate));
        scene("", 500, () => key(Qt.Key_M), () => check("m muted " + v.muted));
        scene("", 700, () => key(Qt.Key_Escape), () => check("Esc: close requested " + closed));
        scene("", 900, () => { v.goTo(v.entries.findIndex(e => e.name === "Harbour Survey 2026.pdf")); }, () => check("pdf landed"));
        scene("", 1800, () => { }, () => check("pdf bare"));
        scene("", 700, () => key(Qt.Key_Slash), () => check("/ search open " + v.searchOpen));
        scene("", 2500, () => { v.setQuery("tidal"); }, () => check("typed tidal"));
        scene("", 900, () => key(Qt.Key_Escape), () => check("Esc closes search " + v.searchOpen));
        scene("", 900, () => key(Qt.Key_PageDown), () => check("PageDown"));
        scene("", 900, () => { }, () => check("page after PageDown " + v.pdfPage));
        scene("", 700, () => key(Qt.Key_Down), () => check("Down scroll"));
        } else {
        // ---- awkward files: animated, rotated, vector, odd names, locked, refused by PDFium
        scene("", 900, () => { v.open(m("anim.gif")); });
        scene("", 1500, () => { restState(); v.settle = 1; });
        scene("misc-bare-gif", 300, () => { }, () => check("gif"));
        scene("", 100, () => { v.step(1); });
        scene("", 1200, () => { restState(); v.settle = 1; });
        scene("misc-bare-webp", 300, () => { v.settle = 1; }, () => check("webp"));
        scene("misc-roll-misc-folder", 1200, () => { v.settle = 0; goName("Diagram.svg"); });
        scene("misc-roll-rotated-exif6", 1200, () => { goName("Rotated 6.jpg"); }, () => check("rotated"));
        scene("misc-bare-rotated-exif6", 900, () => { v.settle = 1; });
        scene("misc-roll-odd-name", 1200, () => { v.settle = 0; goName("Tide #2 (copy) ?.png.jpg"); }, () => check("odd-name"));
        scene("", 500, () => { v.open(m("doc.pdf")); });
        scene("misc-pdf-locked", 1800, () => { restState(); v.settle = 1; }, () => check("locked " + (v.lockedDoc !== null)));
        scene("misc-pdf-unlocked", 2500, () => { if (v.lockedDoc) v.lockedDoc.password = "tacit"; }, () => check("unlocked"));
        scene("", 500, () => { v.open(f("Harbour Survey 2026.pdf")); });
        scene("", 1500, () => { restState(); v.needFallback(f("Harbour Survey 2026.pdf")); });
        scene("misc-pdf-poppler", 2500, () => { v.settle = 1; }, () => check("poppler"));
        scene("", 500, () => { v.open(app.many + "img-30.jpg"); });
        scene("misc-roll-60-files", 1800, () => { restState(); }, () => check("many"));
        scene("", 100, () => { for (let k = 0; k < 15; k++) v.step(1); });
        scene("misc-roll-60-files-after-15-steps", 1200, () => { }, () => check("many-after"));
        }
    }
}
