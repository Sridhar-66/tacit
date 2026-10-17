import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.tacit

/**
 * One level of the side panel's trail (AgentsPane): a page that slides in from the side it is
 * reached from, keeps its scroll and folds in its trail entry, and slides out and is destroyed when
 * the trail leaves it. A page puts its content in `body` and sets `bodyHeight`.
 */
Item {
    id: page
    property var pane: null
    property var entry: ({ f: {} })
    default property alias body: content.data
    property alias over: overSlot.data    // over the scrolling body (a pill held at the foot)
    property real bodyHeight: 0
    readonly property alias flick: flick
    // you are moving the page (wheel, pad, drag, flick, the scrollbar), not the page growing
    readonly property bool userMoving: flick.moving || flick.dragging || glide.active || bar.pressed
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // the trail keeps where you were: the scroll here, the folds in entry.f
    function begin() {}               // the entry is in place
    function save() { page.entry.y = flick.contentY; }
    // the rows lay out after the page is made: the kept place is applied as the content grows, until
    // it fits, you scroll, or a second has passed
    property real wantY: -1
    function restore() { page.wantY = page.entry.y ?? 0; page.settle(); settleEnd.restart(); }
    function settle() {
        if (page.wantY < 0) return;
        flick.contentY = Math.max(0, Math.min(page.wantY, flick.contentHeight - flick.height));
        if (flick.contentHeight - flick.height >= page.wantY) page.wantY = -1;
    }
    Timer { id: settleEnd; interval: 1000; onTriggered: page.wantY = -1 }
    function leave(dir) {
        page.enabled = false;
        page.x = dir > 0 ? -16 : 16;
        page.opacity = 0;
        gone.start();
    }
    Timer { id: gone; interval: 240; onTriggered: page.destroy() }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: page.bodyHeight + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentHeightChanged: page.settle()
        onMovementStarted: page.wantY = -1
        ScrollBar.vertical: StyledScrollBar { id: bar }
        GlideWheel { id: glide; view: flick; gain: 1.6; gainPerSpeed: 3; gainMax: 6 }
        Item {
            id: content
            x: 20
            y: 4
            // a reading column: a wide panel leaves room at the right instead of pulling a row's name
            // and its time apart
            width: Math.min(flick.width - 40, 640)
            height: page.bodyHeight
        }
    }
    Item { id: overSlot; anchors.fill: parent; z: 2 }
    // once the page is scrolled, a hairline where it passes under the crumbs
    Rectangle {
        z: 3
        width: parent.width
        height: 1
        color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.9)
        opacity: flick.contentY > 2 && (page.pane?.trail?.length ?? 1) < 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }
}
