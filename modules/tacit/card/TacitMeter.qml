import QtQuick
import qs.modules.common
import qs.modules.common.functions

// A 4 px meter: primary on a wash.
Rectangle {
    property real value: 0
    implicitHeight: 4
    radius: 2
    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.9)
    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, parent.value))
        height: parent.height
        radius: 2
        color: Appearance.colors.colPrimary
    }
}
