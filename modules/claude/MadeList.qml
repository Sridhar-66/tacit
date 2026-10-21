import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.tacit

/**
 * Made: the files a session outside a git repository made, newest first (the host's
 * changes.made). A row is the kind's glyph, or a thumbnail for a picture, the name, and kind,
 * size and time. ↵ opens it (a text file in Graphis through code-file, anything else through
 * xdg-open), ⇧↵ shows it in Pinax (files reveal), @ attaches it to the next message. A text file
 * a tool wrote opens (a click, or Space) to its newest edits, read from the conversation
 * (DiffView): there is no git diff here.
 */
Item {
    id: made
    property var entries: []          // changes.made: { path, kind, size, at, how }
    property var items: []            // the conversation, for a text file's edits
    property string cwd: ""
    property string sessionId: ""
    signal attachRequested(string path)
    // the commands ↵ and ⇧↵ run, as prefixes; tests point them at a fake
    property var opener: ["xdg-open"]
    property var editor: [`${Directories.tacitBin}/code-file`]
    property var shellIpc: ["qs", "-p", Directories.shellFile, "ipc", "call", "files"]

    // The host sends changes after every turn: the rows are rebuilt only when its list differs.
    property var shown: []
    property string shownText: ""
    function take() {
        const t = JSON.stringify(made.entries ?? []);
        if (t === made.shownText) return;
        made.shownText = t;
        made.shown = made.entries ?? [];
    }
    onEntriesChanged: made.take()
    Component.onCompleted: made.take()
    property string cursor: ""        // the path the keys act on
    property var open: ({})           // path -> its edits shown
    onSessionIdChanged: { made.cursor = ""; made.open = ({}); }

    readonly property var current: made.shown.find(m => m.path === made.cursor) ?? null
    readonly property bool anyEdits: made.shown.some(m => made.hasEdits(m))
    // Graphis opens plain text and source files (the code extensions of Things.kinds); a file of
    // another extension a tool wrote is text too
    readonly property var codeExts: ["qml", "js", "ts", "py", "sh", "fish", "lua", "c", "h", "cpp", "rs", "go", "java", "kt", "swift", "css", "html", "json", "toml", "yaml", "yml", "nix"]
    function isText(m) {
        if (m.kind === "text") return true;
        if (m.kind !== "other") return false;
        const name = m.path.split("/").pop(), dot = name.lastIndexOf(".");
        return m.how === "tool" || (dot > 0 && made.codeExts.includes(name.substring(dot + 1).toLowerCase()));
    }
    // its edits are in the conversation: a tool wrote it, not a command or a script
    function hasEdits(m) { return m.how === "tool" && made.isText(m); }
    function glyph(kind) {
        return ({ pdf: "picture_as_pdf", doc: "description", sheet: "table", slides: "slideshow", image: "image", video: "movie", text: "article" })[kind] ?? "draft";
    }
    // "PDF · 240 kB · made 14:02"; another day, "made 2 Oct"
    function detail(m) {
        const name = m.path.split("/").pop();
        const dot = name.lastIndexOf(".");
        const d = new Date(m.at ?? 0);
        const when = !((m.at ?? 0) > 0) ? ""
            : `made ${Qt.formatDateTime(d, d.toDateString() === new Date().toDateString() ? "hh:mm" : "d MMM")}`;
        return Voice.facts([dot > 0 ? name.substring(dot + 1).toUpperCase() : "", Voice.size(m.size ?? 0), when]);
    }
    readonly property string home: Quickshell.env("HOME")
    function tilde(p) { return p.startsWith(made.home + "/") ? "~" + p.substring(made.home.length) : p; }
    // the conversation's newest edits of one file, oldest first, and how many came before: at
    // most three, and past the newest only while they stay under 160 lines (a DiffView builds
    // every line it holds). Run on every conversation update while a file is open, so a plain
    // loop with nothing allocated per row
    function editsOf(path) {
        const items = made.items, out = [];
        const base = made.cwd + "/";
        const rel = path.startsWith(base) ? path.substring(base.length) : path;
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
            if (it.kind !== "tool" || !it.files) continue;
            const fs = it.files;
            for (let j = 0; j < fs.length; j++) {
                const p = fs[j].path;
                if (p === path || p === rel) {
                    if (it.old || it.new || it.patch) out.push(it);
                    break;
                }
            }
        }
        const list = [];
        let lines = 0;
        for (let i = out.length - 1; i >= 0 && list.length < 3; i--) {
            const e = out[i];
            const n = e.patch ? e.patch.split("\n").length : (e.old ?? "").split("\n").length + (e.new ?? "").split("\n").length;
            if (list.length && lines + n > 160) break;
            lines += n;
            list.unshift(e);
        }
        return { list: list, earlier: out.length - list.length };
    }

    function openFile(m) {
        Quickshell.execDetached(made.isText(m) ? made.editor.concat([m.path]) : made.opener.concat([m.path]));
    }
    function reveal(m) { Quickshell.execDetached(made.shellIpc.concat(["reveal", m.path])); }
    // moves the cursor only: a file's edits are built when it is opened (a click or Space)
    function step(by) {
        if (!made.shown.length) return;
        const at = made.shown.findIndex(m => m.path === made.cursor);
        const i = Math.max(0, Math.min(made.shown.length - 1, at < 0 ? 0 : at + by));
        made.cursor = made.shown[i].path;
        list.positionViewAtIndex(i, ListView.Contain);
    }
    function toggle(m) {
        const o = Object.assign({}, made.open);
        o[m.path] = !(o[m.path] ?? false);
        made.open = o;
    }
    // ↑↓ file · Space edits · ↵ open · ⇧↵ show in Pinax · @ attach; true when the key was one of them
    function handleKey(key, modifiers, text) {
        if (key === Qt.Key_Down) { made.step(1); return true; }
        if (key === Qt.Key_Up) { made.step(-1); return true; }
        const m = made.current;
        if (!m) return false;
        if (key === Qt.Key_Space) { if (made.hasEdits(m)) made.toggle(m); return true; }
        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            if (modifiers & Qt.ShiftModifier) made.reveal(m); else made.openFile(m);
            return true;
        }
        if (text === "@") { made.attachRequested(m.path); return true; }
        return false;
    }
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => { if (made.handleKey(e.key, e.modifiers, e.text)) e.accepted = true; }
    }

    // a quiet action glyph, as the review's
    component Act: MaterialSymbol {
        id: actGlyph
        property string tip: ""
        signal clicked()
        iconSize: 16
        color: actArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
        MouseArea { id: actArea; anchors { fill: parent; margins: -5 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actGlyph.clicked() }
        StyledToolTip { text: actGlyph.tip; extraVisibleCondition: actArea.containsMouse }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; bottomMargin: 4 }
        clip: true
        model: made.shown
        cacheBuffer: 600
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar {}
        GlideWheel { view: list; gain: 1.6; gainPerSpeed: 3; gainMax: 6 }
        delegate: Item {
            id: row
            required property var modelData
            readonly property var m: modelData
            readonly property bool picture: m.kind === "image"
            readonly property bool here: made.cursor === m.path
            readonly property bool opened: made.hasEdits(m) && (made.open[m.path] ?? false)
            // the edits under an open file; replaced only when they differ, so a streaming
            // conversation does not rebuild them
            property var edits: []
            property int earlier: 0
            property string editKeys: ""
            function readEdits() {
                const e = row.opened ? made.editsOf(row.m.path) : { list: [], earlier: 0 };
                const k = e.earlier + ":" + e.list.map(x => x.id ?? x.ts).join(",");
                if (k === row.editKeys) return;
                row.editKeys = k;
                row.earlier = e.earlier;
                row.edits = e.list;
            }
            onOpenedChanged: row.readEdits()
            Component.onCompleted: if (row.opened) row.readEdits()
            Connections { target: made; enabled: row.opened; function onItemsChanged() { row.readEdits(); } }
            width: ListView.view.width
            height: 50 + (row.opened ? edited.height + 8 : 0)

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 8; rightMargin: 8 }
                height: 50
                radius: Appearance.rounding.chip
                color: row.here || row.opened ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.92)
                    : rowArea.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95) : "transparent"
                Behavior on color { ColorAnimation { duration: 90 } }
            }
            ClippingRectangle {
                id: mark
                x: 20
                y: 12
                width: 26
                height: 26
                radius: Appearance.rounding.unsharpenmore
                color: row.picture ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95) : "transparent"
                Image {
                    id: thumb
                    anchors.fill: parent
                    source: row.picture ? `file://${row.m.path}` : ""
                    sourceSize: Qt.size(52, 52)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: thumb.status !== Image.Ready
                    text: made.glyph(row.m.kind)
                    iconSize: 20
                    color: Appearance.colors.colInkSecondary
                }
            }
            Column {
                // clear of the actions shown under the pointer, so the name does not reflow
                anchors { left: mark.right; leftMargin: 12; right: parent.right; rightMargin: 110; verticalCenter: mark.verticalCenter }
                spacing: 1
                StyledText {
                    width: parent.width
                    text: row.m.path.split("/").pop()
                    elide: Text.ElideMiddle
                    font.pixelSize: 15
                    color: Appearance.colors.colInkMain
                }
                StyledText {
                    width: parent.width
                    text: made.detail(row.m)
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    color: Appearance.colors.colInkMeta
                }
            }
            MouseArea {
                id: rowArea
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 50
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    made.cursor = row.m.path;
                    keys.forceActiveFocus();
                    if (made.hasEdits(row.m)) made.toggle(row.m);
                }
                onDoubleClicked: made.openFile(row.m)
            }
            Row {
                id: acts
                anchors { right: parent.right; rightMargin: 22; verticalCenter: mark.verticalCenter }
                visible: rowArea.containsMouse || actsHover.hovered
                spacing: 14
                HoverHandler { id: actsHover }
                Act { text: "open_in_new"; tip: made.isText(row.m) ? "Open in Graphis (↵)" : "Open (↵)"; onClicked: made.openFile(row.m) }
                Act { text: "folder_open"; tip: "Show in Pinax (⇧↵)"; onClicked: made.reveal(row.m) }
                Act { text: "attach_file"; tip: "Attach to the next message (@)"; onClicked: made.attachRequested(row.m.path) }
            }
            StyledToolTip { text: made.tilde(row.m.path); extraVisibleCondition: rowArea.containsMouse }

            Column {
                id: edited
                visible: row.opened
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 56; leftMargin: 16; rightMargin: 12 }
                spacing: 8
                StyledText {
                    visible: row.earlier > 0
                    x: 26
                    text: row.earlier === 1 ? "1 earlier edit" : `${row.earlier} earlier edits`
                    font.pixelSize: 13
                    color: Appearance.colors.colInkSecondary
                }
                Repeater {
                    model: row.edits
                    DiffView {
                        required property var modelData
                        width: edited.width
                        height: implicitHeight
                        item: modelData
                    }
                }
                StyledText {
                    visible: row.edits.length === 0
                    x: 26
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    text: "Its edits are further back in the conversation."
                    font.pixelSize: 13
                    color: Appearance.colors.colInkSecondary
                }
            }
        }
    }

    StyledText {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 24 }
        visible: made.shown.length === 0
        width: parent.width - 40
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: "Nothing made in this session."
        font.pixelSize: 14
        color: Appearance.colors.colInkSecondary
    }

    // the keys that work here, as the review's footer
    Column {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16; bottomMargin: 12 }
        spacing: 8
        visible: made.shown.length > 0
        Rectangle { width: parent.width; height: 1; color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93) }
        Item {
            width: parent.width
            height: 30
            clip: true
            Row {
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 14
                KeyCap { key: "↑↓"; label: "file" }
                KeyCap { visible: made.anyEdits; key: "Space"; label: "edits" }
                KeyCap { key: "↵"; label: "open" }
                KeyCap { key: "⇧↵"; label: "show in Pinax" }
                KeyCap { key: "@"; label: "attach" }
            }
        }
    }
}
