import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// One quiet control of the title row: a Tacit glyph in secondary ink on the row wash (hover 0.90, pressed
// 0.78, as everywhere), 32 px to hit, a plain-words tooltip. `on` is a toggle that is switched on (filled glyph).
Item {
    id: b
    property string glyph: ""
    property string tip: ""
    property bool on: false
    property bool live: true       // false: nothing to do here (the first file's Previous)
    property bool forceTip: false  // stills of the hover and its tooltip
    readonly property alias hovered: ma.containsMouse
    signal clicked()
    width: 32
    height: 32
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verysmall
        color: !b.live ? "transparent"
             : ma.pressed ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.78)
             : ma.containsMouse || b.forceTip ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.90)
             : b.on ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.92) : "transparent"
    }
    VGlyph {
        anchors.centerIn: parent
        text: b.glyph
        iconSize: 20
        fill: b.on ? 1 : 0
        ink: b.live ? (b.on ? 0 : 1) : 3
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: b.live
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
    StyledToolTip {
        text: b.tip
        extraVisibleCondition: ma.containsMouse && b.tip.length > 0
        alternativeVisibleCondition: b.forceTip
        x: (b.width - width) / 2
        y: b.height + 4
    }
}
