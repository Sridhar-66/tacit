import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A list under a small label: one row per thing, biggest first. Past `maxRows` the rest fold into one
// last row, "and N more", which opens the full list (`foldOpens`). `wrap`: the full list, nothing folds.
Item {
    id: band
    property string label: ""
    property var items: []
    property int maxRows: 7
    property bool wrap: false
    property bool foldHot: false            // the folded rest is the cause
    property var foldWord: rest => ""       // the fold's amount, from the items it holds
    property string foldKey: ""
    property bool foldOpens: false
    signal opened(var item)
    signal act(var item, string what)

    readonly property var shown: {
        const list = band.items ?? [];
        if (band.wrap || list.length <= band.maxRows)
            return list;
        const rest = list.slice(band.maxRows - 1);
        return list.slice(0, band.maxRows - 1).concat([{ key: band.foldKey, n: `and ${rest.length} more`, c1: band.foldWord(rest),
                                                         fold: true, hot: band.foldHot, open: band.foldOpens }]);
    }
    readonly property real labelRoom: band.label !== "" ? 36 : 0
    height: band.labelRoom + rows.height

    T {
        visible: band.label !== ""
        text: band.label
        height: 28
        verticalAlignment: Text.AlignBottom
        color: Ink.meta
        font.pixelSize: 15
        font.weight: Font.Medium
    }
    Column {
        id: rows
        y: band.labelRoom
        width: band.width
        // a row that changes place eases there; a new one fades in where it lands
        move: Transition { Anim { properties: "y"; type: Anim.FastSpatial } }
        add: Transition { Anim { property: "appear"; from: 0; to: 1; type: Anim.DefaultEffects } }
        Repeater {
            // keyed, so a row that moves keeps its delegate (and its hover)
            model: ScriptModel { values: band.shown; objectProp: "key" }
            Line {
                required property var modelData
                width: rows.width
                item: modelData
                onOpened: it => band.opened(it)
                onAct: (it, what) => band.act(it, what)
            }
        }
    }
}
