import QtQuick
import qs.modules.common

// A colour change on Tacit's fast-effects curve (150 ms): hover and focus. CAnim is the slow one (300 ms),
// which made a row trail the pointer.
ColorAnimation {
    duration: Appearance.animationCurves.expressiveFastEffectsDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.animationCurves.expressiveFastEffects
}
