import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * An agent's whole run as ticks: one per step, or one per run of steps when there are more than fit,
 * drawn as the most telling kind in it (a picture tallest, then an edit, a command, a read). A band
 * marks the steps the list below has in view. Hovering reads a step; pressing and dragging moves the
 * list through the run.
 */
Item {
    id: strip
    property var kinds: []            // per step: "picture" | "edit" | "command" | "read"
    property var labels: []           // per step: what it did, for the hover
    property int viewLo: -1
    property int viewHi: -1
    property var fresh: ({})          // step index -> true while it has just arrived
    signal jump(int index)
    implicitHeight: 28
    readonly property int n: strip.kinds.length
    readonly property int per: Math.max(1, Math.ceil(strip.n / Math.max(1, Math.floor(strip.width / 3))))
    readonly property var bins: {
        const rank = { picture: 3, edit: 2, command: 1, read: 0 };
        const out = [];
        for (let i = 0; i < strip.n; i += strip.per) {
            let best = i;
            for (let j = i; j < Math.min(strip.n, i + strip.per); j++) if ((rank[strip.kinds[j]] ?? 0) > (rank[strip.kinds[best]] ?? 0)) best = j;
            out.push({ at: i, best: best, kind: strip.kinds[best] });
        }
        return out;
    }
    readonly property real step: strip.bins.length ? Math.min(6, strip.width / strip.bins.length) : 4
    property int hot: -1
    function binAt(x) { return Math.max(0, Math.min(strip.bins.length - 1, Math.floor(x / strip.step))); }
    function height_(k) { return k === "picture" ? 26 : k === "edit" ? 18 : k === "command" ? 11 : 6; }
    function tone(k, on) {
        if (on) return Appearance.colors.colPrimary;
        return k === "picture" ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.38)
             : k === "edit" ? ColorUtils.transparentize(Appearance.colors.colInkMain, 0.5)
             : k === "command" ? ColorUtils.transparentize(Appearance.colors.colInkMain, 0.74)
             : ColorUtils.transparentize(Appearance.colors.colInkMain, 0.85);
    }

    // the band: the steps in view below
    Rectangle {
        visible: strip.viewHi >= 0 && strip.n > 0
        x: strip.viewLo / strip.per * strip.step - 3
        width: Math.max(8, (strip.viewHi - strip.viewLo + 1) / strip.per * strip.step + 6)
        y: -3
        height: parent.height + 6
        radius: 5
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
        Behavior on x { NumberAnimation { duration: 140 } }
        Behavior on width { NumberAnimation { duration: 140 } }
    }
    Repeater {
        model: strip.bins
        Rectangle {
            id: tick
            required property var modelData
            required property int index
            x: tick.index * strip.step
            width: Math.max(1, strip.step - 1)
            height: strip.height_(tick.modelData.kind)
            y: strip.height - height
            radius: 1
            color: strip.tone(tick.modelData.kind, strip.hot === tick.index)
            transformOrigin: Item.Bottom
            scale: strip.fresh[tick.modelData.best] ? 0 : 1
            Component.onCompleted: if (strip.fresh[tick.modelData.best]) scale = 1
            Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.SizeHorCursor : Qt.PointingHandCursor
        onPositionChanged: m => { strip.hot = strip.binAt(m.x); if (pressed) strip.jump(strip.bins[strip.hot].best); }
        onExited: strip.hot = -1
        onPressed: m => { strip.hot = strip.binAt(m.x); strip.jump(strip.bins[strip.hot].best); }
    }
    StyledToolTip {
        extraVisibleCondition: area.containsMouse && strip.hot >= 0
        text: strip.hot >= 0 && strip.bins[strip.hot] ? `Step ${strip.bins[strip.hot].best + 1} of ${strip.n} · ${strip.labels[strip.bins[strip.hot].best] ?? ""}` : ""
    }
}
