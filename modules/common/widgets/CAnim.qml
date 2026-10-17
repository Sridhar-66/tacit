import QtQuick
import qs.modules.common

// Copied from caelestia components/CAnim.qml (GPL-3.0): colour changes ease on the
// slow-effects curve. Same easing adaptation as Anim.qml.
ColorAnimation {
    duration: Appearance.animationCurves.expressiveSlowEffectsDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.animationCurves.expressiveSlowEffects
}
