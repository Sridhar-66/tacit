import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Target mode: while something is carried over the rail (files or a page from outside, a
 * session, a folder heading) or a folder is picked by keys (New session in…), the rail shows
 * only its folders, as this layer over the list. The folders are taken once when it opens and
 * never rebuilt while it shows, so nothing moves under the pointer.
 *
 * It opens when purpose is set (drop, move, new or reorder) and closes when the rail sets it
 * back to "". It has no ground: the rail fades its list out by `shown`. pointAt and edgeScroll
 * take y in this item's frame. For keys the rail gives it focus after setting purpose. A commit
 * sends one signal; one with no target sends cancelled().
 * reordered(path, index): the folder's index in Files' pins without it, as `files move` takes it
 * (a folder not pinned yet is pinned there); -1 unpins it. For that index `folders` must hold
 * every pinned folder in Files' order, hidden (`hidden: true`) and non-local ones included;
 * they are counted but not shown.
 */
FocusScope {
    id: targets

    property string purpose: ""        // "" | drop | move | new | reorder
    property var folders: []           // FolderModel.targets: {fkey, path, name, pinned, local, hidden, live}
    property var carrying: ({})        // {label, lines, isFolder, path}
    property bool typing: false        // the name field replaces the first line: set by the rail or the first key typed; cleared on close

    signal chosen(string fkey)
    signal addFolder(string path)
    signal reordered(string path, int index)
    signal cancelled()

    readonly property bool active: targets.purpose !== ""
    property real shown: targets.active ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 140 } }
    // Never hidden: at opacity 0 it draws nothing, and a hidden item's rows are not laid out, which
    // would leave a pointAt in the opening event without rows. Closed, it takes no input.
    opacity: targets.shown
    enabled: targets.purpose !== ""
    onShownChanged: if (targets.shown === 0 && !targets.active) targets.entries = []

    // ── state ───────────────────────────────────────────────────────────────
    // entries: {kind: add|label|folder|pause|unpin|none, f, pin}: built when it opens, kept while it fades
    property var entries: []
    property int cursor: -1            // the entry under the pointer or the keys
    property int gap: -1               // reorder: the insertion point, 0..pinned count
    property bool done: false          // one commit per opening
    property real scrollSpeed: 0       // px/s, from edgeScroll
    property real lastY: -1
    property var pinOrder: []          // every pinned path in Files' order, shown or not: taken with entries
    property bool instant: false       // the opening event: the header takes its height at once
    readonly property string query: targets.typing ? field.text.trim().toLowerCase() : ""
    // which entries show; assigned before the entries it describes, so a row is born at its height
    property var vis: []

    // reads purpose, not active: this handler can run before active's binding has caught up
    onPurposeChanged: {
        targets.scrollSpeed = 0;
        if (targets.purpose === "") {
            targets.typing = false;
            return;
        }
        targets.instant = true;
        targets.pinOrder = (targets.folders ?? []).filter(f => f && f.pinned && (f.path ?? "") !== "").map(f => f.path);
        const e = targets.snapshot();
        targets.vis = targets.visOf(e, "");
        targets.entries = e;
        targets.cursor = -1;
        targets.gap = -1;
        targets.done = false;
        field.text = "";
        flick.contentY = 0;
        headCol.forceLayout();   // a pointAt in the same event finds the rows where they are drawn
        col.forceLayout();
        Qt.callLater(() => targets.instant = false);
    }
    onTypingChanged: if (targets.typing) field.focus = true
    // narrowed: the first match is chosen, so Enter takes it
    onQueryChanged: {
        targets.vis = targets.visOf(targets.entries, targets.query);
        if (targets.purpose !== "" && targets.purpose !== "reorder")
            targets.cursor = targets.query ? targets.targetList()[0] ?? -1 : -1;
    }
    onCarryingChanged: targets.vis = targets.visOf(targets.entries, targets.query)

    function snapshot() {
        const fs = (targets.folders ?? []).filter(f => f && f.local !== false && (f.path ?? "") !== "" && !f.hidden)
            .map(f => Object.assign({}, f, { live: Object.assign({}, f.live ?? {}) }));
        const out = [{ kind: "add" }, { kind: "label" }];
        fs.filter(f => f.pinned).forEach((f, i) => out.push({ kind: "folder", f: f, pin: i }));
        out.push({ kind: "pause" });
        if (targets.purpose === "reorder")
            out.push({ kind: "unpin" });
        else
            fs.filter(f => !f.pinned).forEach(f => out.push({ kind: "folder", f: f, pin: -1 }));
        out.push({ kind: "none" });
        return out;
    }

    // reorder: whether the carried heading is pinned, hidden or not (Files' order), and where it
    // sits among the shown pins (-1 when it is not shown)
    readonly property bool carriedPinned: targets.purpose === "reorder" && targets.pinOrder.includes(targets.carrying?.path ?? "")
    readonly property int carriedPin: {
        if (targets.purpose !== "reorder")
            return -1;
        const e = targets.entries.find(x => x.kind === "folder" && x.f.path === targets.carrying?.path);
        return e ? e.pin : -1;
    }
    readonly property int pinCount: targets.entries.filter(x => x.kind === "folder" && x.pin >= 0).length

    // gap g among the shown pins as an index in Files' pins without the carried path: before the
    // next shown pin, else after the last one, so pins not shown here keep their places
    function pinIndex(g) {
        const path = targets.carrying?.path ?? "";
        const rest = targets.pinOrder.filter(p => p !== path);
        const shown = targets.entries.filter(x => x.kind === "folder" && x.pin >= 0).map(x => x.f.path);
        const next = shown.slice(g).find(p => p !== path);
        if (next !== undefined)
            return rest.indexOf(next);
        const prev = shown.slice(0, g).filter(p => p !== path).pop();
        return prev !== undefined ? rest.indexOf(prev) + 1 : rest.length;
    }

    // the name filter, the Add slot, the pause only between two groups
    function visOf(entries, q) {
        const c = targets.carrying ?? {};
        const v = entries.map(e => e.kind !== "folder" || !q || (e.f.name ?? "").toLowerCase().includes(q));
        const anyPinned = entries.some((e, i) => e.kind === "folder" && e.pin >= 0 && v[i]);
        const anyOther = entries.some((e, i) => e.kind === "folder" && e.pin < 0 && v[i]);
        const unpinRow = targets.purpose === "reorder" && targets.pinOrder.includes(c.path ?? "");   // carriedPinned, read directly: this can run before it updates
        entries.forEach((e, i) => {
            if (e.kind === "add")
                v[i] = !!c.isFolder && (c.path ?? "") !== "" && targets.purpose !== "reorder";
            else if (e.kind === "pause")
                v[i] = anyPinned && (anyOther || unpinRow);
            else if (e.kind === "unpin")
                v[i] = unpinRow;
            else if (e.kind === "none")
                v[i] = q !== "" && !anyPinned && !anyOther;
        });
        return v;
    }

    readonly property string label: {
        const what = targets.carrying?.label ?? "";
        switch (targets.purpose) {
        case "drop":
            return what ? `Drop ${what} in a folder` : "Drop in a folder";
        case "move":
            return `Move '${what}' to…`;
        case "new":
            return "New session in…";
        case "reorder":
            return targets.carriedPinned ? `Move ${what}` : `Pin ${what}`;
        }
        return "";
    }
    readonly property var carriedLines: targets.carrying?.lines ?? []

    // ── choosing ────────────────────────────────────────────────────────────
    function targetList() {
        const out = [];
        targets.entries.forEach((e, i) => {
            if ((e.kind === "folder" || e.kind === "add") && targets.vis[i])
                out.push(i);
        });
        return out;
    }
    function pointAt(y) {
        targets.lastY = y;
        if (!targets.active)
            return;
        const cy = targets.mapToItem(col, 0, y).y;
        if (targets.purpose === "reorder") {
            targets.pointGap(y < flick.y ? -Infinity : cy);
            return;
        }
        let hit = -1;
        if (y >= flick.y) {
            for (let i = 0; i < targets.entries.length; i++) {
                const it = rows.itemAt(i);
                if (!it || it.height < 0.5 || cy < it.y || cy >= it.y + it.height)
                    continue;
                if (targets.entries[i].kind === "folder" || targets.entries[i].kind === "add")
                    hit = i;
                break;
            }
        }
        if (hit !== targets.cursor)
            targets.cursor = hit;
    }
    // above the pins' bottom: the nearest boundary between headings; below the pause's middle: unpin
    function pointGap(cy) {
        const n = targets.pinCount;
        const first = rows.itemAt(1);   // the "Folders" label; the pins follow it
        const top = first ? first.y + first.height : 0;
        const pause = rows.itemAt(2 + n);
        const bottom = top + n * 44 + (pause ? pause.height / 2 : 0);
        let g = -1, c = -1;
        if (cy >= bottom)
            c = targets.carriedPinned ? targets.entries.findIndex(e => e.kind === "unpin") : -1;
        else
            g = Math.max(0, Math.min(n, Math.round((cy - top) / 44)));
        targets.gap = g;
        targets.cursor = c;
    }
    function step(n) {
        if (!targets.active)
            return;
        if (targets.purpose === "reorder") {
            // gaps 0..pins, then the unpin row
            const last = targets.pinCount + (targets.carriedPinned ? 1 : 0);
            const at = targets.gap >= 0 ? targets.gap : targets.cursor >= 0 ? targets.pinCount + 1 : (n > 0 ? -1 : last + 1);
            const to = Math.max(0, Math.min(last, at + n));
            targets.gap = to <= targets.pinCount ? to : -1;
            targets.cursor = to > targets.pinCount ? targets.entries.findIndex(e => e.kind === "unpin") : -1;
            return;
        }
        const t = targets.targetList();
        if (!t.length) {
            targets.cursor = -1;
            return;
        }
        const at = t.indexOf(targets.cursor);
        const to = at < 0 ? (n > 0 ? n - 1 : t.length + n) : at + n;
        targets.cursor = t[Math.max(0, Math.min(t.length - 1, to))];
        targets.reveal(targets.cursor);
    }
    function commit() {
        if (!targets.active || targets.done)
            return;
        targets.done = true;
        const path = targets.carrying?.path ?? "";
        if (targets.purpose === "reorder") {
            const o = targets.carriedPin;
            if (targets.gap >= 0) {
                const idx = targets.pinIndex(targets.gap);
                // either side of its own place, or the place it already has in Files: no move
                if (o >= 0 && (targets.gap === o || targets.gap === o + 1) || targets.pinOrder.indexOf(path) === idx)
                    targets.cancelled();
                else
                    targets.reordered(path, idx);
            } else if (targets.cursor >= 0 && targets.entries[targets.cursor]?.kind === "unpin") {
                targets.reordered(path, -1);
            } else {
                targets.cancelled();
            }
            return;
        }
        const e = targets.cursor >= 0 ? targets.entries[targets.cursor] : null;
        if (e?.kind === "add")
            targets.addFolder(path);
        else if (e?.kind === "folder")
            targets.chosen(e.f.fkey);
        else
            targets.cancelled();
    }
    function cancel() {
        if (!targets.active || targets.done)
            return;
        targets.done = true;
        targets.cancelled();
    }
    function reveal(i) {
        const it = rows.itemAt(i);
        if (!it)
            return;
        if (it.y < flick.contentY)
            flick.contentY = it.y;
        else if (it.y + 44 > flick.contentY + flick.height)
            flick.contentY = it.y + 44 - flick.height;
    }

    // Within 40 px of the list's top or bottom edge it scrolls, faster the deeper, up to 600 px/s.
    function edgeScroll(y) {
        targets.lastY = y;
        const fy = y - flick.y;
        let v = 0;
        if (targets.active && flick.contentHeight > flick.height) {
            if (fy < 40)
                v = -600 * Math.min(1, (40 - fy) / 40);
            else if (fy > flick.height - 40)
                v = 600 * Math.min(1, (fy - flick.height + 40) / 40);
        }
        targets.scrollSpeed = v;
    }
    FrameAnimation {
        // stops at either end, so a pointer resting in the band does not keep the window drawing
        running: targets.active && (targets.scrollSpeed < 0 ? flick.contentY > 0.5
                                  : targets.scrollSpeed > 0 && flick.contentY < flick.contentHeight - flick.height - 0.5)
        onTriggered: {
            const max = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = Math.max(0, Math.min(max, flick.contentY + targets.scrollSpeed * Math.min(frameTime, 0.05)));
            targets.pointAt(targets.lastY);
        }
    }

    Keys.onPressed: e => {
        if (!targets.active)
            return;
        e.accepted = true;
        if (e.key === Qt.Key_Escape)
            targets.cancel();
        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab)
            targets.step(1);
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab)
            targets.step(-1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (targets.cursor >= 0 || targets.gap >= 0)
                targets.commit();
        } else if (targets.purpose !== "reorder" && e.text.length === 1 && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127
                   && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            targets.typing = true;
            field.text += e.text;
            field.forceActiveFocus();
        } else
            e.accepted = false;
    }

    // a click off the targets ends it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: targets.cancel()
        onWheel: w => w.accepted = true
    }

    // ── what you carry ──────────────────────────────────────────────────────
    Item {
        id: head
        width: parent.width
        height: headCol.implicitHeight
        clip: true
        Behavior on height {
            enabled: !targets.instant
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
        Column {
            id: headCol
            width: parent.width
            topPadding: 6
            bottomPadding: 4
            spacing: 2

            // typing: the rail's search box, with what it is for as its placeholder
            Rectangle {
                x: 12
                width: parent.width - 24
                height: 36
                visible: targets.typing
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.94)
                MaterialSymbol {
                    id: fieldGlyph
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "search"
                    iconSize: 18
                    color: Appearance.colors.colInkSecondary
                }
                StyledTextInput {
                    id: field
                    anchors { left: fieldGlyph.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    font.pixelSize: 15
                    color: Appearance.colors.colInkMain
                    clip: true
                    Keys.onDownPressed: targets.step(1)
                    Keys.onUpPressed: targets.step(-1)
                    Keys.onEscapePressed: targets.cancel()
                    Keys.onReturnPressed: if (targets.cursor >= 0) targets.commit()
                    Keys.onEnterPressed: if (targets.cursor >= 0) targets.commit()
                }
                StyledText {
                    anchors { left: fieldGlyph.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    visible: field.text.length === 0
                    text: targets.label
                    font.pixelSize: 15
                    color: Appearance.colors.colInkSecondary
                    elide: Text.ElideRight
                }
            }
            StyledText {
                x: 20
                width: parent.width - 40
                visible: !targets.typing
                text: targets.label
                font.family: Appearance.font.family.compact
                font.pixelSize: 13
                color: Appearance.colors.colInkSecondary
                elide: Text.ElideMiddle   // a long file name or title gives way, the verb and "in a folder" stay
            }
            Repeater {
                model: targets.carriedLines.slice(0, 3)
                delegate: StyledText {
                    required property var modelData
                    readonly property string lead: `${targets.carrying?.label ?? ""} — `
                    x: 20
                    width: headCol.width - 40
                    // the first line already names a single file
                    text: modelData.startsWith(lead) ? modelData.slice(lead.length) : modelData
                    font.family: Appearance.font.family.compact
                    font.pixelSize: 13
                    color: Appearance.colors.colInkMeta
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            StyledText {
                x: 20
                visible: targets.carriedLines.length > 3
                text: `${targets.carriedLines.length - 3} more`
                font.family: Appearance.font.family.compact
                font.pixelSize: 13
                color: Appearance.colors.colInkMeta
            }
        }
    }

    // ── the folders ─────────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; bottomMargin: 8 }
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width

            Repeater {
                id: rows
                model: targets.entries
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property string kind: modelData.kind
                    readonly property real full: ({ add: 44, label: 36, folder: 44, pause: 14, unpin: 52, none: 36 })[slot.kind] ?? 0
                    readonly property bool target: slot.kind === "folder" || slot.kind === "add" || slot.kind === "unpin"
                    readonly property bool chosen: targets.cursor === slot.index
                    width: col.width
                    height: targets.vis[slot.index] ? slot.full : 0
                    visible: height > 0.5
                    clip: height < slot.full
                    Behavior on height {
                        enabled: !targets.instant
                        NumberAnimation {
                            duration: Appearance.animation.elementResize.duration
                            easing.type: Appearance.animation.elementResize.type
                            easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                        }
                    }

                    Rectangle {
                        visible: slot.target
                        anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
                        y: 2
                        height: slot.full - 4
                        radius: 12
                        color: slot.chosen ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.84) : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }
                    Loader {
                        readonly property var e: slot.modelData
                        width: parent.width
                        height: slot.full
                        sourceComponent: slot.kind === "folder" ? folderPart : slot.kind === "add" ? addPart : slot.kind === "label" ? labelPart
                            : slot.kind === "unpin" ? unpinPart : slot.kind === "none" ? nonePart : null
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: slot.target && targets.purpose !== "reorder"
                        hoverEnabled: enabled
                        cursorShape: Qt.PointingHandCursor
                        onEntered: targets.cursor = slot.index
                        onClicked: {
                            targets.cursor = slot.index;
                            targets.commit();
                        }
                    }
                }
            }
        }

        // reorder: where the heading lands, the SidePanel grip's mark
        Rectangle {
            visible: targets.purpose === "reorder" && targets.gap >= 0
            x: 16
            width: flick.width - 32
            height: 2
            radius: 1
            color: Appearance.colors.colPrimary
            opacity: 0.8
            y: {
                const label = rows.itemAt(1);
                return (label ? label.y + label.height : 0) + targets.gap * 44 - 1;
            }
        }
    }
    FastWheel {
        view: flick
        ease: true
        anchors.fill: flick
    }

    // ── the parts ───────────────────────────────────────────────────────────
    Component {
        id: folderPart
        Item {
            id: fp
            readonly property var f: parent?.e?.f ?? ({})
            readonly property var live: fp.f.live ?? ({})
            readonly property bool lit: (fp.live.waiting ?? 0) > 0 || (fp.live.working ?? 0) > 0 || (fp.live.terminals ?? 0) > 0
                || (fp.live.graphis ?? 0) > 0 || (fp.live.files ?? 0) > 0
            MaterialSymbol {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "folder"
                iconSize: 18
                color: Appearance.colors.colInkSecondary
            }
            StyledText {
                x: 42
                anchors.verticalCenter: parent.verticalCenter
                width: (mark.item ? mark.x - 10 : fp.width - 20) - 42
                text: fp.f.name ?? ""
                font.family: Appearance.font.family.compact
                font.pixelSize: 15
                // reorder: the heading being moved reads quieter in its old place
                color: targets.purpose === "reorder" && fp.f.path === targets.carrying?.path ? Appearance.colors.colInkMeta : Appearance.colors.colInkMain
                elide: Text.ElideRight
            }
            Loader {
                id: mark
                readonly property var live: fp.live
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                active: fp.lit
                sourceComponent: liveMark
            }
        }
    }
    // the heading's live mark: the sand dot or a still Spinner, then terminal, code and folder with counts above 1
    Component {
        id: liveMark
        Row {
            readonly property var live: parent?.live ?? ({})
            spacing: 10
            Item {
                visible: (parent.live.waiting ?? 0) > 0 || (parent.live.working ?? 0) > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                Rectangle {
                    visible: (parent.parent.live.waiting ?? 0) > 0
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Appearance.colors.colPrimary
                }
                Spinner {
                    visible: (parent.parent.live.waiting ?? 0) === 0
                    anchors.centerIn: parent
                    active: false
                    implicitSize: 14
                }
            }
            Repeater {
                model: [["terminal", parent.live.terminals ?? 0], ["code", parent.live.graphis ?? 0], ["folder", parent.live.files ?? 0]].filter(p => p[1] > 0)
                delegate: Row {
                    id: part
                    required property var modelData
                    spacing: 3
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: part.modelData[0]
                        iconSize: 14
                        color: Appearance.colors.colInkMeta
                    }
                    StyledText {
                        visible: part.modelData[1] > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(part.modelData[1])
                        font.family: Appearance.font.family.numbers
                        font.pixelSize: 12
                        color: Appearance.colors.colInkMeta
                    }
                }
            }
        }
    }
    Component {
        id: addPart
        Item {
            MaterialSymbol {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "create_new_folder"
                iconSize: 18
                color: Appearance.colors.colInkSecondary
            }
            StyledText {
                x: 42
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 42 - 20
                text: {
                    const c = targets.carrying ?? {};
                    const name = c.label || (c.path ?? "").split("/").filter(x => x.length).pop() || "";
                    return `Add ${name} as a folder`;
                }
                font.family: Appearance.font.family.compact
                font.pixelSize: 15
                color: Appearance.colors.colInkMain
                elide: Text.ElideRight
            }
        }
    }
    Component {
        id: labelPart
        Item {
            StyledText {
                anchors { left: parent.left; leftMargin: 20; bottom: parent.bottom; bottomMargin: 7 }
                text: "Folders"
                font.family: Appearance.font.family.compact
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Appearance.colors.colInkMeta
            }
        }
    }
    Component {
        id: unpinPart
        Item {
            MaterialSymbol {
                x: 18
                y: 9
                text: "keep_off"
                iconSize: 18
                color: Appearance.colors.colInkSecondary
            }
            Column {
                x: 42
                y: 7
                width: parent.width - 42 - 20
                StyledText {
                    width: parent.width
                    text: `Unpin ${targets.carrying?.label ?? ""}`
                    font.family: Appearance.font.family.compact
                    font.pixelSize: 15
                    color: Appearance.colors.colInkMain
                    elide: Text.ElideRight
                }
                StyledText {
                    width: parent.width
                    text: "Also leaves Pinax's rail"
                    font.family: Appearance.font.family.compact
                    font.pixelSize: 13
                    color: Appearance.colors.colInkMeta
                    elide: Text.ElideRight
                }
            }
        }
    }
    Component {
        id: nonePart
        Item {
            StyledText {
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                text: `No folder matches '${field.text.trim()}'`
                font.family: Appearance.font.family.compact
                font.pixelSize: 14
                color: Appearance.colors.colInkSecondary
                elide: Text.ElideRight
            }
        }
    }
}
