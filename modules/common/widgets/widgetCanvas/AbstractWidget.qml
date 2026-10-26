import QtQuick
import Quickshell
import qs.modules.common

/*
 * Widget to be placed on a WidgetCanvas
 */
MouseArea {
    id: root
    property alias animateXPos: xBehavior.enabled
    property alias animateYPos: yBehavior.enabled
    property bool draggable: true
    property int gridSize: 12
    property bool snapEnabled: true
    property real snapAssistSpeed: 0.35
    readonly property bool dragging: drag.active
    property point allowedDragPosition: Qt.point(0, 0)
    property point lastPointerPosition: Qt.point(0, 0)
    property double lastPointerTime: 0

    property bool selected: false
    property bool groupDragActive: false

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    drag.target: draggable ? dragProxy : undefined
    cursorShape: (draggable && containsPress) ? Qt.ClosedHandCursor : draggable ? Qt.OpenHandCursor : Qt.ArrowCursor

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked
        } else if (mouse.modifiers & Qt.ControlModifier) {
            root.selected = !root.selected
        } else {
            var canvas = findCanvas(root.parent)
            if (canvas) canvas.clearSelection()
            root.selected = true
        }
    }

    function center() {
        root.x = (root.parent.width - root.width) / 2
        root.y = (root.parent.height - root.height) / 2
    }

    function snap(value) {
        return Math.round(value / root.gridSize) * root.gridSize
    }

    function findCanvas(item) {
        var p = item
        while (p) {
            if (p.isWidgetCanvas === true) return p
            p = p.parent
        }
        return null
    }

    function updateDragFeedback() {
        var canvas = findCanvas(root.parent)
        if (!canvas) return
        var topLeft = root.mapToItem(canvas, 0, 0)
        var bottomRight = root.mapToItem(canvas, root.width, root.height)
        canvas.setDragRect(Qt.rect(topLeft.x, topLeft.y,
            bottomRight.x - topLeft.x, bottomRight.y - topLeft.y))
    }

    function updateDragPosition() {
        if (!root.dragging) return
        const now = Date.now()
        const elapsed = now - root.lastPointerTime
        const pointerX = dragProxy.x
        const pointerY = dragProxy.y
        const dx = pointerX - root.lastPointerPosition.x
        const dy = pointerY - root.lastPointerPosition.y
        const speed = elapsed > 0 ? Math.sqrt(dx * dx + dy * dy) / elapsed : Infinity
        root.lastPointerPosition = Qt.point(pointerX, pointerY)
        root.lastPointerTime = now

        let targetX = pointerX
        let targetY = pointerY
        if (root.snapEnabled && speed <= root.snapAssistSpeed) {
            targetX = root.snap(targetX)
            targetY = root.snap(targetY)
        }

        const canvas = findCanvas(root.parent)
        if (canvas) {
            const resolved = canvas.resolveDragPosition(root, targetX, targetY)
            root.allowedDragPosition = resolved
        } else {
            root.allowedDragPosition = Qt.point(targetX, targetY)
        }
        root.updateDragFeedback()
    }

    function commitPosition() {}

    Component.onCompleted: {
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.registerWidget(root)
    }

    Component.onDestruction: {
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.unregisterWidget(root)
    }

    Item {
        id: dragProxy
        parent: root.parent
        x: root.x
        y: root.y

    }

    FrameAnimation {
        running: root.dragging
        onTriggered: root.updateDragPosition()
    }

    Binding {
        target: root
        property: "x"
        value: root.allowedDragPosition.x
        when: root.dragging
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "y"
        value: root.allowedDragPosition.y
        when: root.dragging
        restoreMode: Binding.RestoreNone
    }

    onXChanged: {
        if (!root.dragging) return
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.updateGroupDrag(root)
    }
    onYChanged: {
        if (!root.dragging) return
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.updateGroupDrag(root)
    }

    onDraggingChanged: {
        var canvas = findCanvas(root.parent)
        if (canvas) canvas.setDragging(dragging)

        if (dragging) {
            if (canvas) canvas.beginGroupDrag(root)
            root.allowedDragPosition = Qt.point(root.x, root.y)
            root.lastPointerPosition = Qt.point(dragProxy.x, dragProxy.y)
            root.lastPointerTime = Date.now()
            root.updateDragFeedback()
        } else {
            var snappedX = root.snapEnabled ? root.snap(root.x) : root.x
            var snappedY = root.snapEnabled ? root.snap(root.y) : root.y
            if (canvas) {
                var resolved = canvas.resolveDragPosition(root, snappedX, snappedY)
                snappedX = resolved.x
                snappedY = resolved.y
            }
            var snapDeltaX = snappedX - root.x
            var snapDeltaY = snappedY - root.y
            var settlingGroup = canvas && canvas.groupDragMemberStarts.length > 0
            if (settlingGroup) root.groupDragActive = true
            root.x = snappedX
            root.y = snappedY
            if (canvas) canvas.endGroupDrag(snapDeltaX, snapDeltaY)
            if (settlingGroup) root.groupDragActive = false
            root.commitPosition()
        }

        dragProxy.x = root.x
        dragProxy.y = root.y
    }

    Rectangle {
        anchors.fill: parent
        visible: root.selected
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colPrimary
        radius: Appearance.rounding?.verylarge ?? 30
        z: 9999
    }

    Behavior on x {
        id: xBehavior
        enabled: !root.dragging && !root.groupDragActive
        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
    }
    Behavior on y {
        id: yBehavior
        enabled: !root.dragging && !root.groupDragActive
        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
    }
}