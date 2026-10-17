import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * The session's plan, pinned above the message box while a turn works through it: what is done,
 * what it is on now, what is next. A stopped turn, or one that ended with a task never marked done,
 * takes the plan with it; a later turn that updates the plan brings it back. Built from the conversation's own task calls (TaskCreate numbers a
 * task in its result, TaskUpdate moves or deletes it; the older TodoWrite sends the whole list).
 * Folded it is one line, the task in hand; a click unfolds the list.
 * The task in hand shows how long it has been going while the session works: its ring turns only while
 * agent-host reports something (Spinner rests), and a ring held still through a long quiet command read as
 * frozen (2026-10-11).
 */
Rectangle {
    id: strip
    property var items: []
    property bool open: false
    property bool working: false
    property double turnStart: 0      // when the turn in progress began (Conversation.turnStartOf)
    property string sessionId: ""
    // Per session, the plan as it stood when the session last went quiet: not shown again until a task call
    // changes it. A message sent turns the session busy before its row arrives (turnStart is still the last
    // turn's then), and the last turn's plan came back for that moment, then went (2026-10-11).
    property var quiet: ({})
    onWorkingChanged: if (!strip.working) Qt.callLater(() => {
        if (strip.working) return;
        const q = Object.assign({}, strip.quiet);
        q[strip.sessionId] = strip.touched;
        strip.quiet = q;
    })

    readonly property var tasks: {
        let list = [];
        const byId = {};
        for (const it of strip.items) {
            if (it.kind !== "tool" || !it.task) continue;
            if (it.tool === "TaskCreate") {
                const m = /Task #(\d+)/.exec(String(it.result ?? ""));
                const t = { id: m ? m[1] : `new${list.length}`, subject: it.task.subject ?? "", active: it.task.active ?? "", status: "pending", since: 0 };
                byId[t.id] = t;
                list.push(t);
            } else if (it.tool === "TaskUpdate") {
                const t = byId[String(it.task.id ?? "")];
                if (!t) continue;
                if (it.task.status && it.task.status !== t.status && it.task.status === "in_progress") t.since = it.ts ?? 0;
                if (it.task.status) t.status = it.task.status;
                if (it.task.subject) t.subject = it.task.subject;
            } else if (it.tool === "TodoWrite") {
                // the whole list again: a step still in hand keeps the time it started
                const was = list.find(t => t.status === "in_progress");
                list = (it.task.todos ?? []).map((td, i) => ({ id: `t${i}`, subject: td.content ?? "", active: td.activeForm ?? "", status: td.status ?? "pending",
                    since: td.status === "in_progress" ? (was && was.subject === (td.content ?? "") ? was.since : it.ts ?? 0) : 0 }));
            }
        }
        return list.filter(t => t.status !== "deleted");
    }
    // the newest task call: a plan this turn has not touched belongs to a turn that is over
    readonly property double touched: {
        for (let i = strip.items.length - 1; i >= 0; i--) {
            const it = strip.items[i];
            if (it.kind === "tool" && it.task) return it.ts ?? 0;
        }
        return 0;
    }
    readonly property int done: strip.tasks.filter(t => t.status === "completed").length
    readonly property var now: strip.tasks.find(t => t.status === "in_progress") ?? strip.tasks.find(t => t.status === "pending") ?? null
    // how long the task in hand has been going, while the session works ("" otherwise)
    property double clock: Date.now()
    Timer { running: strip.visible && strip.working && strip.now?.status === "in_progress"; interval: 1000; repeat: true; triggeredOnStart: true; onTriggered: strip.clock = Date.now() }
    function took(since) {
        if (!strip.working || !since) return "";
        const s = Math.max(0, Math.round((strip.clock - since) / 1000));
        return s < 60 ? `${s}s` : s < 3600 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${Math.floor(s / 3600)}h ${Math.floor(s / 60) % 60}m`;
    }

    visible: strip.working && strip.touched >= strip.turnStart && strip.touched > (strip.quiet[strip.sessionId] ?? -1)
        && strip.tasks.length > 0 && strip.done < strip.tasks.length
    implicitHeight: visible ? (strip.open ? 44 + rows.implicitHeight + 12 : 44) : 0
    radius: Appearance.rounding.card
    // as the composer: on the window's frost with a hairline, where the inks keep their contrast (2026-10-11)
    color: "transparent"
    border.width: 1
    border.color: area.containsMouse ? ColorUtils.mix(Appearance.colors.colInkDivider, Appearance.colors.colInkFaint, 0.12) : Appearance.colors.colInkDivider
    Behavior on color { ColorAnimation { duration: 140 } }

    MouseArea { id: area; anchors { left: parent.left; right: parent.right; top: parent.top } height: 44; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: strip.open = !strip.open }
    Item {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 14 }
        height: 44
        MaterialSymbol { id: glyph; anchors.verticalCenter: parent.verticalCenter; text: "checklist"; iconSize: 17; color: Tacit.inkSec }
        StyledText {
            id: label
            anchors { left: glyph.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: "Plan"
            font.pixelSize: Tacit.size.row
            font.weight: Font.Medium
            color: Tacit.inkMain
        }
        StyledText {
            id: count
            anchors { left: label.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: `${strip.done} of ${strip.tasks.length} done`
            font.family: Appearance.font.family.numbers
            font.pixelSize: Tacit.size.meta
            color: Tacit.inkSec
        }
        StyledText {
            anchors { left: count.right; leftMargin: 12; right: nowTook.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            visible: !strip.open && strip.now !== null
            elide: Text.ElideRight
            text: strip.now ? (strip.now.status === "in_progress" && strip.now.active.length ? strip.now.active : `Next: ${strip.now.subject}`) : ""
            font.pixelSize: Tacit.size.row
            color: Tacit.inkMain
        }
        StyledText {
            id: nowTook
            anchors { right: chevron.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            visible: !strip.open && text.length > 0
            text: strip.now && strip.now.status === "in_progress" ? strip.took(strip.now.since) : ""
            font.family: Appearance.font.family.numbers
            font.pixelSize: Tacit.size.meta
            color: Tacit.inkSec
        }
        MaterialSymbol { id: chevron; anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: strip.open ? "expand_less" : "expand_more"; iconSize: 18; color: Tacit.inkSec }
    }
    Column {
        id: rows
        visible: strip.open
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 44; leftMargin: 16; rightMargin: 16 }
        spacing: 4
        Repeater {
            model: strip.tasks
            Item {
                required property var modelData
                width: rows.width
                height: 30
                Item {
                    id: mark
                    width: 17
                    height: 17
                    anchors.verticalCenter: parent.verticalCenter
                    Spinner { anchors.centerIn: parent; visible: modelData.status === "in_progress"; rests: true; implicitSize: 14; colShape: Tacit.accent }
                    MaterialSymbol { anchors.centerIn: parent; visible: modelData.status === "completed"; text: "check"; iconSize: 16; color: Tacit.inkSec }
                    // still to do: setup's thin ring, as the question card's choices
                    Rectangle {
                        anchors.centerIn: parent
                        visible: modelData.status === "pending"
                        width: 13; height: 13; radius: 6.5
                        color: "transparent"
                        border.width: 1
                        border.color: ColorUtils.transparentize(Tacit.inkMain, 0.5)
                    }
                }
                StyledText {
                    id: rowTook
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: text.length > 0
                    text: modelData.status === "in_progress" ? strip.took(modelData.since) : ""
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: Tacit.size.meta
                    color: Tacit.inkSec
                }
                StyledText {
                    anchors { left: mark.right; leftMargin: 10; right: rowTook.visible ? rowTook.left : parent.right; rightMargin: rowTook.visible ? 10 : 0; verticalCenter: parent.verticalCenter }
                    elide: Text.ElideRight
                    text: modelData.subject
                    font.pixelSize: Tacit.size.row
                    font.weight: modelData.status === "in_progress" ? Font.Medium : Font.Normal
                    // done steps step back to the secondary ink; still readable, no strike
                    color: modelData.status === "completed" ? Tacit.inkSec : Tacit.inkMain
                }
            }
        }
    }
}
