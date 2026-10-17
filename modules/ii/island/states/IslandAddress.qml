pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * The browser's Ctrl+L and Ctrl+T in the notch (~/book4-edge/ctrll-notch-plan.md, render
 * tacit-render-2026-09-30/notchfloat.qml). The notch draws; the browser answers over its socket
 * (IslandController.addressSocket), one JSON object a line: hello brings the page, the keys
 * typed before the sheet had them, the rows under the line before anything is typed (`where`,
 * and { where } again when they change) and what Ask Praxis hands over; each change of the text
 * asks for rows ({ query, text, seq }, answered { rows, seq, dest }), and Enter, Alt+Enter,
 * Shift+Enter and Esc say go, go new (Ctrl+T: background), reload and close. Ctrl+L opens with
 * the link all selected and Where next under it; Ctrl+T ("new") with an empty line, Recent and
 * Earlier under it. Tab, or Enter on Ask Praxis, hands the question to the notch's Ask.
 */
Item {
    id: addr
    signal close()

    // 680 wide, 40 px rows, 22 px typed text (the owner's pick 2026-10-02, "B" with 15 px titles: the render's 820 read
    // oversized beside Tacit's 1080p interface; ~/Pictures/Martida and the Ctrl+L sizes artifact)
    readonly property real fullWidth: 680
    readonly property color textColor: Appearance.colors.colOnLayer0
    readonly property color dimColor: Appearance.colors.colSubtext
    readonly property color washColor: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.93)

    property string mode: IslandController.addressMode   // "edit" (Ctrl+L) or "new" (Ctrl+T)
    property string link: ""
    property string host: ""
    property bool touched: addr.mode === "new"   // typed into, or the caret moved, since the link was shown
    property bool setting: false      // the text set from here, not typed
    property var whereRows: []        // the browser's rows before anything is typed: Where next, or Recent and Earlier
    property var typedRows: []        // its rows for the text typed
    property string dest: ""          // new: where the page goes ("new thread", "new page in x1p42100 camera")
    property var praxisChip: null     // { label, text }: the task's pages, for the notch's Ask
    // the where rows until something is typed (Ctrl+T: while the line is empty)
    readonly property bool whereShown: addr.mode === "new" ? input.text.trim() === "" : !addr.touched
    readonly property var rows: addr.whereShown ? addr.whereRows : addr.typedRows
    onWhereShownChanged: addr.resetCurrent()
    property int rowsSeq: -1
    property int seq: 0
    property int current: -1
    property bool finished: false     // go, reload or close sent: nothing more to say
    property int serial: -1           // the call this sheet answers (IslandController.addressSerial)
    property var sock: null           // one Socket per call: one that failed to connect never connects again

    readonly property real rowsHeight: addr.rows.reduce((h, r) => h + (r.kind === "label" ? 28 : 40), addr.rows.length > 0 ? 8 : 0)
    // the heights, the notch row's 34 included: 314 just pressed, 422 typing (the render's 346 and 470 with 40 px rows
    // and a 52 px line)
    implicitHeight: (addr.touched ? 422 : 314) - 34
    // the rows run from under the hairline to 20 above the keys line (the render's three Where next
    // rows, or its six typing rows); more than that scroll
    readonly property real rowsRoom: addr.implicitHeight - 64 - 60
    readonly property real rowsShown: Math.min(addr.rowsHeight, addr.rowsRoom)
    clip: true

    function focusInput() { input.forceActiveFocus(); }

    // ── the browser ─────────────────────────────────────────────────────
    Component {
        id: sockComponent
        Socket {
            id: s
            parser: SplitParser { onRead: line => { if (s === addr.sock) addr.receive(line); } }
            // a local socket connects at once, inside createObject: hello goes out from here
            onConnectedChanged: {
                if (s.connected) {
                    s.write(JSON.stringify({ op: "hello" }) + "\n");
                    s.flush();
                } else if (s === addr.sock && !addr.finished) {
                    addr.fold();
                }
            }
            // nothing listens there (the browser gone): it has its own card
            onError: if (!s.connected && (addr.sock === null || s === addr.sock) && !addr.finished) addr.fold()
        }
    }
    Component.onCompleted: addr.connectTo()
    function connectTo() {
        addr.serial = IslandController.addressSerial;
        const old = addr.sock;
        addr.sock = null;
        if (old)
            old.destroy();
        addr.sock = sockComponent.createObject(addr, { path: IslandController.addressSocket, connected: true });
    }
    function send(o) {
        if (!addr.sock || !addr.sock.connected)
            return;
        addr.sock.write(JSON.stringify(o) + "\n");
        addr.sock.flush();
    }
    // Esc's way, or the lock: the browser hears close, then the notch folds
    Component.onDestruction: {
        if (addr.finished)
            return;
        try { addr.send({ op: "close" }); } catch (e) {}
    }

    function receive(line) {
        let m;
        try { m = JSON.parse(line); } catch (e) { return; }
        if (m.op === "hello") {
            addr.link = m.link ?? "";
            addr.host = m.host ?? "";
            addr.praxisChip = m.praxis ?? null;
            addr.dest = m.dest ?? "";
            IslandController.addressTask = m.task ?? "";
            IslandController.addressPages = m.pages ?? 0;
            addr.whereRows = m.where ?? [];
            addr.resetCurrent();
            // typed in the browser first, then here before the hello came
            const early = addr.touched ? input.text : "";
            const typed = (m.typed ?? "") + early;
            if (typed !== "") {
                addr.setText(typed, false);
                addr.touched = true;
                addr.query();
            } else if (addr.mode === "edit") {
                addr.setText(addr.link, true);
            }
        } else if (m.op === "where") {
            addr.whereRows = m.rows ?? [];
            if (addr.whereShown)
                addr.resetCurrent();
        } else if (m.op === "rows") {
            if (m.seq !== addr.seq || !addr.touched)
                return;
            addr.typedRows = m.rows ?? [];
            addr.rowsSeq = m.seq;
            if (m.dest !== undefined)
                addr.dest = m.dest;
            if (!addr.whereShown)
                addr.resetCurrent();
        } else if (m.op === "close") {
            addr.finished = true;
            addr.fold();
        }
    }
    function setText(text, selected) {
        addr.setting = true;
        input.text = text;
        if (selected)
            input.selectAll();
        else
            input.cursorPosition = input.text.length;
        addr.setting = false;
    }
    // Ctrl+T asks for an empty line too: where the page goes follows the text
    function query() {
        addr.seq++;
        if (input.text.trim() === "") {
            addr.typedRows = [];
            if (addr.mode !== "new")
                return;
        }
        addr.send({ op: "query", text: input.text, seq: addr.seq });
    }
    // the first row current (Enter goes there), except over Ctrl+T's empty line, where Down picks one
    function resetCurrent() {
        addr.current = -1;
        if (!(addr.whereShown && addr.mode === "new"))
            addr.step(1);
    }
    function step(delta) {
        // whereShown changes while the sheet is still being made, before `rows` has its binding
        const rows = addr.rows ?? [];
        let i = addr.current;
        do
            i += delta;
        while (i >= 0 && i < rows.length && rows[i].kind === "label");
        if (i >= 0 && i < rows.length)
            addr.current = i;
        addr.showRow(addr.current);
    }
    // the current row in view when the rows scroll
    function showRow(index) {
        let top = 8;
        for (let k = 0; k < index; k++)
            top += addr.rows[k].kind === "label" ? 28 : 40;
        if (index <= 1)
            rowList.contentY = 0;
        else if (top < rowList.contentY)
            rowList.contentY = top;
        else if (top + 40 > rowList.contentY + rowList.height)
            rowList.contentY = top + 40 - rowList.height;
    }
    // Enter: the row picked for the text as it is, else the text; untouched, the where row picked,
    // else the link. Ask Praxis asks.
    function go(where) {
        const text = input.text.trim();
        const row = addr.rows[addr.current];
        if (row && row.kind === "praxis")
            addr.praxis();
        else if (addr.whereShown) {
            if (row)
                addr.finish({ op: "go", next: addr.current, where: where });
            else if (!addr.touched)
                addr.finish({ op: "go", text: addr.link, where: where });
        } else if (addr.rowsSeq === addr.seq && row)
            addr.finish({ op: "go", index: addr.current, seq: addr.rowsSeq, text: text, where: where });
        else if (text !== "")
            addr.finish({ op: "go", text: text, where: where });
    }
    // Tab, or Enter on Ask Praxis: the question (a ? dropped) goes to the notch's Ask with the
    // task's pages as its context chip; the browser hears praxis and leaves the keys with the notch
    function praxis() {
        if (addr.finished)
            return;
        const question = addr.touched ? input.text.trim().replace(/^\?\s*/, "") : "";
        addr.send({ op: "praxis", text: question });
        addr.finished = true;
        const chips = addr.praxisChip ? [Object.assign({ kind: "context", glyph: "language", handed: true }, addr.praxisChip)] : [];
        // after this call: Ask takes the sheet's place, and this item goes with it
        Qt.callLater(IslandController.openAsk, "browser", chips, question, IslandController.keyboard);
    }
    function finish(message) {
        if (addr.finished)
            return;
        addr.send(message);
        addr.finished = true;
        addr.fold();
    }
    // later, not inside a socket's signal: a failure inside createObject comes before IslandContent
    // has hooked `close`
    function fold() { Qt.callLater(() => addr.close()); }

    // A call while the sheet is up (the browser asked again): start over on the new socket
    Connections {
        target: IslandController
        function onAddressRequested() {
            if (IslandController.addressSerial === addr.serial)
                return;
            addr.finished = false;
            addr.mode = IslandController.addressMode;
            addr.touched = addr.mode === "new";
            addr.whereRows = [];
            addr.typedRows = [];
            addr.rowsSeq = -1;
            addr.dest = "";
            addr.praxisChip = null;
            addr.link = "";
            addr.setText("", false);
            addr.connectTo();
            input.forceActiveFocus();
        }
        // test hooks (`island addressType`, `island addressKey`): keys without a keyboard
        function onAddressTyped(text) { input.remove(input.selectionStart, input.selectionEnd); input.insert(input.cursorPosition, text); }
        function onAddressKeyed(key) {
            if (key === "down") addr.step(1);
            else if (key === "up") addr.step(-1);
            else if (key === "enter") addr.go("here");
            else if (key === "alt+enter") addr.go(addr.mode === "new" ? "background" : "new");
            else if (key === "shift+enter" && addr.mode === "edit") addr.finish({ op: "reload" });
            else if (key === "tab") addr.praxis();
            else if (key === "escape") addr.finish({ op: "close" });
        }
    }

    // ── the sheet: contents rise 8 px as they fade in, over the shape's last 200 ms ──
    property real reveal: 0
    SequentialAnimation {
        running: true
        PauseAnimation { duration: Appearance.animationCurves.expressiveDefaultSpatialDuration - Appearance.animationCurves.expressiveDefaultEffectsDuration }
        Anim { target: addr; property: "reveal"; to: 1; type: Anim.DefaultEffects }
    }

    // the render's regular weight (400); Medium where it has Medium. Sizes are the render's as its
    // SF Pro Rounded set them: Tacit runs about 12 % wider at the same px, and read huge (owner, 2026-10-02)
    component Words: StyledText {
        font.variableAxes: ({ "wght": 400 })
    }

    component Key: Row {
        id: key
        property string cap: ""
        property string label: ""
        spacing: 7
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            radius: 7
            width: Math.max(22, capText.implicitWidth + 12)
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.92)
            border.width: 1
            border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.94)
            Words {
                id: capText
                anchors.centerIn: parent
                text: key.cap
                font.pixelSize: 10
                font.variableAxes: ({ "wght": 500 })
                color: addr.textColor
            }
        }
        Words {
            anchors.verticalCenter: parent.verticalCenter
            text: key.label
            font.pixelSize: 12
            color: addr.dimColor
        }
    }

    Item {
        id: body
        x: Math.round((addr.width - width) / 2)
        width: addr.fullWidth
        height: addr.implicitHeight
        opacity: addr.reveal
        transform: Translate { y: 8 * (1 - addr.reveal) }

        // the line: the link all selected, or what you type
        Item {
            id: line
            y: 4
            width: parent.width
            height: 52

            Rectangle {
                visible: !addr.touched && addr.link !== ""
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                radius: 6
                width: Math.min(linkRow.implicitWidth + 8, parent.width - 48)
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                clip: true
                Row {
                    id: linkRow
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int at: addr.host !== "" ? addr.link.indexOf(addr.host) : -1
                    Words {
                        id: hostText
                        text: linkRow.at >= 0 ? addr.host : addr.link
                        width: Math.min(implicitWidth, line.width - 56)
                        elide: Text.ElideRight
                        font.pixelSize: 20
                        color: addr.textColor
                    }
                    Words {
                        visible: linkRow.at >= 0
                        text: linkRow.at >= 0 ? addr.link.slice(linkRow.at + addr.host.length) : ""
                        width: Math.max(0, Math.min(implicitWidth, line.width - 56 - hostText.width))
                        elide: Text.ElideRight
                        font.pixelSize: 20
                        color: addr.dimColor
                    }
                }
            }
            MaterialSymbol {
                visible: addr.touched
                x: 22
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                iconSize: 20
                color: addr.dimColor
            }
            // Ctrl+T's empty line, as the new-page bar's
            Words {
                visible: addr.mode === "new" && input.text === ""
                x: 52
                anchors.verticalCenter: parent.verticalCenter
                text: "Search or enter address"
                font.pixelSize: 22
                color: addr.dimColor
            }
            // what the line does (the render's), or for Ctrl+T where the page goes
            Words {
                id: hint
                visible: addr.touched && text !== ""
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: addr.mode === "new" ? addr.dest : "search, or ask Praxis"
                font.pixelSize: 12
                color: addr.dimColor
            }
            // takes the keys from the first frame; drawn once typed into (the link above until then)
            TextInput {
                id: input
                x: addr.touched ? 52 : 24
                width: parent.width - x - 24 - (hint.visible ? hint.implicitWidth + 16 : 0)
                anchors.verticalCenter: parent.verticalCenter
                opacity: addr.touched ? 1 : 0
                clip: true
                font.family: Appearance.font.family.main
                font.variableAxes: ({ "wght": 400 })
                font.hintingPreference: Font.PreferNoHinting
                font.pixelSize: 22
                renderType: Text.NativeRendering
                color: addr.textColor
                selectionColor: Appearance.colors.colSecondaryContainer
                selectedTextColor: addr.textColor
                selectByMouse: true
                cursorDelegate: Rectangle {
                    width: 2.5
                    height: 26
                    radius: 1.25
                    color: Appearance.colors.colPrimary
                }
                onTextChanged: {
                    if (addr.setting)
                        return;
                    addr.touched = true;
                    addr.query();
                }
                // the caret moved off the selected link: the link is being edited
                onCursorPositionChanged: if (!addr.setting && !addr.touched && addr.link !== "" && input.selectedText === "") addr.touched = true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        addr.finish({ op: "close" });
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (event.modifiers & Qt.ShiftModifier) {
                            if (addr.mode === "edit")
                                addr.finish({ op: "reload" });
                        } else if (event.modifiers & Qt.AltModifier)
                            addr.go(addr.mode === "new" ? "background" : "new");
                        else
                            addr.go("here");
                    } else if (event.key === Qt.Key_Down)
                        addr.step(1);
                    else if (event.key === Qt.Key_Up)
                        addr.step(-1);
                    else if (event.key === Qt.Key_Tab)
                        addr.praxis();
                    else if (event.key !== Qt.Key_Backtab)
                        return;
                    event.accepted = true;
                }
            }
        }

        Rectangle {
            x: 24
            y: 60
            width: parent.width - 48
            height: 1
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.95)
        }

        // the rows: Where next (or Recent and Earlier) before anything is typed; then Search the web,
        // Ask Praxis, Open and Been here, as the browser's card lists them
        Flickable {
            id: rowList
            x: 8
            y: 64
            width: parent.width - 16
            height: addr.rowsShown
            contentHeight: addr.rowsHeight
            interactive: addr.rowsHeight > addr.rowsRoom
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Column {
                width: rowList.width
                Item { visible: addr.rows.length > 0; width: 1; height: 8 }
                Repeater {
                    model: addr.rows
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool label: row.modelData.kind === "label"
                        readonly property bool bright: row.index === addr.current
                        width: parent.width
                        height: row.label ? 28 : 40

                        Words {
                            visible: row.label
                            x: 16
                            height: parent.height
                            verticalAlignment: Text.AlignBottom
                            bottomPadding: 8
                            text: row.modelData.title
                            font.pixelSize: 12
                            font.variableAxes: ({ "wght": 500 })
                            color: addr.dimColor
                        }
                        Rectangle {
                            visible: !row.label
                            anchors.fill: parent
                            radius: 14
                            color: row.bright ? addr.washColor : "transparent"
                        }
                        Image {
                            id: face
                            visible: !row.label && status === Image.Ready
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            sourceSize: Qt.size(36, 36)
                            source: row.label ? "" : (row.modelData.icon ?? "")
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }
                        // Ask Praxis's diamond, filled in the accent (the render's)
                        MaterialSymbol {
                            readonly property bool praxis: row.modelData.kind === "praxis"
                            visible: !row.label && !face.visible
                            x: 15
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.glyph || "language"
                            iconSize: 19
                            fill: praxis ? 1 : 0
                            color: praxis ? Appearance.colors.colPrimary : addr.dimColor
                        }
                        Row {
                            visible: !row.label
                            x: 50
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            width: parent.width - x - right.width - 24
                            clip: true
                            Words {
                                id: title
                                text: row.modelData.title
                                width: Math.min(implicitWidth, parent.width - (detail.text !== "" ? detail.implicitWidth + 12 : 0))
                                elide: Text.ElideRight
                                font.pixelSize: 15
                                font.variableAxes: ({ "wght": row.bright ? 500 : 400 })
                                color: addr.textColor
                            }
                            Words {
                                id: detail
                                text: row.modelData.detail ?? ""
                                anchors.baseline: title.baseline
                                font.pixelSize: 12
                                color: addr.dimColor
                            }
                        }
                        Row {
                            id: right
                            visible: !row.label
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Words {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.word ?? ""
                                font.pixelSize: 12
                                color: addr.dimColor
                            }
                            Words {
                                visible: row.bright
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↵"
                                font.pixelSize: 14
                                color: addr.textColor
                            }
                        }
                        // a row becomes current when the pointer moves over it, not when rows swap under a resting one
                        MouseArea {
                            visible: !row.label
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            property point at: Qt.point(-1, -1)
                            onPositionChanged: mouse => {
                                if (at.x >= 0 && (Math.abs(mouse.x - at.x) + Math.abs(mouse.y - at.y)) > 0.5)
                                    addr.current = row.index;
                                at = Qt.point(mouse.x, mouse.y);
                            }
                            onClicked: { addr.current = row.index; addr.go("here"); }
                        }
                    }
                }
            }
        }

        // the keys line, one left edge at 24 with everything above
        Row {
            x: 24
            y: addr.implicitHeight - 40
            spacing: 20
            Key { cap: "↵"; label: addr.mode === "new" ? "open" : addr.touched ? "here" : "go" }
            Key { visible: addr.touched; cap: "Alt ↵"; label: addr.mode === "new" ? "in background" : "new page" }
            Key { visible: !addr.touched; cap: "⇧ ↵"; label: "reload" }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: addr.implicitHeight - 40
            spacing: 20
            Key { cap: "Tab"; label: "Praxis" }
            Key { cap: "Esc"; label: "back" }
        }
    }
}
