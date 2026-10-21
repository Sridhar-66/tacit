import qs.modules.common
import qs.modules.common.widgets
import qs.modules.tacit.capture
import QtQuick

Item {
    id: root
    required property real regionX
    required property real regionY
    required property real regionWidth
    required property real regionHeight
    required property real mouseX
    required property real mouseY
    required property color color
    required property color overlayColor
    property bool showAimLines: Config.options.regionSelector.rect.showAimLines

    // a recording runs: only its frame stays, a red hairline with two corners, outside the box so not in the video
    property bool breathingBorderOnly: false
    readonly property color recordRed: "#e8705e"

    // The dimmed screen, with a hole where the picture stays lit
    property rect lit: Qt.rect(root.regionX, root.regionY, root.regionWidth, root.regionHeight)
    property real litRadius: 0
    property bool animateLit: false

    ScrimHole {
        z: 1
        anchors.fill: parent
        visible: !root.breathingBorderOnly
        color: root.overlayColor
        hole: root.lit
        radius: root.litRadius
        animate: root.animateLit
    }

    // One solid hairline just outside the selection, in the text colour
    Rectangle {
        id: selectionBorder
        z: 9
        visible: root.regionWidth > 0 && root.regionHeight > 0
        x: Math.round(root.regionX) - 1
        y: Math.round(root.regionY) - 1
        width: Math.round(root.regionWidth) + 2
        height: Math.round(root.regionHeight) + 2
        color: "transparent"
        border.width: 1
        border.color: root.breathingBorderOnly ? Qt.alpha(root.recordRed, 0.7) : root.color
        opacity: 0.9

        // the recording's corners: top left and bottom right, 14 px, 2 px thick, just outside the hairline
        Repeater {
            model: root.breathingBorderOnly ? [0, 1] : []
            Item {
                required property int modelData
                x: modelData === 0 ? -2 : selectionBorder.width - 12
                y: modelData === 0 ? -2 : selectionBorder.height - 12
                width: 14
                height: 14
                Rectangle {
                    y: modelData === 0 ? 0 : 12
                    width: 14
                    height: 2
                    color: root.recordRed
                }
                Rectangle {
                    x: modelData === 0 ? 0 : 12
                    width: 2
                    height: 14
                    color: root.recordRed
                }
            }
        }
    }

    // Coord lines
    Rectangle { // Vertical
        visible: root.showAimLines && !root.breathingBorderOnly
        opacity: 0.2
        z: 2
        x: root.mouseX
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        width: 1
        color: root.color
    }
    Rectangle { // Horizontal
        visible: root.showAimLines && !root.breathingBorderOnly
        opacity: 0.2
        z: 2
        y: root.mouseY
        anchors {
            left: parent.left
            right: parent.right
        }
        height: 1
        color: root.color
    }
}
