//@ pragma UseQApplication
//@ pragma AppId store
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Apps: find an app by what you want to do, get it, open it, remove it. Its own process (`qs -p store.qml`), like
// Activity and Viewer. Third pass, on Apple's design principles (~/book4-edge/tacit-store-apple-principles.md), not its
// layout: content first with the controls floating over it; concentric shapes and capsules; one app lockup everywhere;
// hierarchy by weight; spring motion that can be interrupted; editorial cards that lead with what you can do; an app
// page with the essentials first. Kept from Tacit: inks measured on this window's ground, tonal surfaces, sentence-case
// labels, the installer's soft-well search, the accent only for the way forward.
// Data: scripts/store/stored.py (Arch's signed app catalogue + pacman; the store's words in assets/store/editorial.json).
// Not here yet, by design: closed apps, a sandbox or permissions, the notch.

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.tacit
import qs.services

ApplicationWindow {
    id: root

    visible: true
    title: "Apps"
    width: 1528
    height: 928
    minimumWidth: 1120
    minimumHeight: 760
    color: "transparent"
    onClosing: Qt.quit()
    Binding { target: Quickshell; property: "watchFiles"; value: false }

    readonly property int m: 64
    readonly property int cw: width - 2 * m
    readonly property string backend: Quickshell.shellPath("scripts/store/stored.py")
    readonly property string renderDir: Quickshell.env("STORE_RENDER") ?? ""

    // ---- where the window is: discover | job | search | app | yours
    property string page: "discover"
    property var history: []
    property var home: null
    property var job: null
    property var found: null
    property var appInfo: null
    property var jobHero: ({})
    property var jobTone: ({})
    property string query: ""
    property var work: null               // { pkg, kind: "install"|"remove", progress, phase }
    property var outcome: ({})
    property string justGot: ""

    onPageChanged: reveal()
    function go(p) { history = history.concat([{ page: page, job: job, appInfo: appInfo, found: found }]); page = p; }
    function back() {
        if (history.length === 0) { page = "discover"; return; }
        const h = history[history.length - 1];
        history = history.slice(0, -1);
        job = h.job; appInfo = h.appInfo; found = h.found; page = h.page;
    }
    function openApp(pkg) {
        const known = appOf(pkg) ?? (found?.apps ?? []).find(x => x.pkg === pkg) ?? null;
        appInfo = known ? Object.assign({ shots: [], description: [], whatsNew: [], loading: true }, known) : null;
        go("app");
        appProc.pkg = pkg; appProc.running = true;
    }
    function openJob(j) {
        job = j; go("job");
        const best = j.pkgs[0];
        if (jobHero[best] === undefined) { heroProc.pkg = best; heroProc.running = true; }
    }
    function launch(a) {
        const id = (a?.desktop || "").replace(/\.desktop$/, "");
        const entry = id ? DesktopEntries.byId(id) : null;
        if (entry) entry.execute(); else if (id) Quickshell.execDetached(["gtk-launch", id]);
    }
    function get(pkg) {
        if (work) return;
        work = { pkg: pkg, kind: "install", progress: 0, phase: "Starting" };
        const o = Object.assign({}, outcome); delete o[pkg]; outcome = o;
        workProc.command = ["python3", "-I", backend, "install", pkg]; workProc.running = true;
    }
    function removeApp(pkg) {
        if (work) return;
        work = { pkg: pkg, kind: "remove", progress: 0.5, phase: "Removing" };
        workProc.command = ["python3", "-I", backend, "remove", pkg]; workProc.running = true;
    }
    function act(a) { const st = stateOf(a); if (st === "installed") launch(a); else if (st === "get") get(a.pkg); }
    function refresh() { homeProc.running = true; if (page === "app" && appInfo) { appProc.pkg = appInfo.pkg; appProc.running = true; } }
    function runSearch(q) {
        query = q;
        const s = q.trim().toLowerCase();
        if (s.length < 2) return;
        const j = (home?.jobs ?? []).find(j => j.name.toLowerCase() === s || j.words.some(w => w === s || (s.length > 3 && w.startsWith(s))));
        found = { query: s, apps: [], job: j ?? null };
        if (page !== "search") go("search");
        searchProc.command = ["python3", "-I", backend, "search", s]; searchProc.running = true;
    }
    function appOf(pkg) { return home?.apps?.[pkg] ?? null; }
    function jobOf(pkg) { return (home?.jobs ?? []).find(j => j.pkgs.includes(pkg)) ?? null; }
    function stateOf(a) {
        if (!a) return "none";
        if (work && work.pkg === a.pkg) return work.kind === "install" ? "getting" : "removing";
        if (a.installed) return "installed";
        if (!a.available) return "unavailable";
        return "get";
    }
    function costWords(a) {
        if (!a) return "";
        if (a.installed) return "On this computer";
        return [a.free === false ? "Free to use" : "Free", a.download ? `${a.download} MB` : ""].filter(x => x).join(" · ");
    }
    readonly property var outcomeWords: ({
        "cancelled": ["Not installed", "The password was not given, so nothing changed."],
        "busy": ["Another update is running", "Try again when it has finished."],
        "offline": ["No internet connection", "Connect to the internet, then try again."],
        "space": ["Not enough space", "Free up some space, then try again."],
        "update": ["Needs a system update first", "Some of what it needs is newer than this system. Update the system, then get it."],
        "failed": ["Couldn't install it", "Nothing was changed. Try again, or look again later."],
        "needed": ["Other apps use it", "It can't be removed while they need it."],
        "unavailable": ["Not made for this computer", "There is no version of it for this computer's processor."]
    })

    // ---- the backend
    Process { id: homeProc; running: true; command: ["python3", "-I", root.backend, "home"]
        stdout: StdioCollector { onStreamFinished: { try { root.home = JSON.parse(text); } catch (e) { console.warn("store: home", e); } } } }
    Process { id: appProc; property string pkg: ""; command: ["python3", "-I", root.backend, "app", pkg]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); if (root.appInfo && j.pkg === root.appInfo.pkg) root.appInfo = j; } catch (e) { console.warn("store: app", e); } } } }
    Process { id: heroProc; property string pkg: ""; command: ["python3", "-I", root.backend, "app", pkg]
        stdout: StdioCollector { onStreamFinished: { try {
            const a = JSON.parse(text);
            const h = Object.assign({}, root.jobHero); h[a.pkg] = a.hero || (a.shots?.[0]?.path ?? ""); root.jobHero = h;
            const t = Object.assign({}, root.jobTone); t[a.pkg] = a.tone ?? ""; root.jobTone = t;
        } catch (e) {} } } }
    Process { id: searchProc
        stdout: StdioCollector { onStreamFinished: { try {
            const r = JSON.parse(text);
            if (root.found && r.query === root.found.query) root.found = Object.assign({}, root.found, { apps: r.apps });
        } catch (e) {} } } }
    Process { id: workProc
        stdout: SplitParser { onRead: line => {
            let msg = null; try { msg = JSON.parse(line); } catch (e) { return; }
            if (msg.progress !== undefined && root.work) root.work = Object.assign({}, root.work, { progress: msg.progress, phase: msg.phase });
            if (msg.result !== undefined && root.work) {
                const o = Object.assign({}, root.outcome); o[root.work.pkg] = msg.result; root.outcome = o;
                if (msg.result === "ok" && root.work.kind === "install") { root.justGot = root.work.pkg; tickTimer.restart(); }
            }
        } }
        onExited: { root.work = null; root.refresh(); } }
    Timer { id: tickTimer; interval: 2600; onTriggered: root.justGot = "" }

    // ---- colour: the ground, the inks measured on it (APCA, as Appearance.inkFor), the raised tones, the page's own colour
    FileView { id: termColors; path: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/terminal/sequences.txt`); blockLoading: true; printErrors: false }
    readonly property color ground: { const mm = /\]11;(#[0-9a-fA-F]{6})/.exec(termColors.text() || ""); return mm ? mm[1] : Appearance.m3colors.m3surfaceContainerLow; }
    function inkAt(lc) {
        const g = root.ground, ink = Appearance.m3colors.m3onBackground;
        const far = g.hslLightness < 0.5 ? "#ffffff" : "#000000";
        const at = t => t <= 1 ? ColorUtils.mix(ink, g, t) : ColorUtils.mix(far, ink, t - 1);
        let lo = 0, hi = 2;
        for (let i = 0; i < 18; i++) { const mid = (lo + hi) / 2; if (Math.abs(ColorUtils.apcaLc(at(mid), g)) < lc) lo = mid; else hi = mid; }
        return at(hi);
    }
    readonly property color inkMain: inkAt(92)
    readonly property color inkSec: inkAt(78)
    readonly property color raised: ColorUtils.mix(inkMain, ground, 0.07)
    readonly property color raisedHot: ColorUtils.mix(inkMain, ground, 0.12)
    readonly property color card: ColorUtils.mix(inkMain, ground, 0.045)
    readonly property string toneHex: page === "app" ? (appInfo?.tone ?? "") : page === "discover" ? (home?.feature?.tone ?? "")
                                      : page === "job" ? (jobTone[job?.pkgs?.[0] ?? ""] ?? "") : ""
    property color tint: toneHex ? toneHex : ground
    Behavior on tint { ColorAnimation { duration: 480; easing.type: Easing.OutCubic } }

    Rectangle { id: canvas; anchors.fill: parent; color: ColorUtils.transparentize(root.ground, Tacit.windowSeeThrough) }
    Rectangle {   // the page's colour, from its picture: a wash from the top
        parent: canvas; z: -1; width: parent.width; height: parent.height * 0.8
        gradient: Gradient {
            GradientStop { position: 0; color: ColorUtils.transparentize(root.tint, root.toneHex ? 0.78 : 1) }
            GradientStop { position: 1; color: ColorUtils.transparentize(root.tint, 1) } }
    }
    Component.onCompleted: MaterialThemeLoader.reapplyTheme()

    // ---- type: hierarchy by weight and size; large type tighter, small type a touch looser
    component Body: StyledText { color: root.inkMain; font.pixelSize: 17 }
    component Small: StyledText { color: root.inkSec; font.pixelSize: 15; font.letterSpacing: 0.15 }
    component Caption: Small { font.weight: Font.Medium }
    component Name: Body { font.weight: Font.DemiBold; font.letterSpacing: -0.1 }
    component Section: Body { font.pixelSize: 24; font.weight: Font.DemiBold; font.letterSpacing: -0.35 }
    component PageTitle: Body { font.pixelSize: 40; font.weight: Font.DemiBold; font.letterSpacing: -0.8 }
    component Headline: Body { font.pixelSize: 48; font.weight: Font.DemiBold; font.letterSpacing: -1.1; color: "white" }

    // ---- motion: springs, so a press, a lift and a growing capsule start from where they are and can turn back
    component Spring: SpringAnimation { spring: 5.5; damping: 0.42; mass: 1; epsilon: 0.004 }

    // ---- touch: anything that can be pressed takes a raised tone under the pointer and sinks a little when pressed
    component Press: Item {
        id: press
        signal picked()
        property int inset: 12
        property real rounding: 18
        property bool lit: true
        property bool lifts: false
        readonly property bool hovered: pressArea.containsMouse
        readonly property bool down: pressArea.pressed
        scale: down ? 0.975 : 1
        Behavior on scale { Spring {} }
        transform: Translate { y: press.lifts && press.hovered && !press.down ? -3 : 0; Behavior on y { Spring {} } }
        Rectangle {
            x: -press.inset; y: -press.inset; width: press.width + 2 * press.inset; height: press.height + 2 * press.inset; radius: press.rounding
            color: !press.lit ? "transparent" : press.down ? root.raisedHot : press.hovered ? root.raised : ColorUtils.transparentize(root.raised, 1)
            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        MouseArea { id: pressArea; x: -press.inset; y: -press.inset; width: press.width + 2 * press.inset; height: press.height + 2 * press.inset
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: press.picked() }
    }
    component Word: Item {
        id: wd
        property string text; property string glyph: ""; property color ink: root.inkSec
        signal picked()
        implicitWidth: wr.implicitWidth; implicitHeight: 28
        scale: wa.pressed ? 0.94 : 1
        Behavior on scale { Spring {} }
        Row { id: wr; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            MaterialSymbol { visible: wd.glyph !== ""; text: wd.glyph; iconSize: 18; anchors.verticalCenter: parent.verticalCenter
                color: wa.containsMouse ? root.inkMain : wd.ink; Behavior on color { ColorAnimation { duration: 120 } } }
            Body { text: wd.text; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.Medium
                color: wa.containsMouse && wd.ink === root.inkSec ? root.inkMain : wd.ink; Behavior on color { ColorAnimation { duration: 120 } } } }
        MouseArea { id: wa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wd.picked() }
    }
    // the one action of an app, as a capsule: Get in the accent, Open in the main ink; while getting it, it fills
    component Capsule: Item {
        id: cap
        property var a
        property bool large: false
        property bool onPicture: false
        readonly property string st: root.stateOf(a)
        readonly property bool got: root.justGot !== "" && root.justGot === a?.pkg
        readonly property string word: st === "getting" ? `${Math.round((root.work?.progress ?? 0) * 100)} %` : st === "removing" ? "Removing"
                                        : st === "installed" ? "Open" : st === "unavailable" ? "Not here" : "Get"
        visible: st !== "none"
        height: large ? 44 : 32
        width: Math.max(large ? 120 : 76, ct.implicitWidth + (got ? 30 : 0) + (large ? 48 : 32))
        Behavior on width { Spring {} }
        scale: ca.pressed ? 0.94 : 1
        Behavior on scale { Spring {} }
        Rectangle { anchors.fill: parent; radius: height / 2
            color: cap.onPicture ? Qt.rgba(1, 1, 1, ca.pressed ? 0.34 : ca.containsMouse ? 0.28 : 0.2) : ca.pressed ? root.raisedHot : ca.containsMouse ? ColorUtils.mix(root.inkMain, root.ground, 0.1) : root.raised
            Behavior on color { ColorAnimation { duration: 140 } } }
        Rectangle { visible: cap.st === "getting"; height: parent.height; radius: height / 2
            width: Math.max(height, parent.width * (root.work?.progress ?? 0)); color: ColorUtils.transparentize(Tacit.accent, 0.62)
            Behavior on width { Spring {} } }
        Row { anchors.centerIn: parent; spacing: 6
            MaterialSymbol { visible: cap.got; text: "check"; iconSize: cap.large ? 20 : 17; color: cap.onPicture ? "white" : Tacit.accent; anchors.verticalCenter: parent.verticalCenter }
            Body { id: ct; anchors.verticalCenter: parent.verticalCenter; text: cap.word; font.pixelSize: cap.large ? 17 : 15; font.weight: Font.DemiBold; font.letterSpacing: 0.2
                color: cap.onPicture ? "white" : cap.st === "get" ? Tacit.accent : cap.st === "unavailable" ? root.inkSec : root.inkMain } }
        MouseArea { id: ca; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; enabled: cap.st === "get" || cap.st === "installed"
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.act(cap.a) }
    }
    component AppIcon: Image {
        property string src
        source: src ? "file://" + src : ""
        sourceSize: Qt.size(256, 256); smooth: true; mipmap: true
    }
    component Pic: Item {
        id: pc
        property string src; property int r: 22; property bool zoom: false
        Rectangle { id: mk; anchors.fill: parent; radius: pc.r; visible: false }
        Rectangle { anchors.fill: parent; radius: pc.r; color: root.card }
        Item { anchors.fill: parent; layer.enabled: true; layer.effect: OpacityMask { maskSource: mk }
            Image { anchors.fill: parent; source: pc.src ? "file://" + pc.src : ""; fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; asynchronous: true
                opacity: status === Image.Ready ? 1 : 0; Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                scale: pc.zoom ? 1.04 : 1; Behavior on scale { Spring { spring: 2.2; damping: 0.6 } } } }
        Rectangle { anchors.fill: parent; radius: pc.r; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06) }
    }
    component Shade: Item {
        id: shade
        property string tone: ""
        property int r: 22
        readonly property color deep: tone ? ColorUtils.mix(tone, "#000000", 0.22) : "#000000"
        Rectangle { anchors.fill: parent; radius: shade.r; gradient: Gradient { GradientStop { position: 0.35; color: "transparent" } GradientStop { position: 1; color: ColorUtils.transparentize(shade.deep, 0.22) } } }
    }

    // ---- the one app lockup: its icon, its name, what it is, what it costs, its capsule
    component Lockup: Press {
        id: lk
        property var a
        property int icon: 64
        width: 400; height: icon + 8
        visible: !!a
        rounding: 18
        onPicked: root.openApp(a.pkg)
        AppIcon { src: lk.a?.icon ?? ""; width: lk.icon; height: lk.icon; anchors.verticalCenter: parent.verticalCenter
            scale: lk.hovered ? 1.05 : 1; Behavior on scale { Spring {} } }
        Column { x: lk.icon + 18; anchors.verticalCenter: parent.verticalCenter; spacing: 2; width: lk.width - lk.icon - 18 - capsule.width - 16
            Name { text: lk.a?.name ?? ""; width: parent.width; elide: Text.ElideRight }
            Small { text: lk.a?.like || lk.a?.line || ""; width: parent.width; elide: Text.ElideRight }
            Small { text: root.costWords(lk.a); width: parent.width; elide: Text.ElideRight; color: ColorUtils.mix(root.inkSec, root.ground, 0.82) } }
        Capsule { id: capsule; a: lk.a; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
    }
    // an editorial card: its picture, what you can do in large type, and the app on an inset strip (concentric: 22 / 14 at 8 in)
    component Story: Press {
        id: story
        property string picture; property string tone; property string label; property string headline; property var a
        inset: 0; lit: false; lifts: true; rounding: 22
        onPicked: if (a) root.openApp(a.pkg)
        Pic { anchors.fill: parent; src: story.picture; zoom: story.hovered; r: 22 }
        Shade { anchors.fill: parent; tone: story.tone; r: 22 }
        Column { x: 32; anchors.bottom: strip.top; anchors.bottomMargin: 24; spacing: 6; width: story.width - 64
            Caption { text: story.label; color: Qt.rgba(1, 1, 1, 0.84) }
            Headline { text: story.headline; width: parent.width; wrapMode: Text.Wrap; font.pixelSize: story.width > 700 ? 48 : 36 } }
        Rectangle {
            id: strip
            x: 8; y: story.height - height - 8; width: story.width - 16; height: 80; radius: 14
            color: ColorUtils.transparentize(ColorUtils.mix(story.tone || "#000000", "#000000", 0.18), 0.32)
            Row { x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 14
                AppIcon { src: story.a?.icon ?? ""; width: 48; height: 48; anchors.verticalCenter: parent.verticalCenter }
                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 1
                    Name { text: story.a?.name ?? ""; color: "white" }
                    Small { text: story.a?.line ?? ""; color: Qt.rgba(1, 1, 1, 0.8); width: strip.width - 230; elide: Text.ElideRight } } }
            Capsule { a: story.a; onPicture: true; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- the control layer: tabs or Back, and the search; it floats over the page and fills in once the page scrolls
    Item {
        id: topRow
        parent: canvas; z: 3
        width: root.width; height: 88
        readonly property real filled: Math.max(0, Math.min(1, (scroller.contentY + scroller.topMargin) / 40))
        Rectangle { anchors.fill: parent; color: root.ground; opacity: topRow.filled }
        Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: root.inkMain; opacity: topRow.filled * 0.08 }
        Row {
            x: root.m; anchors.verticalCenter: parent.verticalCenter; spacing: 32
            visible: root.page !== "app"
            Repeater {
                model: [["Discover", "discover"], ["Your apps", "yours"]]
                Item {
                    required property var modelData
                    readonly property bool on: modelData[1] === "yours" ? root.page === "yours" : root.page !== "yours"
                    width: tl.width; height: 32
                    Body { id: tl; text: modelData[0]; font.weight: parent.on ? Font.DemiBold : Font.Medium
                        color: parent.on || tabArea.containsMouse ? root.inkMain : root.inkSec; Behavior on color { ColorAnimation { duration: 140 } } }
                    Rectangle { y: 30; height: 2; radius: 1; color: Tacit.accent; width: parent.on ? tl.width : 0; x: (tl.width - width) / 2
                        Behavior on width { Spring {} } }
                    MouseArea { id: tabArea; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { field.text = ""; if (parent.modelData[1] === "yours") { if (root.page !== "yours") root.go("yours"); } else { root.history = []; root.page = "discover"; } } }
                }
            }
        }
        Word { visible: root.page === "app"; x: root.m - 4; anchors.verticalCenter: parent.verticalCenter; text: "Back"; glyph: "arrow_back"; onPicked: root.back() }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(640, root.width - 2 * root.m - 520); height: 48; radius: 24
            color: Qt.rgba(1, 1, 1, field.activeFocus || field.text ? 0.10 : (fieldHover.containsMouse ? 0.075 : 0.06))
            Behavior on color { ColorAnimation { duration: 160 } }
            MaterialSymbol { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "search"; iconSize: 21; color: field.activeFocus ? root.inkMain : root.inkSec }
            TextInput {
                id: field
                x: 50; width: parent.width - 70; anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 17; font.family: Appearance.font.family.main; color: root.inkMain
                selectionColor: ColorUtils.transparentize(Tacit.accent, 0.6); clip: true
                cursorDelegate: Rectangle { width: 2; color: Tacit.accent; visible: field.activeFocus }
                onTextChanged: searchDelay.restart()
                Keys.onReturnPressed: { searchDelay.stop(); root.runSearch(text); }
                Keys.onEscapePressed: { if (text) text = ""; else root.back(); }
            }
            Body { x: 50; anchors.verticalCenter: parent.verticalCenter; visible: !field.text; text: "What do you want to do?"; color: root.inkSec }
            MouseArea { id: fieldHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; cursorShape: Qt.IBeamCursor }
            Timer { id: searchDelay; interval: 280; onTriggered: if (field.text.trim().length >= 2) root.runSearch(field.text) }
        }
    }
    Shortcut { sequences: ["Ctrl+F", "Ctrl+K"]; onActivated: field.forceActiveFocus() }
    Shortcut { sequence: "Escape"; enabled: !field.activeFocus; onActivated: root.back() }

    function reveal() { pageIn.stop(); pages.opacity = 0; pages.y = 10; scroller.contentY = -scroller.topMargin; pageIn.restart(); }
    ParallelAnimation { id: pageIn
        Anim { target: pages; property: "opacity"; to: 1; type: Anim.DefaultEffects }
        SpringAnimation { target: pages; property: "y"; to: 0; spring: 4.5; damping: 0.5; epsilon: 0.05 } }

    // ---- the content layer: it scrolls under the controls
    Flickable {
        id: scroller
        parent: canvas
        anchors.fill: parent
        topMargin: 88
        contentWidth: width
        contentHeight: pages.childrenRect.height + 72
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar { topPadding: 92 }
        GlideWheel { view: scroller; gain: 1.6; gainPerSpeed: 3; gainMax: 6 }

        Item {
            id: pages
            width: root.width

            // ---- Discover: two stories; then a shelf for every job, its apps as lockups
            Column {
                visible: root.page === "discover"
                x: root.m; width: root.cw
                Row {
                    spacing: 24
                    Story {
                        width: Math.round((root.cw - 24) * 0.62); height: 480
                        readonly property var j: root.jobOf(root.home?.feature?.pkg ?? "")
                        a: root.appOf(root.home?.feature?.pkg ?? "")
                        picture: root.home?.feature?.picture ?? ""; tone: root.home?.feature?.tone ?? ""
                        label: "Picked this week"; headline: j ? j.name : (a?.name ?? "")
                    }
                    Story {
                        width: root.cw - 24 - Math.round((root.cw - 24) * 0.62); height: 480
                        readonly property var p: root.home?.picks?.[0] ?? null
                        readonly property var j: root.jobOf(p?.pkg ?? "")
                        a: root.appOf(p?.pkg ?? ""); picture: p?.picture ?? ""; tone: p?.tone ?? ""
                        label: "Also this week"; headline: j ? j.name : (a?.name ?? "")
                    }
                }
                Item { width: 1; height: 72 }
                Repeater {
                    model: root.home?.jobs ?? []
                    Column {
                        required property var modelData
                        width: root.cw
                        Item {
                            width: root.cw; height: 34
                            Section { text: modelData.name; anchors.verticalCenter: parent.verticalCenter }
                            Word { visible: modelData.pkgs.length > 1; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: "See all"; glyph: "chevron_right"; onPicked: root.openJob(modelData) }
                        }
                        Item { width: 1; height: 4 }
                        Small { text: modelData.advice; width: root.cw; wrapMode: Text.Wrap; font.pixelSize: 16 }
                        Item { width: 1; height: 24 }
                        Grid {
                            columns: 3; columnSpacing: 48; rowSpacing: 24
                            Repeater { model: modelData.pkgs.slice(0, 6)
                                Lockup { required property string modelData; a: root.appOf(modelData); width: (root.cw - 96) / 3 } }
                        }
                        Item { width: 1; height: 64 }
                    }
                }
            }

            // ---- a job: its name, the best match as a story, every app as a lockup
            Column {
                visible: root.page === "job" && root.job !== null
                x: root.m; width: root.cw
                PageTitle { text: root.job?.name ?? "" }
                Item { width: 1; height: 8 }
                Small { font.pixelSize: 17; text: root.job?.advice ?? "" }
                Item { width: 1; height: 32 }
                Story {
                    width: root.cw; height: 420
                    a: root.appOf(root.job?.pkgs?.[0] ?? "")
                    picture: root.jobHero[root.job?.pkgs?.[0] ?? ""] ?? ""; tone: root.jobTone[root.job?.pkgs?.[0] ?? ""] ?? ""
                    label: "Best match"; headline: [a?.like, a?.name].filter(x => x).join(": ")
                }
                Item { width: 1; height: 48 }
                Grid {
                    columns: 3; columnSpacing: 48; rowSpacing: 24
                    Repeater { model: (root.job?.pkgs ?? []).slice(1)
                        Lockup { required property string modelData; a: root.appOf(modelData); width: (root.cw - 96) / 3 } }
                }
            }

            // ---- search: the matching job first, then the catalogue's matches, all as lockups
            Column {
                visible: root.page === "search" && root.found !== null
                x: root.m; width: root.cw
                PageTitle { text: root.found?.job ? root.found.job.name : `“${root.query.trim()}”` }
                Item { width: 1; height: 8 }
                Small { font.pixelSize: 17
                    text: root.found?.job ? root.found.job.advice : (root.found?.apps?.length ?? 0) ? `${root.found.apps.length} apps match.` : "Looking…" }
                Item { width: 1; height: 32 }
                Grid {
                    columns: 3; columnSpacing: 48; rowSpacing: 24
                    Repeater { model: root.found?.job ? root.found.job.pkgs : []
                        Lockup { required property string modelData; a: root.appOf(modelData); width: (root.cw - 96) / 3 } }
                }
                Item { visible: !!root.found?.job && (root.found?.apps?.length ?? 0) > 0; width: 1; height: 56 }
                Section { visible: !!root.found?.job && (root.found?.apps?.length ?? 0) > 0; text: "Other apps that match" }
                Item { visible: !!root.found?.job; width: 1; height: 24 }
                Grid {
                    columns: 3; columnSpacing: 48; rowSpacing: 24
                    Repeater { model: (root.found?.apps ?? []).filter(x => !(root.found?.job?.pkgs ?? []).includes(x.pkg)).slice(0, 12)
                        Lockup { required property var modelData; a: modelData; width: (root.cw - 96) / 3 } }
                }
            }

            // ---- an app: the essentials first (icon, name, what it is, Get, the facts), then its pictures, then the rest
            Column {
                id: appPage
                visible: root.page === "app"
                x: root.m; width: root.cw
                readonly property var a: root.appInfo
                readonly property string st: root.stateOf(a)
                readonly property string said: a ? (root.outcome[a.pkg] ?? "") : ""
                readonly property string w: said && said !== "ok" ? said : (st === "unavailable" ? "unavailable"
                                            : (a?.plan?.can === false && a?.plan?.why !== "installed" ? (a?.plan?.why ?? "") : ""))
                Item {
                    width: root.cw; height: 152
                    AppIcon { id: bigIcon; src: appPage.a?.icon ?? ""; width: 144; height: 144 }
                    Column { x: 176; anchors.verticalCenter: bigIcon.verticalCenter; spacing: 4; width: root.cw - 176 - 260
                        PageTitle { text: appPage.a?.name ?? "…"; width: parent.width; elide: Text.ElideRight }
                        Body { text: [appPage.a?.like, appPage.a?.line].filter(x => x).join(". "); color: root.inkSec; width: parent.width; wrapMode: Text.Wrap }
                        Small { text: appPage.a?.developer ?? "" } }
                    Column { anchors.right: parent.right; anchors.verticalCenter: bigIcon.verticalCenter; spacing: 10
                        Capsule { a: appPage.a; large: true; anchors.right: parent.right }
                        Small { anchors.right: parent.right; horizontalAlignment: Text.AlignRight
                            text: appPage.st === "getting" ? (root.work?.phase ?? "") : root.justGot === appPage.a?.pkg ? "It's in your apps now."
                                  : appPage.st === "installed" ? "On this computer"
                                  : [appPage.a?.plan?.download ? `${appPage.a.plan.download} MB` : "", appPage.a?.free === false ? "Free to use" : "Free"].filter(x => x).join(" · ") } }
                }
                Column {
                    visible: appPage.w !== "" && !["getting", "removing"].includes(appPage.st)
                    width: root.cw; spacing: 4
                    Item { width: 1; height: 16 }
                    Body { text: (root.outcomeWords[appPage.w] ?? ["", ""])[0]; font.weight: Font.DemiBold }
                    Small { text: (root.outcomeWords[appPage.w] ?? ["", ""])[1]; font.pixelSize: 16 }
                    Item { width: 1; height: 8 }
                    Word { visible: ["cancelled", "busy", "offline", "failed"].includes(appPage.w); text: "Try again"; glyph: "refresh"; ink: root.inkMain; onPicked: root.get(appPage.a.pkg) }
                }
                Item { width: 1; height: 32 }
                Row {
                    Repeater {
                        model: [["Size", appPage.a?.plan?.need ? `${appPage.a.plan.need} MB` : appPage.a?.size ? `${appPage.a.size} MB` : "–"],
                                ["Licence", appPage.a ? (appPage.a.free ? "Open source" : "Closed source") : "–"],
                                ["Version", appPage.a?.version || "–"],
                                ["Made by", appPage.a?.developer || "–"],
                                ["Kind", root.jobOf(appPage.a?.pkg ?? "")?.name ?? "App"]]
                        Item {
                            required property var modelData; required property int index
                            width: root.cw / 5; height: 64
                            Rectangle { visible: index > 0; width: 1; height: 40; anchors.verticalCenter: parent.verticalCenter; color: root.inkMain; opacity: 0.1 }
                            Column { x: index > 0 ? 24 : 0; anchors.verticalCenter: parent.verticalCenter; spacing: 4; width: parent.width - 32
                                Caption { text: modelData[0] }
                                Name { text: modelData[1]; width: parent.width; elide: Text.ElideRight } }
                        }
                    }
                }
                Item { width: 1; height: 40 }
                Item {
                    width: root.cw + root.m; height: (appPage.a?.shots?.length ?? 0) > 0 ? 400 : 0
                    visible: height > 0; clip: true
                    Flickable {
                        anchors.fill: parent; contentWidth: shotRow.width + root.m; contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
                        Row { id: shotRow; spacing: 20
                            Repeater { model: appPage.a?.shots ?? []
                                Press { id: sp; required property var modelData
                                    width: 640; height: 400; inset: 0; lit: false; lifts: true; rounding: 18
                                    Pic { anchors.fill: parent; src: sp.modelData.path; r: 18; zoom: sp.hovered } } } }
                    }
                }
                Item { width: 1; height: 48 }
                Row {
                    spacing: 64
                    Column { width: (root.cw - 64) * 0.58; spacing: 10
                        Section { visible: (appPage.a?.description?.length ?? 0) > 0; text: "About" }
                        Body { width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.3; text: (appPage.a?.description ?? []).join("\n\n") } }
                    Column { width: (root.cw - 64) * 0.42; spacing: 10; visible: (appPage.a?.whatsNew?.length ?? 0) > 0
                        Section { text: "What's new" }
                        Small { text: `Version ${appPage.a?.version ?? ""}` }
                        Body { width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.3; maximumLineCount: 8; elide: Text.ElideRight; text: (appPage.a?.whatsNew ?? []).join(" ") } }
                }
                Item { width: 1; height: 24 }
                Word { visible: !!appPage.a?.homepage; text: "Its website"; glyph: "open_in_new"; onPicked: Qt.openUrlExternally(appPage.a.homepage) }
            }

            // ---- Your apps: every app from here on this computer, as lockups, with Remove beside each
            Column {
                id: yoursPage
                visible: root.page === "yours"
                x: root.m; width: root.cw
                readonly property var list: (root.home?.installed ?? []).map(p => root.appOf(p)).filter(x => x)
                PageTitle { text: "Your apps" }
                Item { width: 1; height: 8 }
                Small { font.pixelSize: 17; text: "Apps from this store that are on this computer. They update with Tacit's system updates." }
                Item { width: 1; height: 40 }
                Small { visible: yoursPage.list.length === 0; font.pixelSize: 17; text: "None yet. Apps you get here are listed here." }
                Repeater {
                    model: yoursPage.list
                    Column {
                        required property var modelData
                        readonly property string said: root.outcome[modelData.pkg] ?? ""
                        Item {
                            width: Math.min(root.cw, 1000); height: 80
                            Lockup { a: modelData; width: parent.width - 160; anchors.verticalCenter: parent.verticalCenter }
                            Word { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: root.work?.pkg === modelData.pkg ? "Removing…" : "Remove"; glyph: "delete"; ink: Tacit.risk; onPicked: root.removeApp(modelData.pkg) }
                        }
                        Small { visible: parent.said !== "" && parent.said !== "ok"; x: 82; text: (root.outcomeWords[parent.said] ?? ["", ""]).join(". ") }
                        Item { width: 1; height: 16 }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "store"
        function present(): void { root.visible = true; root.raise(); root.requestActivate(); }
        function page(name: string): void { if (name === "yours") root.go("yours"); else { root.history = []; root.page = "discover"; } present(); }
        function search(words: string): void { field.text = words; root.runSearch(words); present(); }
        function state(): string { return JSON.stringify({ page: root.page, loaded: !!root.home, work: root.work, outcome: root.outcome }); }
    }

    // ---- STORE_RENDER=<dir>: the pages with real data, saved as pictures, then quit (for checking the look)
    property int renderStep: 0
    Timer {
        running: root.renderDir !== "" && !!root.home
        interval: 6000; repeat: true
        onTriggered: {
            const steps = [
                () => { root.page = "discover"; scroller.contentY = -scroller.topMargin; },
                () => { scroller.contentY = 520; },
                () => { scroller.contentY = 1200; },
                () => root.openJob(root.home.jobs[0]),
                () => { field.text = "call family"; root.runSearch("call family"); },
                () => root.openApp("pinta"),
                () => { scroller.contentY = 520; },
                () => { root.history = []; root.go("yours"); }
            ];
            const next = () => { if (root.renderStep >= steps.length) { Qt.quit(); return; } steps[root.renderStep](); root.renderStep++; };
            if (root.renderStep === 0) { next(); return; }
            const n = String(root.renderStep).padStart(2, "0");
            canvas.grabToImage(g => { g.saveToFile(`${root.renderDir}/${n}.png`); next(); });
        }
    }
}
