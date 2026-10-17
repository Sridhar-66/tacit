import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * A row in the side panel's trail: one mark (a breathing sand dot while it runs, a check when done,
 * a ring when stopped, a clay error, a clock while it waits), the name, one line under it (the step it
 * is on, what it found, what stopped it), the time at the right, and a faint chevron that says the
 * row opens (full ink on hover). The row you came back
 * from wears the sand wash for a moment, so the eye lands where it left.
 */
Item {
    id: row
    property string mark: "done"         // running | done | failed | waiting | stopped | none
    property string glyph: ""             // a glyph in place of the state's mark
    property string title: ""
    property string line: ""
    property string tone: ""              // "live" | "bad" | ""
    property string meta: ""
    property int add: -1                  // a file's lines added and removed, in the diff colours (in place of meta)
    property int del: -1
    property bool cursor: false
    property bool cameFrom: false
    property bool chevron: true
    property int indent: 0
    property alias extra: extraSlot.data  // under the line (a workflow's progress bar)
    signal clicked()
    implicitHeight: Math.max(44, col.implicitHeight + 16)
    width: parent ? parent.width : 0

    Rectangle {
        anchors { fill: parent; leftMargin: -10 + row.indent; rightMargin: -10 }
        radius: 10
        color: row.cameFrom ? ColorUtils.transparentize(Appearance.m3colors.m3primaryContainer, 0.62)
             : (area.containsMouse || row.cursor) ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95) : "transparent"
        Behavior on color { ColorAnimation { duration: 400 } }
    }
    Item {
        id: markBox
        x: row.indent
        width: 22
        height: 18
        anchors.verticalCenter: parent.verticalCenter
        // one breathing dot per running thing, no spinners
        Rectangle {
            visible: row.glyph.length === 0 && row.mark === "running"
            anchors.centerIn: parent
            width: 9; height: 9; radius: 4.5
            color: Appearance.colors.colPrimary
            SequentialAnimation on opacity {
                running: row.mark === "running" && row.visible && Appearance.agentsMoving
                loops: Animation.Infinite
                alwaysRunToEnd: true    // a breath stopped mid-way finishes, then rests
                NumberAnimation { to: 0.35; duration: 1300; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 1300; easing.type: Easing.InOutSine }
            }
        }
        // stopped: a ring, kept apart from done and from failed
        Rectangle {
            visible: row.glyph.length === 0 && row.mark === "stopped"
            anchors.centerIn: parent
            width: 11; height: 11; radius: 5.5
            color: "transparent"
            border.width: 1.5
            border.color: Appearance.colors.colInkMeta
        }
        MaterialSymbol {
            visible: row.glyph.length > 0 || ["done", "failed", "waiting"].includes(row.mark)
            anchors.centerIn: parent
            text: row.glyph.length ? row.glyph : row.mark === "failed" ? "error" : row.mark === "waiting" ? "schedule" : "check"
            iconSize: 18
            color: row.mark === "failed" ? Appearance.colors.colClay : row.glyph.length ? Appearance.colors.colInkSecondary : row.mark === "waiting" ? Appearance.colors.colInkMeta : Appearance.colors.colInkSecondary
        }
    }
    Column {
        id: col
        anchors { left: markBox.right; leftMargin: 12; right: metaText.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 2
        StyledText {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Appearance.colors.colInkMain
        }
        StyledText {
            visible: row.line.length > 0
            width: parent.width
            text: row.line
            elide: Text.ElideRight
            font.pixelSize: 14
            color: row.tone === "bad" ? Appearance.colors.colClay : Appearance.colors.colInkSecondary
        }
        Item { id: extraSlot; width: parent.width; height: childrenRect.height; visible: children.length > 0 }
    }
    StyledText {
        id: metaText
        visible: row.add < 0
        anchors { right: chev.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
        text: row.meta
        font.pixelSize: 14
        font.features: { "tnum": 1 }
        color: Appearance.colors.colInkMeta
    }
    Row {
        visible: row.add >= 0
        anchors { right: chev.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
        spacing: 6
        StyledText { visible: row.add > 0; text: `+${row.add}`; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: "#7BD88F" }
        StyledText { visible: row.del > 0; text: `−${row.del}`; font.family: Appearance.font.family.numbers; font.pixelSize: 14; color: "#F28B82" }
    }
    MaterialSymbol {
        id: chev
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 17
        text: "chevron_right"
        iconSize: 17
        color: area.containsMouse || row.cursor ? Appearance.colors.colInkSecondary : Appearance.colors.colInkFaint
        opacity: row.chevron ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
    MouseArea {
        id: area
        anchors { fill: parent; leftMargin: -10 + row.indent; rightMargin: -10 }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
