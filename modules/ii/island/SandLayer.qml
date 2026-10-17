import QtQuick
import Tacit.Sand
import qs.services

// The voice as sand (2026-10-15): Flow's three bands lift grains in a thin glass tank behind the time; when you stop,
// the bed levels flat and the notch closes over it. The component and its physics: native/sand (build.sh installs it
// into ~/.local/lib/qml, found through shell.qml's QML_IMPORT_PATH).
Sand {
    // writing (Flow turning the words into text: usually under a second, ~10 s when its live stream fails and the
    // recording is heard again): the sand keeps breathing, a slow rise and fall of the bed, so the notch never sits
    // still and looks frozen ("after done recording it freezes"); it stays active, so the bed is not raised again
    readonly property bool writing: Dictation.state === "writing"
    property real breath: 0
    SequentialAnimation on breath {
        running: writing
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutSine }
    }
    active: Dictation.state === "listening" || writing
    // a live voice at the mic moved the sand less than the recorded conversation it was tuned on ("too light",
    // 2026-10-15): the bands get a gain, held to the analysis' range (1.3)
    readonly property real gain: 1.6       // measured: a live voice reached 55-75 % of the tuning recording's bands
    // loudness: flowd measures each band against its own recent peak (an automatic gain), so a soft voice filled the
    // bands like a loud one ("sensitive to my voice even though I am not talking loud"); Flow's absolute level scales
    // them back. Measured at this mic: talking median 0.28, p75 0.48, p90 0.74 - full drive from 0.55
    readonly property real loud: Math.min(1.2, Dictation.level / 0.55)
    low: writing ? 0.45 * breath : Math.min(1.3, (Dictation.bands[0] ?? 0) * gain * loud)
    mid: writing ? 0 : Math.min(1.3, (Dictation.bands[1] ?? 0) * gain * loud)
    high: writing ? 0 : Math.min(1.3, (Dictation.bands[2] ?? 0) * gain * loud)
    // denser than the film (more frequent bursts), as high as it ("overshooting too much" at puff 7600 / lift 2.8 /
    // width 1.5: the cloud top sat at the top glass in 60 % of frames; here 8 %, the film 3 %; a burst reaches 3x its
    // width upward, so width is height)
    // weight ("everything flying, no weight and gravity on the layers"): the low band's lift worked as anti-gravity -
    // at a live voice it cancelled ~70-120 % of a top grain's weight for as long as you spoke; at 0.8 it loosens the
    // bed without floating it, and the bursts (the film's 4200) throw grains that fall back in arcs
    puff: 4200
    lift: 0.8
    ventRate: 260
    ventWidth: 1.0
    // the vowels' taps through the bed, the film's vibration ("vibration feel is missing"): 10 g moved the bed's top
    // 67 % more than none; 16 g added nothing
    shake: 7
    // drawn at twice the size and scaled down: a grain is under half a pixel. A fixed size (the notch's 150 x 40): tied
    // to the width, the image was made anew on every frame of the notch's opening and closing
    fixedColorBufferWidth: 300
    fixedColorBufferHeight: 80
}
