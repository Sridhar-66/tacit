import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

/**
 * The popup stack. A Column, not a ListView: a ListView measures a row once, when it places
 * it, and keeps that height (a row arriving expanded with its reply field grew from 59 to
 * 143 and the row below stayed at y=59: overlap; forceLayout did not help). A Column follows
 * its children's heights by construction. Arrival is the Column's add transition; a row on
 * its way out (Notifications marks it `leaving`, then drops it after the motion) slides out
 * and collapses its height itself, so rows below and the panel move in step.
 */
Column {
    id: root
    property bool reverse: false   // bottom-docked panels: newest at the bottom
    // what NotificationGroup expects from its list (drag-to-dismiss lets neighbours follow)
    property int dragIndex: -1
    property real dragDistance: 0
    function resetDrag() {
        root.dragIndex = -1;
        root.dragDistance = 0;
    }
    // The panel is sized from this: rows on their way out are left out at once, and the
    // stack ends on a whole row under maxHeight (a burst shows the newest rows entire, the
    // rest wait in the centre) rather than cutting a row in half.
    property real maxHeight: 1e9
    readonly property real rowsHeight: {
        let h = 0;
        for (const c of root.children) {
            if (c.leaving !== false)
                continue;
            if (h > 0 && h + c.height > root.maxHeight)
                break;
            h += c.height;
        }
        return h;
    }
    spacing: 0

    // A row comes out of the panel's edge: a short drop plus a fade, like the notch's sheet.
    add: Transition {
        NumberAnimation {
            property: "y"
            from: ViewTransition.destination.y + (root.reverse ? 12 : -12)
            to: ViewTransition.destination.y
            duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
        }
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.animationCurves.expressiveDefaultEffectsDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultEffects
        }
    }
    move: Transition {
        NumberAnimation {
            property: "y"
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.reverse ? Notifications.popupAppNameList.slice().reverse() : Notifications.popupAppNameList
        }
        delegate: NotificationGroup {
            required property int index
            required property var modelData
            popup: true
            width: root.width
            qmlParent: root
            notificationGroup: Notifications.popupGroupsByAppName[modelData]
        }
    }
}
