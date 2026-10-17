import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The document as a row of small pages, the open one filled; under each the matches stand as amber bars.
Item {
    id: root
    required property var v
    readonly property int n: v.pdfPages
    readonly property real tw: Math.min(22, Math.max(2, width * 0.6 / Math.max(1, n)))
    height: 56
    Repeater {
        model: root.n
        Item {
            required property int index
            readonly property bool cur: index === root.v.pdfPage
            readonly property int hits: root.v.pdfCounts[index] ?? 0
            x: root.n > 1 ? index * (root.width - root.tw) / (root.n - 1) : 0
            width: root.tw
            height: root.height
            Rectangle {
                width: parent.width
                height: 30
                radius: 3
                color: parent.cur ? Appearance.colors.colInkMain : "transparent"
                border.width: parent.cur ? 0 : 1.5
                border.color: Appearance.colors.colInkFaint
                Behavior on color { CAnim {} }
            }
            Rectangle {
                visible: parent.hits > 0
                y: 36
                width: parent.width
                height: Math.max(2, Math.min(14, parent.hits / 22 * 14))
                radius: 2
                color: root.v.hit
                opacity: parent.cur ? 1 : 0.7
            }
            MouseArea { anchors.fill: parent; anchors.margins: -3; cursorShape: Qt.PointingHandCursor; onClicked: root.v.pdfGoTo(parent.index) }
        }
    }
}
