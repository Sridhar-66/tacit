import QtQuick
import qs.modules.common

// The whole document down the right edge: matches as ticks, the part on screen as a bracket.
Item {
    id: root
    required property var v
    width: 10
    Rectangle { x: 4; width: 1; height: parent.height; color: Appearance.colors.colInkDivider }
    Repeater {
        model: root.v.pdfMarks
        Rectangle {
            required property real modelData
            width: 9
            height: 2
            radius: 1
            y: modelData * root.height
            color: root.v.hit
            opacity: 0.9
        }
    }
    Rectangle {
        x: -3
        y: root.v.pdfTop * root.height
        width: 16
        height: Math.max(14, root.v.pdfSpan * root.height)
        radius: 3
        color: "transparent"
        border.width: 1.5
        border.color: Appearance.colors.colInkMain
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.v.pdfGoToFraction((m.y + 8) / root.height)
        onPositionChanged: m => { if (pressed) root.v.pdfGoToFraction((m.y + 8) / root.height); }
    }
}
