import QtQuick
import QtQuick.Shapes
import qs.modules.common

/**
 * Praxis's working mark: a ring with a quarter open, turning once a second (the step A
 * mockup). The ring is drawn once; RotationAnimator turns it on the render thread, so it costs the
 * app nothing per frame and stops when the window is not drawn. The shell's Busy (the morphing
 * M3 shape) repaints a canvas on every frame: four of them in the session list held 70% of a core.
 * Resting (between agent-host's events), the ring becomes a steady dot: a ring held still mid-turn read as stuck
 * loading (2026-10-11). A dot says "in hand, quiet" and costs nothing.
 */
Item {
    id: spin
    property bool active: true
    // rests: it turns only while agents' work moves (Appearance.agentsMoving), holding its angle between
    property bool rests: false
    readonly property bool turning: spin.active && spin.visible && (!spin.rests || Appearance.agentsMoving)
    readonly property bool resting: spin.rests && spin.active && !Appearance.agentsMoving
    onTurningChanged: syncTurn()
    Component.onCompleted: syncTurn()
    // turning again continues from where it stopped, so the ring never snaps back
    function syncTurn() {
        if (spin.turning) {
            const at = ring.rotation % 360;
            turn.from = at;
            turn.to = at + 360;
            turn.start();
        } else {
            turn.stop();
        }
    }
    property real implicitSize: 16      // the footprint Busy took; the ring is 0.8 of it, as Busy's shape was ~0.7
    property color colShape: Appearance.colors.colInkSecondary
    readonly property real d: implicitSize * 0.8
    readonly property real stroke: Math.max(1.5, d / 6.5)
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Rectangle {
        anchors.centerIn: parent
        width: spin.d * 0.5
        height: width
        radius: width / 2
        color: spin.colShape
        opacity: spin.resting ? 1 : 0
        scale: spin.resting ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    Shape {
        id: ring
        anchors.centerIn: parent
        width: spin.d
        height: spin.d
        opacity: spin.resting ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: spin.colShape
            strokeWidth: spin.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: spin.d / 2
                centerY: spin.d / 2
                radiusX: (spin.d - spin.stroke) / 2
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 270
            }
        }
        RotationAnimator on rotation {
            id: turn
            running: false
            from: 0
            to: 360
            duration: 1100
            loops: Animation.Infinite
        }
    }
}
