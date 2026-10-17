import QtQuick
import Quickshell
import Quickshell.Io

// The boot sky. mode "dawn", under the boot lock (bootlock.qml): from the still the splash held, the limb rises, the
// name focuses in, the sun comes up and lights the person's picture from the edge, and the camera goes in until their
// picture fills the screen - the lock ground itself, so the sky can go without a cut. mode "dusk", over the desktop
// at shut down and restart (Dusk.qml): the desktop (`material`, a capture of the screen) curves away into the planet,
// its light goes back to the edge and the limb sets, down to black. Everything follows `t` (seconds); play() runs it,
// finish() takes a dawn to its end in half a second (any key or touch).
// The look is the approved mockup's (~/book4-edge/tacit-boot-mocks/ease7.py); shaders/bootsky.frag draws it.
Item {
    id: sky
    property real t: 0
    property string mode: "dawn"
    readonly property bool dusk: mode === "dusk"
    readonly property real end: dusk ? 3.9 : 5.6
    property Item material: null     // dusk: what the planet's surface shows (the desktop); dawn: the ground image
    property string groundPath: ""
    // the person's atmosphere (tacit-boot-ground writes it beside the ground); the dusk palette until it is read
    property var palette: ({ glow: [["#ffe2bf", 2.6, 5.0], ["#fbc2b1", 1.1, 24.0], ["#d67d63", 0.32, 100.0], ["#81402e", 0.1, 380.0]], sky: "#0b0605" })
    property string palettePath: ""
    readonly property bool done: t >= end
    // the light has settled on the person's picture: the lock's clock and field come in
    signal arrived()
    readonly property bool settled: !dusk && t >= 4.6
    onSettledChanged: if (settled) arrived()
    visible: dusk || !done

    // On the wall clock, not on frames: at boot the full shell loads beside the lock, and an animation that steps per
    // frame would play the sunrise in slow motion; this one drops frames instead and keeps its time.
    property real startMs: 0
    property real rushMs: 0         // finish(): the moment it began, and where t was
    property real rushFrom: 0
    function play() { sky.startMs = Date.now() - sky.t * 1000; sky.rushMs = 0; clock.running = true; }
    function finish() {
        if (sky.done || sky.rushMs > 0) return;
        sky.rushFrom = sky.t; sky.rushMs = Date.now(); clock.running = true;
    }
    FrameAnimation {
        id: clock
        running: false
        onTriggered: {
            const now = Date.now();
            if (sky.rushMs > 0) {
                const x = Math.min((now - sky.rushMs) / 500, 1);
                sky.t = sky.rushFrom + (sky.end - sky.rushFrom) * (1 - Math.pow(1 - x, 3));
            } else {
                sky.t = Math.min((now - sky.startMs) / 1000, sky.end);
            }
            if (sky.t >= sky.end) clock.running = false;
        }
    }

    // the mockup's curves
    function clamp01(x) { return Math.min(Math.max(x, 0), 1); }
    function seg(a, b) { return clamp01((sky.t - a) / (b - a)); }
    function easeIO(x) { x = clamp01(x); return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; }
    function smooth(a, b) { const x = sky.seg(a, b); return x * x * (3 - 2 * x); }
    function lerp(a, b, x) { return a + (b - a) * x; }
    function lin(hex, k) {
        const c = Qt.color(hex);
        return Qt.vector4d(Math.pow(c.r, 2.2), Math.pow(c.g, 2.2), Math.pow(c.b, 2.2), k);
    }

    readonly property real eRise: easeIO(seg(0, 3.0))
    readonly property real eIn: easeIO(seg(3.2, 5.4))
    readonly property real eOut: easeIO(seg(0, 1.9))      // dusk: the desktop curves away into the planet
    readonly property real eSet: easeIO(seg(2.2, 3.6))    // ...and sets
    readonly property real halo: dusk ? smooth(0, 0.5) : 1 - smooth(4.2, 5.4)

    FileView {
        path: sky.palettePath
        blockLoading: true
        onLoaded: { try { sky.palette = JSON.parse(text()); } catch (e) {} }
    }
    Image {
        id: groundImage
        source: sky.groundPath.length ? "file://" + sky.groundPath : ""
        visible: false
        cache: false
        sourceSize: Qt.size(sky.width, sky.height)
        fillMode: Image.PreserveAspectCrop
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        property vector2d res: Qt.vector2d(width, height)
        property real domeTop: sky.dusk ? sky.lerp(sky.lerp(-0.12 * height, 0.70 * height, sky.eOut), 1.02 * height, sky.eSet)
                                        : sky.lerp(sky.lerp(0.95 * height, 0.70 * height, sky.eRise), -0.35 * height, sky.eIn)
        property real radius: sky.dusk ? sky.lerp(4.0 * width, 1.1 * width, sky.eOut) : sky.lerp(1.1 * width, 4.0 * width, sky.eIn)
        property real push: sky.dusk ? 1 : 1 + 0.04 * sky.seg(0, 3.0) * (1 - sky.eIn)
        property real sun: sky.dusk ? sky.smooth(0.6, 1.4) * (1 - sky.smooth(1.8, 3.0))
                                    : sky.easeIO(sky.seg(1.2, 3.4)) * (1 - sky.easeIO(sky.seg(3.6, 5.4)))
        property real day: sky.dusk ? 1 - sky.easeIO(sky.seg(0.6, 2.6)) : sky.easeIO(sky.seg(2.4, 5.0))
        property real fade: sky.dusk ? 1 - sky.smooth(3.3, 3.9) : 1
        property real halo: sky.halo
        // no grain in the first frames: they must equal the still the splash and the compositor held
        property real film: sky.halo * sky.smooth(0, 0.6)
        property real frame: 0
        property vector4d sky: { const c = Qt.color(sky.palette.sky); return Qt.vector4d(Math.pow(c.r, 2.2), Math.pow(c.g, 2.2), Math.pow(c.b, 2.2), 1); }
        property vector4d glow0: sky.lin(sky.palette.glow[0][0], sky.palette.glow[0][1])
        property vector4d glow1: sky.lin(sky.palette.glow[1][0], sky.palette.glow[1][1])
        property vector4d glow2: sky.lin(sky.palette.glow[2][0], sky.palette.glow[2][1])
        property vector4d glow3: sky.lin(sky.palette.glow[3][0], sky.palette.glow[3][1])
        property vector4d widths: Qt.vector4d(sky.palette.glow[0][2], sky.palette.glow[1][2], sky.palette.glow[2][2], sky.palette.glow[3][2])
        property variant ground: sky.material ?? groundImage
        fragmentShader: Qt.resolvedUrl("shaders/bootsky.frag.qsb")
        FrameAnimation { running: sky.t > 0 && !sky.done; onTriggered: fx.frame = (fx.frame + 1) % 997 }
    }

    // The name: small and centred, in its place; it focuses in after the limb starts and leaves before the light.
    Text {
        visible: !sky.dusk
        readonly property real k: sky.height / 1080
        x: (sky.width - width) / 2 + 13 * k
        y: sky.height * 0.44 - height / 2
        text: "TACIT"
        color: "#f3f0ea"
        font.family: "Tacit Sans Display"
        font.pixelSize: Math.round(56 * k)
        font.letterSpacing: 26 * k
        font.variableAxes: { "wght": 400 }
        opacity: sky.smooth(0.2, 1.0) * (1 - sky.smooth(3.0, 3.6))
    }
}
