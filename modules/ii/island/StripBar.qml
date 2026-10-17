import QtQuick
import qs.modules.common
import qs.modules.common.functions

// A level in the strip: a thin track in the main ink, filled to the value.
Rectangle {
    id: bar
    property real value: 0
    implicitWidth: 56
    implicitHeight: 3
    radius: 1.5
    color: ColorUtils.transparentize(Tacit.inkMain, 0.85)
    Rectangle {
        height: parent.height
        width: parent.width * Math.max(0, Math.min(1, bar.value))
        radius: parent.radius
        color: Tacit.inkMain
        Behavior on width {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }
}
