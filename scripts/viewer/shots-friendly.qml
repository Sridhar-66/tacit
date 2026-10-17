import QtQuick
import QtQuick.Controls
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.modules.common
import "modules/viewer"

// Off-screen stills of the viewer on the desktop wallpaper, for the friendly pass. The same file renders the
// v1 tree ("before") and the new one ("after"); only what both have is touched, so the stills line up.
ApplicationWindow {
    id: app
    readonly property int ww: +(Quickshell.env("VIEWER_W") || 1544)
    readonly property int wh: +(Quickshell.env("VIEWER_H") || 944)
    visible: true; width: ww + 56; height: wh + 56; color: "transparent"
    readonly property string dir: Quickshell.env("VIEWER_DIR") + "/"
    readonly property string out: Quickshell.env("VIEWER_OUT") + "/"
    readonly property string set: Quickshell.env("VIEWER_SET") || "main"
    readonly property string ast: "file:///home/abdul/.cache/tacit-mocks/assets/"

    Item {
        id: r
        width: app.ww + 56; height: app.wh + 56
        Image { anchors.fill: parent; source: app.ast + "bg.png"; fillMode: Image.PreserveAspectCrop }
        Rectangle { x: 27; y: 27; width: app.ww + 2; height: app.wh + 2; radius: 19; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08) }
        Item {
            id: win
            x: 28; y: 28; width: app.ww; height: app.wh
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: Rectangle { width: win.width; height: win.height; radius: 18 } }
            Image { x: -28; y: -28; width: r.width; height: r.height; source: app.ast + "bgblur.png"; fillMode: Image.PreserveAspectCrop }
            Rectangle { anchors.fill: parent; color: Qt.rgba(0x1D / 255, 0x1A / 255, 0x19 / 255, 0.85) }
            Viewer { id: v; anchors.fill: parent; muted: true }
        }
    }

    property var steps: []
    property real mark: 0
    property int at: 0
    function scene(name, wait, setup, post) { steps.push({ name: name, wait: wait, setup: setup, post: post }); }
    Timer { id: tick; interval: 400; running: true; onTriggered: app.next() }
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
        r.grabToImage(g => { g.saveToFile(app.out + s.name + ".png"); console.log("SHOT " + s.name + " t=" + (Date.now() - app.mark) + ' pos=' + v.pos.toFixed(2) + ' cur=' + v.cur + ' landed=' + v.landed + ' settle=' + v.settle.toFixed(2) + ' chrome=' + v.chrome.toFixed(2) + ' facts=' + v.facts.toFixed(2) + ' fold=' + v.fold.toFixed(2) + ' zoom=' + v.zoom.toFixed(2)); tick.interval = 10; tick.restart(); });
    }
    function rest() {
        v.animate = false; v.factsOn = false; v.folded = false; v.chromeOn = true; v.zoom = 1; v.panX = 0; v.panY = 0; v.settle = 0; v.fold = 0; v.facts = 0;
        if (v.moreOn !== undefined) more(false);
        if (v.rot !== undefined) { v.rotEase = false; v.rot = 0; v.rotEase = true; }
        v.pdfZoom = 1;
    }
    function more(b) { if (v.moreOn !== undefined) v.moreOn = b; }
    function bare() { rest(); v.settle = 1; }
    function tipOn(i, on) { const k = v.titleBar?.controls?.children; if (k && k[i]) k[i].forceTip = on; }

    Component.onCompleted: {
        const f = n => app.dir + n;
        const open = (n, wait, then) => { scene("", wait, () => { v.open(f(n)); }); scene("", then, () => { rest(); }); };
        const tag = Quickshell.env("VIEWER_TAG") || "";
        const S = (n, wait, setup, post) => scene(n, wait, setup, post);
        if (app.set === "main") {
            // photo
            open("IMG_20240914_143208.jpg", 900, 1300);
            S("photo-bare", 900, () => { v.settle = 1; });
            S("photo-info", 900, () => { v.factsOn = true; });
            S("photo-info-more", 900, () => { more(true); });
            S("photo-zoomed", 900, () => { v.factsOn = false; more(false); v.setZoom(2.2); });
            S("photo-roll", 900, () => { rest(); });
            S("photo-roll-info", 900, () => { v.factsOn = true; });
            S("photo-roll-info-more", 900, () => { more(true); });
            S("fold", 1000, () => { rest(); v.folded = true; });
            // PDFs
            open("Codsi_Beddelidda_Lambarka.pdf", 900, 2500);
            S("pdf-letter-roll", 900, () => { });
            S("pdf-letter-bare", 1400, () => { v.settle = 1; });
            S("pdf-letter-info", 900, () => { v.factsOn = true; });
            open("Annual_report-2025_final.pdf", 900, 3500);
            S("pdf-report-roll", 900, () => { });
            S("pdf-report-bare", 1600, () => { v.settle = 1; });
            S("pdf-report-page5", 1700, () => { v.pdfGoTo(4); });
            S("pdf-report-info", 1200, () => { v.factsOn = true; });
            S("pdf-report-search", 4200, () => { v.factsOn = false; v.openSearch(); v.setQuery("tidal"); }, () => {});
            S("pdf-report-search-2", 900, () => { v.reader.search.currentResult = 3; });
            // screenshot
            S("", 900, () => { v.closeSearch(); v.open(f("Screenshot_from_2026-10-02_21-14-07.png")); });
            S("", 1300, () => { rest(); });
            S("screenshot-roll", 900, () => { });
            S("screenshot-bare", 900, () => { v.settle = 1; });
            // video, song
            open("VID_20240914_151200.mp4", 900, 1800);
            S("", 700, () => { v.seekTo(9 / 24); });
            S("", 700, () => { if (v.playing) v.togglePlay(); });
            S("video-bare", 900, () => { v.settle = 1; v.showChrome(); });
            S("video-roll", 900, () => { v.settle = 0; });
            open("01_Slow-Water.flac", 900, 1800);
            S("", 700, () => { v.seekTo(72 / 214); });
            S("", 700, () => { if (v.playing) v.togglePlay(); });
            S("audio-roll", 900, () => { });
            S("audio-bare", 900, () => { v.settle = 1; v.showChrome(); });
            S("audio-info", 900, () => { v.factsOn = true; });
        } else if (app.set === "extra") {
            // after only: rotate, the strip, the tooltip, the open-with menu
            open("IMG_20240914_143208.jpg", 900, 1300);
            S("photo-turned-90", 1600, () => { v.settle = 1; v.animate = true; v.turn(); });
            S("photo-turned-180", 1600, () => { v.turn(); });
            S("photo-tip-zoomin", 800, () => { v.animate = false; v.rotEase = false; v.rot = 0; v.rotEase = true; tipOn(5, true); });
            S("photo-tip-copy", 800, () => { tipOn(5, false); tipOn(9, true); });
            S("photo-open-with", 1500, () => { tipOn(9, false); v.openWith(1400, 62); });
            S("", 300, () => { });
            S("photo-info-more-copy", 600, () => { v.key({ key: Qt.Key_Escape, modifiers: 0, accepted: false }); rest(); v.settle = 1; v.factsOn = true; more(true); });
                        open("Annual_report-2025_final.pdf", 900, 3500);
            S("pdf-report-fit", 1600, () => { v.settle = 1; v.pdfGoTo(7); });
            S("pdf-report-zoom", 1200, () => { v.zoomBy(1); v.zoomBy(1); });
        } else if (app.set === "motion") {
            // a step from a settled photo, caught on the way: the roll pulls back, moves, and settles again
            open("IMG_20240914_143208.jpg", 900, 1300);
            S("", 900, () => { v.settle = 1; });
            S("mo-00-bare", 400, () => { v.animate = true; v.showChrome(); });
            S("mo-01-40ms", 40, () => { v.step(1); });
            S("mo-02-120ms", 80, null);
            S("mo-03-240ms", 120, null);
            S("mo-04-450ms", 210, null);
            S("mo-05-900ms", 450, null);
            S("mo-06-1400ms", 500, null);
            S("mo-07-1800ms", 400, null);
            S("mo-08-2600ms", 800, null);
        } else if (app.set.startsWith("m-")) {
            // frame-by-frame transitions; every scene is named m-<what> and grabs at the listed ms after the action
            const key = (k, m) => v.key({ key: k, modifiers: m ?? 0, accepted: false });
            const seq = (p, times, act) => { let prev = 0; times.forEach((t, i) => { S(p + "-" + String(i).padStart(2, "0") + "-" + t, t - prev, i === 0 ? () => { app.mark = Date.now(); act(); } : null); prev = t; }); };
            const prep = (n, extra) => { open(n, 900, 1300); S("", 900, () => { v.settle = 1; }); S("", 700, () => { v.animate = true; v.showChrome(); if (extra) extra(); }); };
            const T1 = [0, 40, 120, 240, 450, 700, 900];
            const TS = [900, 1000, 1100, 1200, 1300, 1450, 1650, 2000, 2600];   // the dwell, then settle
            const IMG = "IMG_20240914_143208.jpg", PDF = "Annual_report-2025_final.pdf", PDF2 = "Codsi_Beddelidda_Lambarka.pdf", VID = "VID_20240914_151200.mp4", AUD = "01_Slow-Water.flac", PNG = "Screenshot_from_2026-10-02_21-14-07.png";
            const n = app.set;
            if (n === "m-prev") { prep(IMG); seq("p", [0, 40, 120, 240, 450, 700, 900, 1000, 1100, 1200, 1300, 1450, 1650, 2000, 2600], () => key(Qt.Key_Left)); }
            else if (n === "m-next") { prep(IMG); seq("n", [0, 40, 120, 240, 450, 700, 900, 1000, 1100, 1200, 1300, 1450, 1650, 2000, 2600], () => key(Qt.Key_Right)); }
            else if (n === "m-run") {
                prep(IMG);
                S("rl-00-k1", 150, () => { app.mark = Date.now(); key(Qt.Key_Left); });
                S("rl-01-k2", 150, () => key(Qt.Key_Left));
                S("rl-02-k3", 150, () => key(Qt.Key_Left));
                seq("rl-end", [100, 250, 450, 700, 1000, 1300, 1600, 2000, 2800], () => { });
            }
            else if (n === "m-run2") {
                prep(AUD);
                S("rr-00-k1", 150, () => { app.mark = Date.now(); key(Qt.Key_Right); });
                S("rr-01-k2", 150, () => key(Qt.Key_Right));
                S("rr-02-k3", 150, () => key(Qt.Key_Right));
                S("rr-03-k4", 150, () => key(Qt.Key_Right));
                seq("rr-end", [100, 250, 450, 700, 1000, 1300, 1600, 2000, 2800], () => { });
            }
            else if (n === "m-info") {
                prep(IMG);
                seq("i-open", [0, 40, 120, 240, 450, 900], () => key(Qt.Key_I));
                seq("i-next", [0, 60, 160, 300, 500, 800, 1300, 2000], () => key(Qt.Key_Right));
                seq("i-close", [0, 40, 120, 240, 450, 900], () => key(Qt.Key_I));
            }
            else if (n === "m-more") {
                prep(IMG, () => { v.factsOn = true; });
                seq("m-tog", [0, 60, 200, 500, 900], () => more(true));
                seq("m-back", [0, 60, 200, 500, 900], () => more(false));
                seq("m-step", [0, 100, 300, 700, 1300, 2000], () => { more(true); key(Qt.Key_Right); });
            }
            else if (n === "m-pdf") {
                prep(PDF);
                S("", 1500, () => { });
                seq("pd-next", [0, 40, 120, 240, 450, 700, 900, 1100, 1300, 1600, 2000, 2600, 3200], () => key(Qt.Key_Right));
                seq("pd-prev", [0, 40, 120, 240, 450, 900, 1300, 1700, 2200, 3000], () => key(Qt.Key_Left));
                seq("pd-prev2", [0, 40, 120, 240, 450, 900, 1300, 1700, 2200, 3000], () => key(Qt.Key_Left));
            }
            else if (n === "m-topdf") { prep(IMG); seq("tp", [0, 40, 120, 240, 450, 700, 900, 1100, 1300, 1600, 2000, 2600, 3200], () => { v.goTo(1); }); }
            else if (n === "m-vid") {
                prep(VID);
                seq("v-prev", [0, 40, 120, 240, 450, 700, 900, 1100, 1300, 1600, 2000, 2600], () => key(Qt.Key_Left));
            }
            else if (n === "m-vid2") { prep(PNG); seq("v-next", [0, 40, 120, 240, 450, 700, 900, 1100, 1300, 1600, 2000, 2600], () => key(Qt.Key_Right)); }
            else if (n === "m-aud") { prep(VID); seq("a-go", [0, 40, 120, 240, 450, 700, 900, 1100, 1300, 1600, 2000, 2600], () => v.goTo(0)); }
            else if (n === "m-search") {
                prep(PDF);
                S("", 1500, () => { });
                seq("s-open", [0, 60, 160, 400, 900, 1800], () => { v.openSearch(); v.setQuery("tidal"); });
                seq("s-next", [0, 40, 120, 240, 450, 900, 1300, 1800, 2400, 3000], () => key(Qt.Key_Right));
                seq("s-close", [0, 60, 160, 400, 900], () => { v.key({ key: Qt.Key_Slash, modifiers: 0, accepted: false }); });
            }
            else if (n === "m-search2") {
                prep(PDF);
                S("", 1500, () => { });
                S("", 2500, () => { v.openSearch(); v.setQuery("tidal"); });
                seq("c-close", [0, 60, 160, 400, 900, 1500], () => v.closeSearch());
            }
            else if (n === "m-zoom") {
                prep(IMG);
                seq("z-in", [0, 60, 160, 400, 900], () => { v.zoomBy(1); v.zoomBy(1); v.zoomBy(1); });
                seq("z-next", [0, 40, 120, 240, 450, 900, 1300, 1800, 2400], () => key(Qt.Key_Right));
                seq("z-prev", [0, 40, 120, 240, 450, 900, 1300, 1800, 2400], () => key(Qt.Key_Left));
            }
            else if (n === "m-fit") {
                prep(IMG);
                S("", 300, () => { v.zoomBy(1); v.zoomBy(1); v.zoomBy(1); });
                seq("f-fit", [0, 60, 160, 400, 900], () => v.fit());
                seq("f-rot", [0, 60, 160, 400, 900, 1500], () => v.turn());
                seq("f-step", [0, 60, 160, 400, 900, 1500, 2200], () => key(Qt.Key_Right));
            }
            else if (n === "m-fold") {
                prep(IMG);
                seq("fo-in", [0, 40, 120, 240, 450, 700, 1000, 1500], () => key(Qt.Key_Tab));
                seq("fo-out", [0, 40, 120, 240, 450, 700, 1000, 1500, 2200], () => key(Qt.Key_Tab));
            }
            else if (n === "m-settle") {
                // unsettle by click / re-settle by Enter, and chrome fade
                prep(IMG);
                seq("u-hide", [0, 60, 160, 400, 900], () => { v.chromeOn = false; });
                seq("u-show", [0, 60, 160, 400, 900], () => { v.showChrome(); });
                seq("u-unsettle", [0, 40, 120, 240, 450, 900], () => v.unsettle());
                seq("u-enter", [0, 40, 120, 240, 450, 900, 1300], () => key(Qt.Key_Return));
            }
            else if (n === "m-open") {
                prep(IMG);
                seq("o-menu", [0, 80, 200, 500, 1100], () => v.openWith(1400, 62));
                seq("o-close", [0, 80, 200, 500], () => key(Qt.Key_Escape));
            }
        } else if (app.set === "keys") {
            let closed = 0;
            v.closeRequested.connect(() => closed++);
            const chk = l => console.log("CHECK " + l + " " + v.state());
            const key = (k, m) => v.key({ key: k, modifiers: m ?? 0, accepted: false });
            S("", 900, () => { v.open(f("IMG_20240914_143208.jpg")); });
            S("", 1200, () => { }, () => chk("open"));
            S("", 900, () => key(Qt.Key_Right), () => chk("Right"));
            S("", 900, () => key(Qt.Key_Equal), () => chk("zoom in " + v.zoom));
            S("", 900, () => key(Qt.Key_Minus), () => chk("zoom out " + v.zoom));
            S("", 900, () => key(Qt.Key_I), () => chk("i factsOn=" + v.factsOn));
            S("", 900, () => key(Qt.Key_Escape), () => chk("Esc factsOn=" + v.factsOn));
            S("", 900, () => v.zoomBy(1), () => chk("button zoom in " + v.zoom));
            S("", 900, () => v.fit(), () => chk("button fit " + v.zoom));
            S("", 900, () => v.turn(), () => chk("button turn rot=" + v.rot));
            S("", 900, () => v.toggleInfo(), () => chk("button info " + v.factsOn));
            S("", 900, () => v.step(1), () => chk("button next"));
            S("", 900, () => v.step(-1), () => chk("button prev"));
        }
    }
}
