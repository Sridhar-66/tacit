import QtQuick
import qs.modules.common

// Copied from caelestia components/Anim.qml (GPL-3.0). One typed NumberAnimation
// so every site says `Anim { type: Anim.FastSpatial }` instead of spelling out
// duration + easing.type + easing.bezierCurve.
//
// Only adaptation: caelestia's Tokens.anim.<curve> are QEasingCurve values built in
// C++ (plugin/src/Caelestia/Config/anim.cpp), so they assign `easing:` directly. Our
// curves are list<real>, so the same curve is set as BezierSpline + bezierCurve.
NumberAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    readonly property QtObject curves: Appearance.animationCurves

    duration: {
        if (type < Anim.StandardSmall || type > Anim.SlowEffects)
            return curves.normalDuration;

        if (type === Anim.FastSpatial)
            return curves.expressiveFastSpatialDuration;
        if (type === Anim.DefaultSpatial)
            return curves.expressiveDefaultSpatialDuration;
        if (type === Anim.SlowSpatial)
            return curves.expressiveSlowSpatialDuration;
        if (type === Anim.FastEffects)
            return curves.expressiveFastEffectsDuration;
        if (type === Anim.DefaultEffects)
            return curves.expressiveDefaultEffectsDuration;
        if (type === Anim.SlowEffects)
            return curves.expressiveSlowEffectsDuration;

        const durations = [curves.smallDuration, curves.normalDuration, curves.largeDuration, curves.extraLargeDuration];
        return durations[type % 4]; // 0-7 are the 4 standard types
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        if (type === Anim.FastSpatial)
            return curves.expressiveFastSpatial;
        if (type === Anim.DefaultSpatial)
            return curves.expressiveDefaultSpatial;
        if (type === Anim.SlowSpatial)
            return curves.expressiveSlowSpatial;
        if (type === Anim.FastEffects)
            return curves.expressiveFastEffects;
        if (type === Anim.DefaultEffects)
            return curves.expressiveDefaultEffects;
        if (type === Anim.SlowEffects)
            return curves.expressiveSlowEffects;

        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return curves.emphasized;
        return curves.standard;
    }
}
