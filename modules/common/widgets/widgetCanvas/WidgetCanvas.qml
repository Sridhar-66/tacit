import QtQuick
import qs.modules.common

MouseArea {
    id: root
    property int gridSize: 12
    property bool showGrid: false
    readonly property bool isWidgetCanvas: true
    readonly property bool gridVisible: showGrid && Config.options.background.showGrid
    property rect dragRect: Qt.rect(0, 0, 0, 0)

    property var registeredWidgets: []
    property bool selecting: false
    property point selectionStartPoint: Qt.point(0, 0)
    property rect selectionRect: Qt.rect(0, 0, 0, 0)

    property var groupDragMemberStarts: []
    property real groupDragStartX: 0
    property real groupDragStartY: 0
    property var dragCollisionMovers: []
    property var dragCollisionObstacles: []
    property point dragCollisionOrigin: Qt.point(0, 0)
    property point dragCollisionOriginCanvas: Qt.point(0, 0)
    property real dragCollisionInitialOverlap: 0

    function setDragging(active) {
        root.showGrid = active
        if (!active)
            root.dragRect = Qt.rect(0, 0, 0, 0)
    }

    function setDragRect(rect) {
        root.dragRect = rect
    }

    function registerWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.concat([widget])
    }

    function unregisterWidget(widget) {
        root.registeredWidgets = root.registeredWidgets.filter(w => w !== widget)
    }

    function clearSelection() {
        for (const widget of root.registeredWidgets) widget.selected = false
    }

    function rectsIntersect(a, b) {
        return a.x < b.x + b.width && a.x + a.width > b.x
            && a.y < b.y + b.height && a.y + a.height > b.y
    }

    function overlapAreaAt(x, y, width, height, other) {
        width = Math.max(0, Math.min(x + width, other.x + other.width) - Math.max(x, other.x))
        height = Math.max(0, Math.min(y + height, other.y + other.height) - Math.max(y, other.y))
        return width * height
    }

    function widgetRect(widget, x = widget.x, y = widget.y) {
        const topLeft = widget.parent.mapToItem(root, x, y)
        const bottomRight = widget.parent.mapToItem(root, x + widget.width, y + widget.height)
        return Qt.rect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y)
    }

    function groupOverlapArea(dx, dy) {
        let total = 0
        for (const mover of root.dragCollisionMovers) {
            const candidateX = mover.rect.x + dx
            const candidateY = mover.rect.y + dy
            for (const obstacle of root.dragCollisionObstacles)
                total += root.overlapAreaAt(candidateX, candidateY,
                    mover.rect.width, mover.rect.height, obstacle)
        }
        return total
    }

    function resolveDragPosition(widget, targetX, targetY) {
        const localDX = targetX - root.dragCollisionOrigin.x
        const localDY = targetY - root.dragCollisionOrigin.y
        const targetCanvas = widget.parent.mapToItem(root, targetX, targetY)
        const dx = targetCanvas.x - root.dragCollisionOriginCanvas.x
        const dy = targetCanvas.y - root.dragCollisionOriginCanvas.y
        const targetOverlap = root.groupOverlapArea(dx, dy)
        if (targetOverlap <= root.dragCollisionInitialOverlap + 0.01)
            return Qt.point(targetX, targetY)

        let low = 0
        let high = 1
        for (let i = 0; i < 8; i++) {
            const middle = (low + high) / 2
            if (root.groupOverlapArea(dx * middle, dy * middle) <= root.dragCollisionInitialOverlap + 0.01)
                low = middle
            else
                high = middle
        }
        return Qt.point(root.dragCollisionOrigin.x + localDX * low,
            root.dragCollisionOrigin.y + localDY * low)
    }

    function selectWithinRect(rect) {
        for (const widget of root.registeredWidgets) {
            widget.selected = root.rectsIntersect(rect, root.widgetRect(widget))
        }
    }

    function beginGroupDrag(initiator) {
        if (!initiator.selected) {
            root.groupDragMemberStarts = []
        } else {
            root.groupDragStartX = initiator.x
            root.groupDragStartY = initiator.y
            root.groupDragMemberStarts = root.registeredWidgets
                .filter(w => w.selected && w !== initiator)
                .map(w => ({ widget: w, startX: w.x, startY: w.y }))
            for (const entry of root.groupDragMemberStarts) entry.widget.groupDragActive = true
        }
        const movers = [initiator, ...root.groupDragMemberStarts.map(entry => entry.widget)]
        root.dragCollisionOrigin = Qt.point(initiator.x, initiator.y)
        root.dragCollisionOriginCanvas = initiator.parent.mapToItem(root, initiator.x, initiator.y)
        root.dragCollisionMovers = movers.map(widget => ({ widget, rect: root.widgetRect(widget) }))
        root.dragCollisionObstacles = root.registeredWidgets
            .filter(widget => !movers.includes(widget))
            .map(widget => root.widgetRect(widget))
        root.dragCollisionInitialOverlap = root.groupOverlapArea(0, 0)
    }

    function updateGroupDrag(initiator) {
        if (root.groupDragMemberStarts.length === 0) return
        const dx = initiator.x - root.groupDragStartX
        const dy = initiator.y - root.groupDragStartY
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.x = entry.startX + dx
            entry.widget.y = entry.startY + dy
        }
    }

    function endGroupDrag(snapDeltaX, snapDeltaY) {
        for (const entry of root.groupDragMemberStarts) {
            entry.widget.x += snapDeltaX
            entry.widget.y += snapDeltaY
            entry.widget.groupDragActive = false
            entry.widget.commitPosition()
        }
        root.groupDragMemberStarts = []
        root.dragCollisionMovers = []
        root.dragCollisionObstacles = []
    }

    onPressed: (mouse) => {
        if (Config.options.background.widgetsLocked) return
        root.selecting = true
        root.selectionStartPoint = Qt.point(mouse.x, mouse.y)
        root.selectionRect = Qt.rect(mouse.x, mouse.y, 0, 0)
        if (!(mouse.modifiers & Qt.ControlModifier)) root.clearSelection()
    }

    onPositionChanged: (mouse) => {
        if (!root.selecting) return
        const startX = root.selectionStartPoint.x
        const startY = root.selectionStartPoint.y
        const rectX = Math.min(startX, mouse.x)
        const rectY = Math.min(startY, mouse.y)
        const rectW = Math.abs(mouse.x - startX)
        const rectH = Math.abs(mouse.y - startY)
        root.selectionRect = Qt.rect(rectX, rectY, rectW, rectH)
        root.selectWithinRect(root.selectionRect)
    }

    onReleased: {
        root.selecting = false
    }

    Canvas {
        id: baseGrid
        anchors.fill: parent
        visible: root.gridVisible
        property color dotColor: Appearance.m3colors.m3onBackground

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        onDotColorChanged: requestPaint()

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.fillStyle = dotColor
            context.globalAlpha = 0.24

            for (let x = 0; x <= width; x += root.gridSize) {
                for (let y = 0; y <= height; y += root.gridSize) {
                    context.beginPath()
                    context.arc(x, y, 1.15, 0, Math.PI * 2)
                    context.fill()
                }
            }
        }
    }

    Canvas {
        id: nearbyGrid
        readonly property real margin: root.gridSize * 2
        readonly property real leftEdge: Math.max(0, root.dragRect.x - margin)
        readonly property real topEdge: Math.max(0, root.dragRect.y - margin)
        readonly property real rightEdge: Math.min(root.width, root.dragRect.x + root.dragRect.width + margin)
        readonly property real bottomEdge: Math.min(root.height, root.dragRect.y + root.dragRect.height + margin)
        property color dotColor: Appearance.m3colors.m3onBackground

        x: leftEdge
        y: topEdge
        width: Math.max(0, rightEdge - leftEdge)
        height: Math.max(0, bottomEdge - topEdge)
        visible: root.gridVisible && Config.options.background.showSnapLines
            && root.dragRect.width > 0 && root.dragRect.height > 0

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onXChanged: requestPaint()
        onYChanged: requestPaint()
        onVisibleChanged: requestPaint()
        onDotColorChanged: requestPaint()

        onPaint: {
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.fillStyle = dotColor
            const size = root.gridSize
            const glowRadius = nearbyGrid.margin
            const startX = Math.ceil(x / size) * size - x
            const startY = Math.ceil(y / size) * size - y

            for (let localX = startX; localX <= width; localX += size) {
                for (let localY = startY; localY <= height; localY += size) {
                    const dotX = x + localX
                    const dotY = y + localY
                    const dx = Math.max(root.dragRect.x - dotX, 0, dotX - root.dragRect.x - root.dragRect.width)
                    const dy = Math.max(root.dragRect.y - dotY, 0, dotY - root.dragRect.y - root.dragRect.height)
                    const progress = Math.min(1, Math.sqrt(dx * dx + dy * dy) / glowRadius)
                    const falloff = 1 - progress * progress * (3 - 2 * progress)
                    context.globalAlpha = 0.25 + 0.45 * falloff
                    context.beginPath()
                    context.arc(localX, localY, 1 + 0.5 * falloff, 0, Math.PI * 2)
                    context.fill()
                }
            }
        }
    }

    Connections {
        target: root
        function onGridSizeChanged() {
            baseGrid.requestPaint()
            nearbyGrid.requestPaint()
        }
        function onDragRectChanged() { nearbyGrid.requestPaint() }
    }

    Rectangle {
        id: selectionRectVisual
        visible: root.selecting
        x: root.selectionRect.x
        y: root.selectionRect.y
        width: root.selectionRect.width
        height: root.selectionRect.height
        color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.15)
        border.width: 1
        border.color: Appearance.colors.colPrimary
        z: 9999
    }

}