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

    property bool breathingBorderOnly: false

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
        border.color: root.color

        // Breathing
        opacity: 0.9
        SequentialAnimation on opacity {
            running: root.breathingBorderOnly
            loops: Animation.Infinite
            NumberAnimation { from: 0.9; to: 0.3; duration: 1200; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.3; to: 0.9; duration: 1200; easing.type: Easing.InOutQuad }
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
