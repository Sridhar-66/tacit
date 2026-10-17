import QtQuick
import qs.modules.common
import "Info.js" as Info

// Play, time and the seek line, for video (one row) and audio (the wave, then a row under it).
// The ticks are the time: filled up to the playhead, a tall one on it, a wave of loudness for audio.
Item {
    id: root
    required property var v
    property bool audio: false
    property real pad: 0
    readonly property color main: Appearance.colors.colInkMain
    readonly property color sec: Appearance.colors.colInkSecondary
    readonly property color faint: Appearance.colors.colInkFaint
    readonly property real prog: v.duration > 0 ? v.position / v.duration : 0
    readonly property bool playing: v.playing
    implicitHeight: audio ? 112 : 40

    component Icon: VGlyph {
        id: ic
        property bool on: false
        property var tap: null
        ink: on ? 0 : 1
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (ic.tap) ic.tap() }
    }

    // ---- the seek line
    Item {
        id: line
        x: root.audio ? root.pad : root.pad + 100
        y: root.audio ? 0 : 0
        width: root.audio ? root.width - 2 * root.pad : root.width - 2 * root.pad - 100 - 190
        height: root.audio ? 56 : 40
        property real hover: -1
        Repeater {
            model: 120
            Rectangle {
                required property int index
                readonly property real f: index / 119
                readonly property real amp: root.audio ? Math.max(0.06, Math.pow(root.v.peaks[index] ?? 0.4, 2.2)) : 0
                x: index * (line.width - 2) / 119
                width: 2
                radius: 1
                height: root.audio ? Math.max(4, amp * (line.height - 2))
                    : index === Math.round(root.prog * 119) ? line.height - 6 : (index % 10 === 0 ? 22 : 14)
                y: (line.height - height) / 2
                color: f <= root.prog ? root.main : root.faint
            }
        }
        // where a click would land
        Rectangle { visible: line.hover >= 0; x: line.hover * (line.width - 2); width: 2; height: root.audio ? line.height : 28; y: (line.height - height) / 2; radius: 1; color: root.sec }
        VT {
            visible: line.hover >= 0
            x: Math.max(0, Math.min(line.width - width, line.hover * line.width - width / 2))
            y: -26
            ink: 1
            font.pixelSize: 13
            text: Info.clock(line.hover * root.v.duration)
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: m => { line.hover = Math.max(0, Math.min(1, m.x / width)); if (pressed) root.v.seekTo(line.hover); }
            onPressed: m => root.v.seekTo(Math.max(0, Math.min(1, m.x / width)))
            onExited: line.hover = -1
        }
    }

    // ---- video: play, time, line, remaining, tracks / volume / speed on one row
    VGlyph { visible: !root.audio; x: root.pad; y: 8; ink: 0; iconSize: 24; fill: 1; text: root.playing ? "pause" : "play_arrow"
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.v.togglePlay() } }
    VT { visible: !root.audio; x: root.pad + 36; y: 10; text: Info.clock(root.v.position) }
    VT { visible: !root.audio; x: root.width - root.pad - 176; y: 10; ink: 1; text: "−" + Info.clock(Math.max(0, root.v.duration - root.v.position)) }
    Row {
        visible: !root.audio
        x: root.width - root.pad - 112
        y: 8
        spacing: 14
        Icon { text: "closed_caption"; on: root.v.subtitleOn; tap: () => root.v.cycleSubtitles() }
        Icon { text: root.v.muted || root.v.volume === 0 ? "volume_off" : "volume_up"; tap: () => root.v.toggleMute() }
        Icon { text: "speed"; on: root.v.rate !== 1; tap: () => root.v.cycleRate() }
    }

    // ---- audio: times at the ends, the controls between
    VT { visible: root.audio; x: root.pad; y: 70; text: Info.clock(root.v.position) }
    VT { visible: root.audio; x: root.width - root.pad - width; y: 70; ink: 1; text: "−" + Info.clock(Math.max(0, root.v.duration - root.v.position)) }
    Row {
        visible: root.audio
        x: (root.width - width) / 2
        y: 64
        spacing: 26
        Icon { text: "skip_previous"; iconSize: 22; fill: 1; tap: () => root.v.step(-1, true) }
        Icon { text: root.playing ? "pause" : "play_arrow"; iconSize: 26; fill: 1; ink: 0; tap: () => root.v.togglePlay() }
        Icon { text: "skip_next"; iconSize: 22; fill: 1; tap: () => root.v.step(1, true) }
    }
    Row {
        visible: root.audio
        x: root.width - root.pad - 70 - width
        y: 66
        spacing: 14
        Icon { text: root.v.muted || root.v.volume === 0 ? "volume_off" : "volume_up"; tap: () => root.v.toggleMute() }
        Icon { text: "speed"; on: root.v.rate !== 1; tap: () => root.v.cycleRate() }
    }
}
