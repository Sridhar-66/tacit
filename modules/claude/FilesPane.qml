import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../code"

/**
 * Files, in the side panel: what this session read and changed (newest first, from the
 * conversation), then the project's tree when the session runs in a git repository (Code's tree,
 * with its change colours). A file opens here read-only (FileViewer), as a chip beside the
 * others; the conversation's file links open here at their line too. Ctrl+click anywhere, or
 * the header's button, opens the file in Code instead.
 */
Item {
    id: pane
    // Diff colours that read at a glance on the near-black panel, as Claude Desktop's do: the calm
    // palette's success/error containers are grey-greens that sank into it.
    readonly property color addFill: "#234A2D"
    readonly property color delFill: "#4E2428"
    readonly property color addInk: "#E6F4E8"
    readonly property color delInk: "#FBE3E1"
    readonly property color addMark: "#7BD88F"
    readonly property color delMark: "#F28B82"

    property string cwd: ""
    property string sessionId: ""
    property var items: []            // the conversation (its loaded part)
    property var changes: ({ files: [] })   // every file the session changed (the host's list)
    property var tabs: []
    signal tabPicked(string key)
    signal closeRequested()

    readonly property string home: Quickshell.env("HOME")
    property var opened: []           // paths, as chips
    property string active: ""        // the file showing; "" = the list

    function full(p) { return p.startsWith("~/") ? pane.home + p.substring(1) : p; }
    function short(p) { return p.startsWith(pane.home + "/") ? "~" + p.substring(pane.home.length) : p; }
    // a file you pick stops following Claude; one the follow opens does not
    function open(path, line, find, byFollow) {
        const p = pane.full(path);
        if (!byFollow) pane.follow = false;
        if (!pane.opened.includes(p)) pane.opened = pane.opened.concat([p]);
        pane.active = p;
        viewer.goTo(line, find);
    }
    function show(p) { pane.follow = pane.follow && p === pane.active; pane.active = p; }
    function close(p) {
        const i = pane.opened.indexOf(p);
        pane.opened = pane.opened.filter(x => x !== p);
        if (pane.active === p) pane.active = pane.opened[Math.min(i, pane.opened.length - 1)] ?? "";
    }
    // where a path lives, said short: inside the project from its root, else from ~
    function place(dir) {
        if (pane.repo.length && (dir === pane.repo || dir.startsWith(pane.repo + "/"))) return project.name + dir.substring(pane.repo.length);
        return pane.short(dir);
    }

    // ── follow: this turn's edits open as Claude makes them ───────────────
    property bool follow: true
    readonly property var lastEdit: {
        for (let i = pane.items.length - 1; i >= 0; i--) {
            const it = pane.items[i];
            if (it.role === "user" && it.kind === "text") return null;
            if (it.kind === "tool" && (it.files ?? []).length === 1)
                return { key: `${it.ts ?? i}|${it.files[0].path}`, path: it.files[0].path,
                         find: ((it.new ?? "").split("\n").find(l => l.trim().length) ?? "").trim() };
        }
        return null;
    }
    property string lastEditKey: ""
    property bool primed: false      // the session's edits so far are history: only new ones are followed
    onLastEditChanged: {
        const e = pane.lastEdit;
        if (!e || e.key === pane.lastEditKey) return;
        pane.lastEditKey = e.key;
        if (pane.primed && pane.follow) pane.open(e.path, 0, e.find, true);
    }
    onSessionIdChanged: { pane.opened = []; pane.active = ""; pane.follow = true; pane.primed = false; pane.lastEditKey = pane.lastEdit ? pane.lastEdit.key : ""; primeLater.restart(); }
    Timer { id: primeLater; interval: 1500; onTriggered: { pane.lastEditKey = pane.lastEdit ? pane.lastEdit.key : ""; pane.primed = true; } }
    function setFollow(on) {
        pane.follow = on;
        if (on && pane.lastEdit) pane.open(pane.lastEdit.path, 0, pane.lastEdit.find, true);
    }

    function openInCode(p, line) {
        Quickshell.execDetached([`${pane.home}/.local/bin/code-file`, p, String(line ?? 0)]);
    }

    // ── what the session touched: edits, new files, reads; newest first ────
    // The loaded conversation gives the order and the reads; the host's list the totals and the
    // files changed earlier than what is loaded (after the rest, latest first).
    readonly property var touched: {
        const seen = {}, out = [], total = {};
        for (const f of pane.changes.files ?? []) total[f.path] = f;
        for (let i = pane.items.length - 1; i >= 0; i--) {
            const it = pane.items[i];
            if (it.kind !== "tool") continue;
            let list = [];
            if ((it.files ?? []).length) list = it.files.map(f => ({ path: f.path, kind: f.kind === "write" ? "write" : "edit", add: f.add ?? 0, del: f.del ?? 0 }));
            // Codex reads a picture with view_image, its summary the full path
            else if ((it.tool === "Read" || it.tool === "view_image") && (it.summary ?? "").length) list = [{ path: pane.full(it.summary), kind: "read", add: 0, del: 0 }];
            for (const f of list) {
                const e = seen[f.path];
                if (e) { if (e.kind === "read" && f.kind !== "read") e.kind = f.kind; e.add += f.add; e.del += f.del; continue; }
                seen[f.path] = f;
                out.push(f);
            }
        }
        for (const f of out) if (total[f.path]) { f.add = total[f.path].add ?? f.add; f.del = total[f.path].del ?? f.del; }
        for (const f of (pane.changes.files ?? []).slice().reverse())
            if (!seen[f.path]) out.push({ path: f.path, kind: f.created ? "write" : "edit", add: f.add ?? 0, del: f.del ?? 0 });
        return out;
    }

    // the list's rows: what the session edited, newest first, each with its folder beside it; what it
    // only read folds into one line (a session reads dozens of files and pictures it never changes)
    property bool showRead: false
    readonly property var touchedRows: {
        const edited = pane.touched.filter(f => f.kind !== "read");
        const read = pane.touched.filter(f => f.kind === "read");
        const out = [];
        if (edited.length) {
            out.push({ dir: true, label: "Edited" });
            for (const f of edited) out.push(Object.assign({ dir: false }, f));
        }
        if (read.length) {
            out.push({ dir: true, label: "Read", more: pane.showRead ? "Hide" : `${read.length} ${read.length === 1 ? "file" : "files"}` });
            if (pane.showRead) for (const f of read) out.push(Object.assign({ dir: false }, f));
        }
        return out;
    }

    // ── the project: the git repository the session runs in, if any ────────
    property string repo: ""
    onCwdChanged: pane.findRepo()
    Component.onCompleted: { pane.findRepo(); primeLater.start(); }
    // the command is set here, not bound: a binding could still hold the last folder when it starts
    function findRepo() {
        pane.repo = "";
        topProc.running = false;
        if (!pane.cwd.length) return;
        topProc.command = ["git", "-C", pane.cwd, "rev-parse", "--show-toplevel"];
        topProc.running = true;
    }
    Process {
        id: topProc
        stdout: StdioCollector { onStreamFinished: { const t = this.text.trim(); pane.repo = t; if (t.length && project.root !== t) project.setRoot(t); } }
    }
    CodeProject { id: project }

    // ── header: the panel's tabs; for a file, Code and Files ───────────────
    component Act: MaterialSymbol {
        id: actGlyph
        property string tip: ""
        signal clicked()
        iconSize: 16
        color: actArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
        MouseArea { id: actArea; anchors { fill: parent; margins: -5 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actGlyph.clicked() }
        StyledToolTip { text: actGlyph.tip; extraVisibleCondition: actArea.containsMouse }
    }
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 56
        PanelTabs {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            names: pane.tabs
            current: "files"
            onPicked: key => pane.tabPicked(key)
        }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 } height: 1; color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93) }
        Row {
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            spacing: 14
            Act {
                visible: pane.lastEdit !== null
                text: "my_location"
                fill: pane.follow ? 1 : 0
                color: pane.follow ? Appearance.colors.colPrimary : Appearance.colors.colInkSecondary
                tip: pane.follow ? "Following Claude's edits" : "Follow Claude's edits"
                onClicked: pane.setFollow(!pane.follow)
            }
            Act { visible: pane.active.length > 0; text: "folder_open"; tip: "Show in Files"; onClicked: Quickshell.execDetached(["qs", "-p", Directories.shellFile, "ipc", "call", "files", "reveal", pane.active]) }
            Act { visible: pane.active.length > 0; text: "open_in_new"; tip: "Open in Graphis"; onClicked: pane.openInCode(pane.active, 0) }
            Act { text: "close"; iconSize: 18; tip: "Close (Ctrl+Alt+B)"; onClicked: pane.closeRequested() }
        }
    }

    // the list, then one chip per open file (the composer's chip)
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string glyph: ""
        property bool on: false
        property bool closable: false
        signal clicked()
        signal closed()
        width: chipRow.implicitWidth + 20
        height: 28
        radius: 14
        color: chip.on ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.88) : chipArea.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.92) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: m => { if (m.button === Qt.MiddleButton && chip.closable) chip.closed(); else chip.clicked(); } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol { visible: chip.glyph.length > 0; text: chip.glyph; iconSize: 15; anchors.verticalCenter: parent.verticalCenter; color: chip.on ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary }
            StyledText { visible: chip.label.length > 0; text: chip.label; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; color: chip.on ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary }
            MaterialSymbol {
                visible: chip.closable && (chip.on || chipArea.containsMouse)
                text: "close"
                iconSize: 13
                anchors.verticalCenter: parent.verticalCenter
                color: xArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
                MouseArea { id: xArea; anchors { fill: parent; margins: -4 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.closed() }
            }
        }
    }
    Item {
        id: chipRow
        visible: pane.opened.length > 0
        anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; top: header.bottom; topMargin: 8 }
        height: 28
    }
    ListView {
        id: chips
        visible: pane.opened.length > 0
        anchors { left: chipRow.left; right: chipRow.right; top: chipRow.top }
        height: 28
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: [""].concat(pane.opened)
        delegate: Chip {
            required property string modelData
            glyph: modelData.length ? "" : "list"
            label: modelData.length ? modelData.split("/").pop() : ""
            on: pane.active === modelData
            closable: modelData.length > 0
            onClicked: pane.show(modelData)
            onClosed: pane.close(modelData)
        }
    }
    // the open file's place, quietly
    StyledText {
        id: where
        visible: pane.active.length > 0
        anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 20; top: chipRow.bottom; topMargin: 10 }
        rightPadding: 90
        text: pane.place(pane.active.substring(0, pane.active.lastIndexOf("/"))) + (viewer.isImage || !viewer.loaded || viewer.problem.length ? "" : `  ·  ${viewer.lineCount} lines`)
        elide: Text.ElideMiddle
        font.pixelSize: 13
        color: Appearance.colors.colInkSecondary
        StyledText {
            visible: viewer.isMarkdown
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: viewer.showSource ? "Preview" : "Source"
            font.pixelSize: 13
            color: mdArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
            MouseArea { id: mdArea; anchors { fill: parent; margins: -5 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: viewer.showSource = !viewer.showSource }
        }
        StyledText {
            visible: viewer.ext === "html" || viewer.ext === "htm"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "Open preview"
            font.pixelSize: 13
            color: htmlArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
            MouseArea { id: htmlArea; anchors { fill: parent; margins: -5 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("file://" + pane.active) }
        }
    }

    FileViewer {
        id: viewer
        visible: pane.active.length > 0
        anchors { left: parent.left; right: parent.right; top: where.bottom; topMargin: 8; bottom: parent.bottom }
        path: pane.active
        onOpenInCode: line => pane.openInCode(pane.active, line)
    }

    // ── the list ────────────────────────────────────────────────────────────
    Flickable {
        id: list
        visible: pane.active.length === 0
        anchors { left: parent.left; right: parent.right; top: chipRow.visible ? chipRow.bottom : header.bottom; topMargin: 4; bottom: parent.bottom }
        clip: true
        contentHeight: column.implicitHeight + 16
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar {}
        FastWheel { view: list }
        Column {
            id: column
            width: list.width

            Item { width: parent.width; height: 6 }
            Repeater {
                model: pane.touchedRows
                delegate: Item {
                    id: row
                    required property var modelData
                    width: column.width
                    height: row.modelData.dir ? 30 : 38
                    StyledText {
                        visible: row.modelData.dir
                        anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 20; bottom: parent.bottom; bottomMargin: 6 }
                        text: row.modelData.label ?? ""
                        elide: Text.ElideMiddle
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Appearance.colors.colInkSecondary
                    }
                    StyledText {
                        visible: row.modelData.dir && (row.modelData.more ?? "").length > 0
                        anchors { right: parent.right; rightMargin: 22; bottom: parent.bottom; bottomMargin: 6 }
                        text: `${row.modelData.more ?? ""} ›`
                        font.pixelSize: 12
                        color: rowArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
                    }
                    Rectangle {
                        visible: !row.modelData.dir
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        radius: 10
                        color: pane.active === row.modelData.path ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.92) : rowArea.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95) : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }
                    MaterialSymbol {
                        id: rowGlyph
                        visible: !row.modelData.dir
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        text: row.modelData.dir ? "" : tree.glyphFor(row.modelData.path.split("/").pop())
                        iconSize: 17
                        color: Appearance.colors.colInkSecondary
                    }
                    Row {
                        id: rowName
                        visible: !row.modelData.dir
                        anchors { left: rowGlyph.right; leftMargin: 12; right: rowStat.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        clip: true
                        StyledText { id: fileName; text: row.modelData.dir ? "" : row.modelData.path.split("/").pop(); font.pixelSize: 15; color: Appearance.colors.colInkMain }
                        StyledText {
                            anchors.baseline: fileName.baseline
                            width: Math.max(0, parent.width - fileName.width - 8)
                            // the folder by its last part: the full path is in the tooltip and one click away
                            text: row.modelData.dir ? "" : pane.place(row.modelData.path.substring(0, row.modelData.path.lastIndexOf("/"))).split("/").slice(-1)[0]
                            elide: Text.ElideMiddle
                            font.pixelSize: 13
                            color: Appearance.colors.colInkMeta
                        }
                    }
                    Row {
                        id: rowStat
                        visible: !row.modelData.dir
                        anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        StyledText { visible: row.modelData.kind === "read"; text: "read"; font.pixelSize: 13; color: Appearance.colors.colInkSecondary }
                        StyledText { visible: row.modelData.add > 0; text: `+${row.modelData.add}`; font.family: Appearance.font.family.numbers; font.pixelSize: 13; color: pane.addMark }
                        StyledText { visible: row.modelData.del > 0; text: `−${row.modelData.del}`; font.family: Appearance.font.family.numbers; font.pixelSize: 13; color: pane.delMark }
                    }
                    MouseArea {
                        id: rowArea
                        enabled: !row.modelData.dir || (row.modelData.more ?? "").length > 0
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => row.modelData.dir ? (pane.showRead = !pane.showRead)
                            : (m.modifiers & Qt.ControlModifier) ? pane.openInCode(row.modelData.path, 0) : pane.open(row.modelData.path, 0, "")
                    }
                }
            }

            Item {
                visible: pane.repo.length > 0
                width: parent.width
                height: 36
                StyledText { anchors { left: parent.left; leftMargin: 20; bottom: parent.bottom; bottomMargin: 7 } text: project.name; font.pixelSize: 13; font.weight: Font.DemiBold; color: Appearance.colors.colInkSecondary }
            }
            CodeTree {
                id: tree
                visible: pane.repo.length > 0
                width: column.width
                height: contentHeight
                interactive: false
                project: project
                onOpenFile: rel => pane.open(project.root + "/" + rel, 0, "")
                onWatchFile: rel => pane.open(project.root + "/" + rel, 0, "")
            }

            StyledText {
                visible: pane.touched.length === 0 && pane.repo.length === 0
                x: 20
                width: column.width - 40
                topPadding: 8
                text: "Files this session reads or changes show up here."
                wrapMode: Text.Wrap
                font.pixelSize: 14
                color: Appearance.colors.colInkSecondary
            }
        }
    }
}
