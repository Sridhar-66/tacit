import QtQuick
import qs.modules.common

// The folder as one row of marks: a mark per file, its width says what the file is, the framed one stands taller.
Item {
    id: root
    required property var v
    readonly property var widths: ({ image: 28, pdf: 16, video: 36, audio: 16, file: 16 })
    readonly property int n: v.entries.length
    readonly property bool few: n <= 24
    // past 24 files the marks shrink to 4 px and a window of 61 follows the roll
    readonly property int lo: few ? 0 : Math.max(0, Math.min(n - 61, Math.round(v.pos) - 30))
    readonly property int hi: few ? n : Math.min(n, lo + 61)
    height: 22
    width: row.width
    Row {
        id: row
        spacing: root.few ? 10 : 3
        Repeater {
            model: root.hi - root.lo
            Item {
                required property int index
                readonly property int i: root.lo + index
                readonly property real w: Math.max(0, 1 - Math.abs(i - root.v.pos))
                width: root.few ? (root.widths[root.v.entries[i]?.kind] ?? 16) : 4
                height: root.height
                Rectangle {
                    width: parent.width
                    height: 10 + 8 * parent.w
                    y: root.height - height
                    radius: 3
                    color: Qt.tint(Appearance.colors.colInkFaint, Qt.rgba(Appearance.colors.colInkMain.r, Appearance.colors.colInkMain.g, Appearance.colors.colInkMain.b, parent.w))
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.v.goTo(parent.i) }
            }
        }
    }
}
