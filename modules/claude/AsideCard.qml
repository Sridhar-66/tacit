import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Asked aside: questions about the work put to the session without touching its conversation
 * (Claude Code's side_question). It answers from what it knows so far, even mid-turn, and
 * nothing is added to the transcript. Follow-ups carry the earlier questions and answers.
 * Above the message box, in its soft raised fill; × puts the thread away.
 */
Rectangle {
    id: card
    property var thread: []          // [{ question, response, pending, error }]
    signal closed()

    visible: card.thread.length > 0
    implicitHeight: visible ? Math.min(head.height + 10 + body.implicitHeight, 320) + 22 : 0
    radius: 18
    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93)

    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 11; leftMargin: 14; rightMargin: 12 }
        height: 22
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            MaterialSymbol { text: "chat"; iconSize: 16; color: Appearance.colors.colInkSecondary; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Aside"; font.pixelSize: 14; font.weight: Font.Medium; color: Appearance.colors.colInkMain; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "not part of the conversation"; font.pixelSize: 13; color: Appearance.colors.colInkSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
        MaterialSymbol {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "close"
            iconSize: 16
            color: closeArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
            MouseArea { id: closeArea; anchors { fill: parent; margins: -6 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.closed() }
        }
    }
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 10; leftMargin: 14; rightMargin: 14; bottomMargin: 11 }
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        // the newest answer stays in view as it arrives
        onContentHeightChanged: flick.contentY = Math.max(0, flick.contentHeight - flick.height)
        Column {
            id: body
            width: flick.width
            spacing: 12
            Repeater {
                model: card.thread
                Column {
                    required property var modelData
                    width: body.width
                    spacing: 4
                    StyledText { width: parent.width; wrapMode: Text.Wrap; text: modelData.question; font.pixelSize: 14; font.weight: Font.Medium; color: Appearance.colors.colInkMain }
                    Row {
                        visible: modelData.pending === true
                        spacing: 8
                        Spinner { implicitSize: 14; colShape: Appearance.colors.colPrimary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Thinking aside…"; font.pixelSize: 14; color: Appearance.colors.colInkSecondary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    StyledText { visible: (modelData.error ?? "").length > 0; width: parent.width; wrapMode: Text.Wrap; text: modelData.error ?? ""; font.pixelSize: 13; color: Appearance.colors.colClay }
                    ClaudeText { visible: (modelData.response ?? "").length > 0; width: parent.width; markdown: modelData.response ?? "" }
                }
            }
        }
    }
}
