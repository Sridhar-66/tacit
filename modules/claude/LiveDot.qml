import QtQuick
import qs.modules.common

// Something working, as Tacit marks it everywhere (the rail, the side panel, the conversation): a
// sand dot that breathes while the work moves (Appearance.agentsMoving) and holds still otherwise.
// Stopped mid-breath it finishes the breath, so it always rests at full colour.
Rectangle {
    id: dot
    property bool breathing: true
    width: 8
    height: 8
    radius: 4
    color: Appearance.colors.colPrimary
    SequentialAnimation on opacity {
        running: dot.visible && dot.breathing && Appearance.agentsMoving
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.35; duration: 1300; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 1300; easing.type: Easing.InOutSine }
    }
}
