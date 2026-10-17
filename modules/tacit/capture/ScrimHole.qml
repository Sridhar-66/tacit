import qs.modules.common
import QtQuick
import QtQuick.Shapes

// The screen dimmed with one hole where the picture stays lit: the selection, or the window the
// pointer is over. Plain component, no services: the login lock's tree may load it.
Shape {
    id: root
    property color color: "#66000000"
    property rect hole: Qt.rect(0, 0, 0, 0)
    property real radius: 0
    // Off while dragging: the hole must follow the pointer, not trail it.
    property bool animate: false

    property real hx: hole.x
    property real hy: hole.y
    property real hw: hole.width
    property real hh: hole.height
    Behavior on hx { enabled: root.animate; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
    Behavior on hy { enabled: root.animate; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
    Behavior on hw { enabled: root.animate; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
    Behavior on hh { enabled: root.animate; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }

    preferredRendererType: Shape.CurveRenderer

    function holePath() {
        const w = Math.max(0, hw), h = Math.max(0, hh);
        const r = Math.min(radius, w / 2, h / 2);
        return `M ${hx + r} ${hy} L ${hx + w - r} ${hy} A ${r} ${r} 0 0 1 ${hx + w} ${hy + r} `
            + `L ${hx + w} ${hy + h - r} A ${r} ${r} 0 0 1 ${hx + w - r} ${hy + h} `
            + `L ${hx + r} ${hy + h} A ${r} ${r} 0 0 1 ${hx} ${hy + h - r} `
            + `L ${hx} ${hy + r} A ${r} ${r} 0 0 1 ${hx + r} ${hy} Z`;
    }

    ShapePath {
        fillRule: ShapePath.OddEvenFill
        fillColor: root.color
        strokeColor: "transparent"
        PathSvg {
            path: `M 0 0 L ${root.width} 0 L ${root.width} ${root.height} L 0 ${root.height} Z ${root.holePath()}`
        }
    }
}
