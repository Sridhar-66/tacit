import QtQuick
import qs.modules.common
import qs.modules.common.functions

// A way out in the strip: drawn 24 tall, its target the strip's full height and a little either side. The way forward
// has the one ring; the other way out is quiet. No glyphs.
Item {
    id: pill
    property string text
    property bool ring: false
    property var action: null
    implicitWidth: words.implicitWidth + 24
    implicitHeight: 24
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: area.containsMouse ? ColorUtils.transparentize(Tacit.inkMain, area.pressed ? 0.84 : 0.92) : "transparent"
        border.width: pill.ring ? 1 : 0
        border.color: ColorUtils.transparentize(Tacit.inkMain, 0.55)
    }
    StripWords {
        id: words
        anchors.centerIn: parent
        text: pill.text
        point: pill.ring
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        anchors.topMargin: -5
        anchors.bottomMargin: -5
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.action?.()
    }
}
