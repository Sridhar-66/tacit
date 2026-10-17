import QtQuick
import qs.modules.common

/**
 * Motion for one symbol, used only where the movement says something: a toggle that fills in when it is
 * switched (settle), the bell that swings when notifications come on (swing), previous/next that lean the way
 * they go (nudge). Invisible; give it the symbol as `target`.
 */
Item {
    id: root
    visible: false
    required property Item target

    function settle() { settleAnim.restart(); }
    function swing() { swingAnim.restart(); }
    function nudge(dx) { nudgeOut.to = dx; nudgeAnim.restart(); }

    Translate { id: shift }
    Component.onCompleted: root.target.transform = [shift]

    NumberAnimation {
        id: settleAnim
        target: root.target
        property: "scale"
        from: 0.72
        to: 1
        duration: Appearance.animation.elementMoveFast.duration
        easing.type: Appearance.animation.elementMoveFast.type
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }
    SequentialAnimation {
        id: swingAnim
        NumberAnimation { target: root.target; property: "rotation"; to: -16; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root.target; property: "rotation"; to: 11; duration: 150; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root.target; property: "rotation"; to: -6; duration: 140; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root.target; property: "rotation"; to: 0; duration: 160; easing.type: Easing.OutQuad }
    }
    SequentialAnimation {
        id: nudgeAnim
        NumberAnimation { id: nudgeOut; target: shift; property: "x"; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation {
            target: shift
            property: "x"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
}
