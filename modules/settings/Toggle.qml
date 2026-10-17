import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * The switch Settings uses, only for a real on/off: on is a sand track with the dark knob (sand's
 * own ink), off an outline with a quiet knob, so the two read apart at a glance.
 */
Switch {
    id: sw
    implicitWidth: 40
    implicitHeight: 24
    padding: 0
    background: null
    contentItem: null

    indicator: Rectangle {
        implicitWidth: 40
        implicitHeight: 24
        radius: 12
        color: sw.checked ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 1)
        border.width: sw.checked ? 0 : 1.5
        border.color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.7)
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Appearance.m3colors.m3onPrimary : Tacit.inkMeta
            Behavior on x { Anim { type: Anim.FastSpatial } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }
}
