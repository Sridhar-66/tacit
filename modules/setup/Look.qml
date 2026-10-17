pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

// Setup's look: the inks the setup reviews settled on (further apart than the apps' on this black sky),
// the horizon's light for actions, and one unit that scales the 1920 x 1080 design to any screen.
Singleton {
    property real u: 1                  // set by setup.qml from the screen
    property real text: 1               // "Larger text" makes it 1.25
    property bool lessMotion: false
    readonly property color main: Appearance.colors.colInkMain
    // Tacit's ink levels on this sky (APCA Lc 85 and 75 on #050505, the apps' sec and meta floor): the greys the setup
    // reviews settled on read Lc 71 and 45, and the small grey lines were hard to read (owner, 2026-10-17)
    readonly property color sec: "#e2dad8"
    readonly property color meta: "#d1cac8"
    readonly property color light: "#f3c59a"        // the horizon's light (scripts/setup/render-horizons.py)
    readonly property string display: Appearance.font.family.display
    function px(n) { return Math.round(n * u); }
    function fs(n) { return Math.round(n * u * text); }
}
