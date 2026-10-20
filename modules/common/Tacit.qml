pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common.functions

// Tacit's kit (2026-10-08, the owner's go; https://claude.ai/artifact/CKcjMwxz7yFW8kEbpx5gXY): one set of inks, one
// meaning for colour, one type scale and corners, for every Tacit app. All of it follows the wallpaper's palette
// (Appearance's matugen roles); the inks reach fixed APCA contrast on the panel ground whatever the palette.
// Actions are Slab (widgets/Slab.qml).
Singleton {
    id: root

    // ---- inks: text by brightness, never by opacity (Activity's levels, the brighter secondary and meta)
    readonly property color inkMain: Appearance.colors.colInkMain
    readonly property color inkSec: ColorUtils.mix(Appearance.colors.colInkMain, Appearance.colors.colInkSecondary, 0.25)
    readonly property color inkMeta: ColorUtils.mix(Appearance.colors.colInkSecondary, Appearance.colors.colInkMeta, 0.4)
    readonly property color inkFaint: Appearance.colors.colInkFaint
    readonly property color hairline: Appearance.colors.colInkDivider

    // ---- colour by meaning
    // the default, safe action (Enter), and a cause in a sentence: the palette's accent ("sand" on dusk)
    readonly property color accent: Appearance.colors.colPrimary
    readonly property color onAccent: Appearance.m3colors.m3onPrimary
    // an action that risks something: the palette's error role, always with a warning symbol (on some palettes it
    // sits close to the accent)
    readonly property color risk: Appearance.m3colors.m3error
    // the ground slabs and panels stand on, and a slab raised from it
    readonly property color ground: Appearance.m3colors.m3surfaceContainerLow
    readonly property color raised: ColorUtils.mix(inkMain, ground, 0.11)
    readonly property color raisedHot: ColorUtils.mix(inkMain, ground, 0.17)
    // how far every Tacit app's window lets the blur through, as Settings > Appearance has it: Frosted is the terminal's
    // ground at foot's alpha 0.85 (foot.ini), Solid none, Clear its own amount. One number, so the apps cannot drift
    // apart (Praxis and the Store had, 2026-10-15). Shell surfaces use the frost.
    readonly property real windowSeeThrough: !Config.options.appearance.transparency.enable ? 0
        : Config.options.appearance.transparency.automatic ? 0.15 : Config.options.appearance.transparency.backgroundTransparency

    // ---- type: six sizes; hierarchy by size and weight
    readonly property QtObject size: QtObject {
        readonly property int alarm: 40
        readonly property int headline: 30
        readonly property int section: 22
        readonly property int body: 17
        readonly property int row: 15
        readonly property int meta: 13
    }
    // ---- corners
    readonly property QtObject radius: QtObject {
        readonly property int slab: 12
        readonly property int rowSlab: 10
        readonly property int panel: 14
    }

    // `fg` toward `bg` as far as it keeps APCA Lc `lc` on `bg`: a quieter line in the same ink
    function quieter(fg, bg, lc) {
        let lo = 0, hi = 1;
        for (let i = 0; i < 16; i++) {
            const mid = (lo + hi) / 2;
            if (Math.abs(ColorUtils.apcaLc(ColorUtils.mix(fg, bg, mid), bg)) >= lc)
                hi = mid;
            else
                lo = mid;
        }
        return ColorUtils.mix(fg, bg, hi);
    }
}
