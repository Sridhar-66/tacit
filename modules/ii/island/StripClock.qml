import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// The notch's time: tabular figures in a box sized from "00:00", so nothing beside it moves as the minutes change. A
// changed digit rolls up like a counter (the rightmost first, the next 40 ms later): the old one leaves as the new one
// arrives, in step, inside a window the height of the figures, so the two never overlap.
Item {
    id: clock
    property bool back: false   // a peek shows its point: the time steps back to meta
    readonly property int base: 23   // the strip's baseline (34 tall)
    readonly property string time: DateTime.time
    property string shown: clock.time
    property string was: clock.time
    property var delays: []
    implicitWidth: Math.ceil(metrics.advanceWidth)
    implicitHeight: 34
    onTimeChanged: {
        const a = clock.shown, b = clock.time;
        let d = [], k = 0;
        for (let i = b.length - 1; i >= 0; i--) {
            if (a.length === b.length && a[i] !== b[i]) {
                d[i] = k * 40;
                k++;
            } else {
                d[i] = -1;
            }
        }
        clock.was = a;
        clock.delays = d;
        clock.shown = b;
    }
    component Figure: StyledText {
        font.family: Appearance.font.family.numbers
        font.pixelSize: 16
        // Medium: the owner's pick (2026-09-30) over the shared 450
        font.variableAxes: ({ "wght": 500 })
        font.features: ({ "tnum": 1 })
        color: clock.back ? Tacit.inkMeta : Tacit.inkMain
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }
    Figure {
        id: face
        visible: false
        text: "0"
    }
    TextMetrics {
        id: metrics
        font: face.font
        text: "00:00"
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        Repeater {
            model: clock.shown.length
            Item {
                id: cell
                required property int index
                property real e: 1
                width: figure.implicitWidth
                height: clock.height
                Connections {
                    target: clock
                    function onShownChanged() {
                        if ((clock.delays[cell.index] ?? -1) < 0)
                            return;
                        roll.stop();
                        cell.e = 0;
                        roll.start();
                    }
                }
                SequentialAnimation {
                    id: roll
                    PauseAnimation { duration: Math.max(0, clock.delays[cell.index] ?? 0) }
                    NumberAnimation { target: cell; property: "e"; to: 1; duration: 260; easing.type: Easing.InOutCubic }
                }
                Item {
                    y: clock.base - 14
                    width: parent.width
                    height: 16
                    clip: cell.e < 1
                    Figure {
                        visible: cell.e < 1
                        text: clock.was[cell.index] ?? ""
                        y: 14 - baselineOffset - 16 * cell.e
                    }
                    Figure {
                        id: figure
                        text: clock.shown[cell.index] ?? ""
                        y: 14 - baselineOffset + 16 * (1 - cell.e)
                    }
                }
            }
        }
    }
}
