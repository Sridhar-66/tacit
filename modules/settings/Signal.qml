import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Wi-Fi strength as one fan: the whole fan faint, the arcs reached (from the bottom) in ink. Tacit's
 * network_wifi_N_bar symbols draw the same fan at every strength, so they cannot tell them apart.
 */
Item {
    id: sig
    property int strength: 0            // 0..100, as NetworkManager reports it
    readonly property int bars: sig.strength > 66 ? 3 : sig.strength > 33 ? 2 : 1
    implicitWidth: 18
    implicitHeight: 18

    MaterialSymbol {
        anchors.fill: parent
        text: "wifi"
        iconSize: 18
        color: ColorUtils.transparentize(Appearance.colors.colInkMain, 0.88)
    }
    Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: [0, 0.5, 0.69, 1][sig.bars] * parent.height
        clip: true
        MaterialSymbol {
            anchors.bottom: parent.bottom
            width: 18
            height: 18
            text: "wifi"
            iconSize: 18
            color: Tacit.inkSec
        }
    }
}
