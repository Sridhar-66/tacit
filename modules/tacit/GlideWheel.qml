import QtQuick
import qs.modules.common

// Touchpad scrolling as the browser does it: the view follows the fingers one to one (Qt's
// pixel delta, already scaled by Hyprland's touchpad scroll_factor) and, after a flick, glides
// on at the release speed, slowing by 0.998 per millisecond (UIKit's normal deceleration).
// A slow scroll stops where the fingers stop. A mouse wheel moves one eased step per notch.
// A mostly sideways scroll is left to the view.
MouseArea {
    id: glide
    required property Flickable view
    property real velocity: 0       // px per ms, in contentY's direction
    // true while it moves the view (fingers on the pad, a glide, a notch's step): a view that eases
    // its own contentY turns that easing off meanwhile, or the one-to-one moves are smeared
    readonly property bool active: glide.touching || momentum.running || step.running
    property bool touching: false
    property var samples: []        // [ms, dy] of the last moves, as the view moved
    // Touchpad gain rising with finger speed: a slow move stays precise, a quick swipe goes far, and
    // the glide after it carries that speed. 1, 0, 1 is 1:1 (Files).
    property real gain: 1
    property real gainPerSpeed: 0   // added per px/ms of finger speed
    property real gainMax: 1
    property var raw: []            // [ms, dy] as the pad sent them, for the finger's speed
    // A view inside another scrolling view (a diff in the conversation): what it can't take, being
    // at its end that way, goes on to the view under it instead of stopping there.
    property bool chain: false

    anchors.fill: parent
    acceptedButtons: Qt.NoButton

    function range() {
        const minY = glide.view.originY - glide.view.topMargin;
        return [minY, Math.max(minY, glide.view.contentHeight + glide.view.bottomMargin - glide.view.height + glide.view.originY)];
    }
    // returns false at an end
    function moveBy(dy) {
        const r = glide.range();
        const y = Math.max(r[0], Math.min(glide.view.contentY + dy, r[1]));
        const moved = y !== glide.view.contentY;
        glide.view.contentY = y;
        return moved;
    }
    // One touchpad event; split out so a scene can drive it with made-up timings.
    function touch(dy, phase, now) {
        glide.touching = phase !== Qt.ScrollEnd;
        idle.restart();
        if (phase === Qt.ScrollBegin) {
            momentum.stop();
            glide.samples = [];
            glide.raw = [];
        }
        if (dy !== 0) {
            momentum.stop();
            glide.raw = glide.raw.filter(s => now - s[0] <= 50).concat([[now, dy]]);
            const speed = Math.abs(glide.raw.reduce((a, s) => a + s[1], 0)) / Math.max(8, now - glide.raw[0][0]);
            const k = Math.min(glide.gainMax, glide.gain + glide.gainPerSpeed * speed);
            glide.moveBy(dy * k);
            glide.samples = glide.samples.filter(s => now - s[0] <= 80).concat([[now, dy * k]]);
        }
        if (phase === Qt.ScrollEnd && !momentum.running) {
            // the speed of the last 80 ms, if the fingers were still moving when they lifted
            const recent = glide.samples.filter(s => now - s[0] <= 80);
            const moving = recent.length > 1 && now - recent[recent.length - 1][0] <= 40;
            const span = moving ? Math.max(16, now - recent[0][0]) : 0;
            glide.velocity = moving ? recent.reduce((a, s) => a + s[1], 0) / span : 0;
            glide.samples = [];
            glide.raw = [];
            if (Math.abs(glide.velocity) > 0.1)
                momentum.start();
        }
    }

    onWheel: e => {
        if (Math.abs(e.pixelDelta.x) + Math.abs(e.angleDelta.x) > Math.abs(e.pixelDelta.y) + Math.abs(e.angleDelta.y)) {
            e.accepted = false;
            return;
        }
        if (glide.chain) {
            const dy = e.pixelDelta.y !== 0 ? -e.pixelDelta.y : -e.angleDelta.y;
            const r = glide.range();
            if ((dy > 0 && glide.view.contentY >= r[1] - 0.5) || (dy < 0 && glide.view.contentY <= r[0] + 0.5)) {
                momentum.stop();
                e.accepted = false;
                return;
            }
        }
        if (e.phase !== Qt.NoScrollPhase || e.pixelDelta.y !== 0) {
            step.stop();
            glide.touch(-e.pixelDelta.y, e.phase, Date.now());
        } else {
            momentum.stop();
            const factor = Config?.options.interactions.scrolling.mouseScrollFactor ?? 120;
            const r = glide.range();
            const from = step.running ? step.to : glide.view.contentY;
            step.stop();
            step.to = Math.max(r[0], Math.min(from - e.angleDelta.y / 120 * factor, r[1]));
            step.start();
        }
        e.accepted = true;
    }

    // a pad that sends no end phase still lets go
    Timer { id: idle; interval: 150; onTriggered: glide.touching = false }
    FrameAnimation {
        id: momentum
        onTriggered: {
            const dt = Math.min(frameTime * 1000, 50);
            glide.velocity *= Math.pow(0.998, dt);
            if (!glide.moveBy(glide.velocity * dt) || Math.abs(glide.velocity) < 0.02)
                momentum.stop();
        }
    }
    NumberAnimation {
        id: step
        target: glide.view
        property: "contentY"
        duration: Appearance.animation.scroll.duration
        easing.type: Appearance.animation.scroll.type
        easing.bezierCurve: Appearance.animation.scroll.bezierCurve
    }
}
