import QtQuick

// The horizon (scripts/setup/render-horizons.py): one render per step, each a little more lit; a new step
// fades in over the last instead of jumping.
Item {
    id: g
    property int step: 1
    property bool lessMotion: false
    property bool showingA: true
    onStepChanged: {
        const next = Qt.resolvedUrl(`../../assets/setup/horizon-${Math.max(1, Math.min(7, step))}.jpg`);
        if (showingA) { b.source = next; } else { a.source = next; }
        showingA = !showingA;
    }
    Image { id: a; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: Qt.resolvedUrl("../../assets/setup/horizon-1.jpg")
        opacity: g.showingA ? 1 : 0; Behavior on opacity { NumberAnimation { duration: g.lessMotion ? 300 : 1400; easing.type: Easing.InOutSine } } }
    Image { id: b; anchors.fill: parent; fillMode: Image.PreserveAspectCrop
        opacity: g.showingA ? 0 : 1; Behavior on opacity { NumberAnimation { duration: g.lessMotion ? 300 : 1400; easing.type: Easing.InOutSine } } }
}
