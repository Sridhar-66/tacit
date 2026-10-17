import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * A workflow's phases as lanes, one line each: the phase's name, a slim bar with a segment per agent
 * (a hair each past 40, one bar by state past 170), and how many are done (the rest on hover). Done is full ink, running breathes in
 * sand, failed is clay, stopped is an outline, waiting an empty track. The agents' names are in the list
 * under the lanes, not repeated here; a segment shows its agent's name on hover and opens it.
 */
Column {
    id: lanes
    property var phases: []           // [{ name, members: [member] }]
    property real now: Date.now()
    signal openAgent(string id)
    spacing: 8

    function tone(s) {
        return s === "done" ? Appearance.colors.colInkSecondary
             : s === "running" ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.25)
             : s === "failed" ? Appearance.colors.colClay
             : s === "stopped" ? "transparent"
             : ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.9);
    }
    function counts(ms) {
        const c = { done: 0, running: 0, failed: 0, stopped: 0, waiting: 0 };
        for (const m of ms) c[c[m.state] !== undefined ? m.state : "waiting"]++;
        return [`${c.done} of ${ms.length} done`, c.running ? `${c.running} running` : "", c.failed ? `${c.failed} failed` : "", c.stopped ? `${c.stopped} stopped` : "", c.waiting ? `${c.waiting} waiting` : ""].filter(x => x).join(" · ");
    }

    Repeater {
        model: lanes.phases
        Item {
            id: lane
            required property var modelData
            readonly property var ms: lane.modelData.members
            width: lanes.width
            height: 22
            StyledText {
                width: 80
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: lane.modelData.name
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Appearance.colors.colInkSecondary
            }
            StyledText {
                id: laneCount
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: `${lane.ms.filter(m => m.state === "done").length} of ${lane.ms.length}`
                font.pixelSize: 14
                font.features: { "tnum": 1 }
                color: Appearance.colors.colInkMeta
                StyledToolTip { text: lanes.counts(lane.ms); extraVisibleCondition: countArea.containsMouse }
                MouseArea { id: countArea; anchors.fill: parent; hoverEnabled: true }
            }
            Column {
                id: laneCol
                x: 90
                width: parent.width - 90 - laneCount.width - 14
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    width: parent.width
                    height: 6
                    spacing: lane.ms.length > 40 ? 0 : 3
                    Repeater {
                        model: lane.ms.length <= 170 ? lane.ms : []
                        Rectangle {
                            id: seg
                            required property var modelData
                            width: (parent.width - parent.spacing * (lane.ms.length - 1)) / Math.max(1, lane.ms.length)
                            height: 6
                            radius: lane.ms.length > 40 ? 0 : 3
                            color: lanes.tone(seg.modelData.state)
                            border.width: seg.modelData.state === "stopped" && lane.ms.length <= 40 ? 1 : 0
                            border.color: Appearance.colors.colInkFaint
                            SequentialAnimation on opacity {
                                running: seg.modelData.state === "running" && seg.visible && Appearance.agentsMoving
                                loops: Animation.Infinite
                                alwaysRunToEnd: true    // a breath stopped mid-way finishes, then rests
                                NumberAnimation { to: 0.5; duration: 1400; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                            }
                            MouseArea { id: segArea; anchors { fill: parent; topMargin: -6; bottomMargin: -6 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lanes.openAgent(seg.modelData.agent) }
                            StyledToolTip { text: seg.modelData.label || "Agent"; extraVisibleCondition: segArea.containsMouse }
                        }
                    }
                    // past 170, one bar by state
                    Repeater {
                        model: lane.ms.length > 170 ? ["done", "running", "failed", "stopped", "waiting"] : []
                        Rectangle {
                            required property string modelData
                            readonly property int n: lane.ms.filter(m => m.state === modelData || (modelData === "waiting" && !["done", "running", "failed", "stopped"].includes(m.state))).length
                            width: parent.width * n / lane.ms.length
                            height: 6
                            color: lanes.tone(modelData)
                        }
                    }
                }
            }
        }
    }
}
