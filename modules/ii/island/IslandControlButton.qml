import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Round icon button for the island's expanded states.
 */
RippleButton {
    id: button

    // NOT `icon`: RippleButton derives from QtQuick.Controls Button, whose grouped
    // `icon` property is FINAL. Declaring one here made the whole component fail to
    // load ("Cannot override FINAL property"), which took IslandDashboard with it.
    property string glyph: ""
    property real iconSize: 20
    signal activated

    implicitWidth: 32
    implicitHeight: 32
    padding: 0
    buttonRadius: Appearance.rounding.full
    // Previous and next lean the way they go; play and pause settle in when one replaces the other.
    readonly property real lean: button.glyph === "skip_next" ? 3 : (button.glyph === "skip_previous" ? -3 : 0)
    property bool ready: false
    Component.onCompleted: button.ready = true
    onGlyphChanged: if (button.ready) motion.settle()
    releaseAction: () => {
        if (button.lean !== 0)
            motion.nudge(button.lean);
        button.activated();
    }

    SymbolMotion {
        id: motion
        target: symbol
    }

    contentItem: MaterialSymbol {
        id: symbol
        text: button.glyph
        iconSize: button.iconSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: button.toggled ? Appearance.colors.colOnPrimary : IslandController.contentColor
    }
}
