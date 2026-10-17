import QtQuick
import qs.modules.common
import qs.modules.common.functions

/**
 * How far a set of agents is, as one thin bar: a segment per agent while they fit (up to 40), one
 * bar split by state in proportion beyond that. Finished is the meta ink, running breathes in sand,
 * failed is clay, stopped is faint, waiting is an empty track.
 */
Item {
    id: bar
    property var states: []           // "done" | "running" | "failed" | "waiting" | "stopped"
    implicitHeight: 3
    height: 3
    function tone(s) {
        return s === "done" ? ColorUtils.transparentize(Appearance.colors.colInkMeta, 0.35)
             : s === "running" ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)
             : s === "failed" ? Appearance.colors.colClay
             : s === "stopped" ? ColorUtils.transparentize(Appearance.colors.colInkFaint, 0.6)
             : ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.88);
    }
    readonly property var counts: {
        const c = { done: 0, running: 0, failed: 0, stopped: 0, waiting: 0 };
        for (const s of bar.states) c[c[s] !== undefined ? s : "waiting"]++;
        return c;
    }
    Row {
        visible: bar.states.length <= 40
        anchors.fill: parent
        spacing: 3
        Repeater {
            model: bar.states.length <= 40 ? bar.states : []
            Rectangle {
                required property string modelData
                width: Math.max(2, (bar.width - 3 * (bar.states.length - 1)) / Math.max(1, bar.states.length))
                height: 3
                radius: 1.5
                color: bar.tone(modelData)
                SequentialAnimation on opacity {
                    running: modelData === "running" && bar.visible && Appearance.agentsMoving
                    loops: Animation.Infinite
                    alwaysRunToEnd: true    // a breath stopped mid-way finishes, then rests
                    NumberAnimation { to: 0.5; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    Row {
        visible: bar.states.length > 40
        anchors.fill: parent
        Repeater {
            model: bar.states.length > 40 ? ["done", "running", "failed", "stopped", "waiting"].filter(k => bar.counts[k] > 0) : []
            Rectangle {
                required property string modelData
                width: bar.width * bar.counts[modelData] / Math.max(1, bar.states.length)
                height: 3
                color: bar.tone(modelData)
            }
        }
    }
}
