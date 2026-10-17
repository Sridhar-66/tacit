import QtQuick
import qs.modules.common.widgets

// The way forward: a ring of the horizon's light. Focus and hover lift it with a faint neutral fill; the ring stays as it is.
Item {
    id: a
    property string text
    property bool later: false
    signal clicked()
    width: Math.max(Look.px(240), at.width + Look.px(80))
    height: Look.px(58)
    activeFocusOnTab: !later
    Keys.onReturnPressed: if (!later) clicked()
    Keys.onEnterPressed: if (!later) clicked()
    Keys.onSpacePressed: if (!later) clicked()
    scale: ma.pressed && !later ? 0.97 : 1
    Behavior on scale { Anim { type: Anim.FastEffects } }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: a.later ? "transparent" : Qt.rgba(1, 1, 1, a.activeFocus ? 0.08 : ma.containsMouse ? 0.05 : 0)
        border.width: 1.5
        border.color: a.later ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0.95, 0.77, 0.60, 0.75)
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    T { id: at; anchors.centerIn: parent; text: a.text; font.pixelSize: Look.fs(19); font.weight: Font.Medium; color: a.later ? Look.meta : Look.main }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: a.later ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: if (!a.later) a.clicked() }
}
