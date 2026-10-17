import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets

// Text with a soft band of light sweeping across it while `active` (OpenChamber's running-tool
// shine): the text in its own tone, a brighter copy masked by a moving gradient over it.
Item {
    id: shine
    property string text: ""
    property bool active: false
    // rests: the band sweeps only while agents' work moves (Appearance.agentsMoving); a sweep under way finishes
    property bool rests: false
    property int pixelSize: 15
    property int weight: Font.Normal
    property string family: Appearance.font.family.main
    property color color: Appearance.colors.colInkMain
    property color glowColor: Appearance.m3colors.m3onSurface
    property int elide: Text.ElideRight
    readonly property real bandWidth: Math.max(40, base.width * 0.35)
    property real bandX: -bandWidth

    implicitWidth: base.implicitWidth
    implicitHeight: base.implicitHeight

    StyledText {
        id: base
        width: shine.width
        text: shine.text
        elide: shine.elide
        font.pixelSize: shine.pixelSize
        font.weight: shine.weight
        font.family: shine.family
        color: shine.color
    }
    StyledText {
        id: bright
        visible: false
        width: shine.width
        text: shine.text
        elide: shine.elide
        font.pixelSize: shine.pixelSize
        font.weight: shine.weight
        font.family: shine.family
        color: shine.glowColor
    }
    LinearGradient {
        id: band
        visible: false
        width: base.width
        height: base.height
        // outside start..end the gradient holds its edge colours, so the band enters and leaves clean
        start: Qt.point(shine.bandX, 0)
        end: Qt.point(shine.bandX + shine.bandWidth, 0)
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: "white" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    OpacityMask {
        visible: shine.active
        width: base.width
        height: base.height
        source: bright
        maskSource: band
    }
    NumberAnimation on bandX {
        running: shine.active && (!shine.rests || Appearance.agentsMoving)
        loops: Animation.Infinite
        alwaysRunToEnd: true
        from: -shine.bandWidth
        to: base.width + shine.bandWidth * 0.2
        duration: 1500
        easing.type: Easing.InOutQuad
    }
}
