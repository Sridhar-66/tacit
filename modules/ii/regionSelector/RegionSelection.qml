pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.tacit.capture
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "quickshell:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Modes
    enum SnipAction { Copy, Edit, Search, CharRecognition, Record, RecordWithSound, Claude } 
    enum SelectionMode { RectCorners, Circle }
    enum Phase { Select, Post }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    property var phase: RegionSelection.Phase.Select
    signal dismiss()

    // Styles
    property string screenshotDir: Directories.screenshotTemp
    // The dim, the outlines and the strip's ground come from Tacit's surfaces: the scrim the
    // password request dims with, the selection's hairline in the text colour, the targeted
    // window's ring in the overview's target colour (colSecondary), a near-opaque ground under text.
    property color overlayColor: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.4)
    property color selectionBorderColor: Appearance.colors.colOnLayer0
    property color windowBorderColor: Appearance.colors.colSecondary
    property color quietBorderColor: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)
    property color imageBorderColor: Appearance.colors.colTertiary
    property color stripGround: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.04)
    property real targetRegionOpacity: Config.options.regionSelector.targetRegions.opacity
    property bool contentRegionOpacity: Config.options.regionSelector.targetRegions.contentRegionOpacity

    // Vars for indicators
    readonly property var windows: [...HyprlandData.windowList].sort((a, b) => {
        // Sort floating=true windows before others
        if (a.floating === b.floating) return 0;
        return a.floating ? -1 : 1;
    })
    readonly property var layers: HyprlandData.layers
    readonly property real falsePositivePreventionRatio: 0.5

    // Screen & interaction vars
    readonly property var monitor: WM.monitorFor(screen)
    readonly property var monitorGeometry: WM.monitorGeometry(screen)
    readonly property real monitorScale: monitorGeometry.scale
    readonly property real monitorOffsetX: monitorGeometry.x
    readonly property real monitorOffsetY: monitorGeometry.y
    property int activeWorkspaceId: WM.activeWorkspaceForMonitor(root.monitor?.name)?.id ?? 0
    // Unique per selection: an OCR or search capture reads its file for seconds after the
    // selector is gone, so the next capture must not write over it.
    readonly property string screenshotNonce: `${Date.now()}`
    property string screenshotPath: `${root.screenshotDir}/image-${screen.name}-${root.screenshotNonce}`
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property real dragDiffX: 0
    property real dragDiffY: 0
    property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)
    property bool dragging: false
    property list<point> points: []
    property var mouseButton: null
    property var imageRegions: []
    readonly property var windowsHere: root.windows.filter(w => w.workspace.id === root.activeWorkspaceId)
    readonly property list<var> windowRegions: (root.enableLayerRegions //
        ? RegionFunctions.filterWindowRegionsByLayers(root.windowsHere, root.layerRegions)
        : root.windowsHere
    ).map(window => {
        return {
            at: [window.at[0] - root.monitorOffsetX, window.at[1] - root.monitorOffsetY],
            size: [window.size[0], window.size[1]],
            class: window.class,
            title: window.title,
        }
    })
    // Layer surfaces whose box says nothing about what they paint: the island's surface spans the
    // top third of the screen, the frame and the corners hug the edges. Left in, they outline empty
    // space and, through filterWindowRegionsByLayers, delete every window underneath.
    readonly property list<string> ignoredLayerNamespaces: [":bar", ":verticalBar", ":dock", //
        ":island", ":screenframe", ":screenCorners", ":regionSelector"]
    readonly property list<var> layerRegions: {
        const layersOfThisMonitor = root.layers[root.monitor?.name]
        const topLayers = layersOfThisMonitor?.levels["2"]
        if (!topLayers) return [];
        const nonBarTopLayers = topLayers
            .filter(layer => layer.namespace !== "quickshell" // The shell's 1x1 anchor surface
                && !root.ignoredLayerNamespaces.some(namespace => layer.namespace.includes(namespace)))
            .map(layer => {
            return {
                at: [layer.x, layer.y],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }
        })
        const offsetAdjustedLayers = nonBarTopLayers.map(layer => {
            return {
                at: [layer.at[0] - root.monitorOffsetX, layer.at[1] - root.monitorOffsetY],
                size: layer.size,
                namespace: layer.namespace,
            }
        });
        return offsetAdjustedLayers;
    }

    // Config
    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    property bool enableWindowRegions: Config.options.regionSelector.targetRegions.windows && !isCircleSelection
    property bool enableLayerRegions: Config.options.regionSelector.targetRegions.layers && !isCircleSelection
    property bool enableContentRegions: Config.options.regionSelector.targetRegions.content

    // Target
    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0
    function targetedRegionValid() {
        return (root.targetedRegionX >= 0 && root.targetedRegionY >= 0)
    }
    function setRegionToTargeted() {
        const padding = Config.options.regionSelector.targetRegions.selectionPadding; // Make borders not cut off n stuff
        root.regionX = root.targetedRegionX - padding;
        root.regionY = root.targetedRegionY - padding;
        root.regionWidth = root.targetedRegionWidth + padding * 2;
        root.regionHeight = root.targetedRegionHeight + padding * 2;
    }

    function regionAt(regions, x, y) {
        return regions.find(region => {
            return region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        });
    }

    // Each kind is only consulted when its outlines are drawn, or a click would snap to a
    // rectangle the user was never shown.
    function updateTargetedRegion(x, y) {
        // Image regions
        const clickedRegion = root.enableContentRegions ? root.regionAt(root.imageRegions, x, y) : undefined;
        if (clickedRegion) {
            root.targetedRegionX = clickedRegion.at[0];
            root.targetedRegionY = clickedRegion.at[1];
            root.targetedRegionWidth = clickedRegion.size[0];
            root.targetedRegionHeight = clickedRegion.size[1];
            return;
        }

        // Layer regions
        const clickedLayer = root.enableLayerRegions ? root.regionAt(root.layerRegions, x, y) : undefined;
        if (clickedLayer) {
            root.targetedRegionX = clickedLayer.at[0];
            root.targetedRegionY = clickedLayer.at[1];
            root.targetedRegionWidth = clickedLayer.size[0];
            root.targetedRegionHeight = clickedLayer.size[1];
            return;
        }

        // Window regions
        const clickedWindow = root.enableWindowRegions ? root.regionAt(root.windowRegions, x, y) : undefined;
        if (clickedWindow) {
            root.targetedRegionX = clickedWindow.at[0];
            root.targetedRegionY = clickedWindow.at[1];
            root.targetedRegionWidth = clickedWindow.size[0];
            root.targetedRegionHeight = clickedWindow.size[1];
            return;
        }

        root.targetedRegionX = -1;
        root.targetedRegionY = -1;
        root.targetedRegionWidth = 0;
        root.targetedRegionHeight = 0;
    }

    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)
    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)

    // What the notch strip says.
    readonly property string stripVerb: root.isCircleSelection ? "Draw" : "Drag"
    readonly property string stripGlyph: switch (root.action) {
    case RegionSelection.SnipAction.Copy:
    case RegionSelection.SnipAction.Edit:
        return "content_cut";
    case RegionSelection.SnipAction.Search:
        return "image_search";
    case RegionSelection.SnipAction.CharRecognition:
        return "document_scanner";
    case RegionSelection.SnipAction.Record:
    case RegionSelection.SnipAction.RecordWithSound:
        return "videocam";
    case RegionSelection.SnipAction.Claude:
        return "chat";
    default:
        return "";
    }
    readonly property string stripHint: switch (root.action) {
    case RegionSelection.SnipAction.Copy:
    case RegionSelection.SnipAction.Edit:
        return `${root.stripVerb} to copy, right-${root.stripVerb.toLowerCase()} to annotate`;
    case RegionSelection.SnipAction.Search:
        return `${root.stripVerb} to search with Google Lens`;
    case RegionSelection.SnipAction.CharRecognition:
        return `${root.stripVerb} over text to copy it`;
    case RegionSelection.SnipAction.Record:
        return `${root.stripVerb} to record this region`;
    case RegionSelection.SnipAction.RecordWithSound:
        return `${root.stripVerb} to record this region, with sound`;
    case RegionSelection.SnipAction.Claude:
        return `${root.stripVerb} to ask Claude about it`;
    default:
        return "";
    }
    readonly property string stripRelease: switch (root.action) {
    case RegionSelection.SnipAction.Copy:
    case RegionSelection.SnipAction.Edit:
        return root.mouseButton === Qt.RightButton ? "Release to annotate" : "Release to copy";
    case RegionSelection.SnipAction.Search:
        return "Release to search";
    case RegionSelection.SnipAction.CharRecognition:
        return "Release to copy the text";
    case RegionSelection.SnipAction.Record:
    case RegionSelection.SnipAction.RecordWithSound:
        return "Release to start recording";
    case RegionSelection.SnipAction.Claude:
        return "Release to ask Claude";
    default:
        return "";
    }
    // A drag's box; a bare press shows the box it would snap to. A circle has no box until release.
    readonly property string stripSize: {
        if (root.isCircleSelection) return "";
        const sized = root.draggedAway ? [root.regionWidth, root.regionHeight]
            : (root.targetedRegionValid() ? [root.targetedRegionWidth, root.targetedRegionHeight] : null);
        return sized ? `${Math.round(sized[0])} × ${Math.round(sized[1])}` : "";
    }
    // The dim's hole: the selection while one is drawn, else the window or region the pointer is over.
    readonly property rect litRect: {
        if (root.isCircleSelection) return Qt.rect(0, 0, 0, 0);
        if (root.phase === RegionSelection.Phase.Post || root.draggedAway)
            return Qt.rect(root.regionX, root.regionY, root.regionWidth, root.regionHeight);
        if (root.targetedRegionValid())
            return Qt.rect(root.targetedRegionX, root.targetedRegionY, root.targetedRegionWidth, root.targetedRegionHeight);
        return Qt.rect(0, 0, 0, 0);
    }

    // Screenshot stuff
    TempScreenshotProcess {
        id: screenshotProc
        running: true
        screen: root.screen
        screenshotDir: root.screenshotDir
        screenshotPath: root.screenshotPath
        onExited: (exitCode, exitStatus) => {
            if (root.enableContentRegions) imageDetectionProcess.running = true;
            root.preparationDone = !checkRecordingProc.running;
        }
    }
    property bool isRecording: root.action === RegionSelection.SnipAction.Record || root.action === RegionSelection.SnipAction.RecordWithSound
    property bool recordingShouldStop: false
    Process {
        id: checkRecordingProc
        running: isRecording
        command: ["pidof", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            root.preparationDone = !screenshotProc.running
            root.recordingShouldStop = (exitCode === 0);
        }
    }
    // Only the crop commands read the capture and remove it afterwards. Every other capture -
    // the other monitors', a cancelled selection's, a recording's - is ours to drop, or each
    // selection leaves a full-resolution shot of every monitor behind in /tmp.
    property bool tempCaptureConsumed: false
    Component.onDestruction: {
        if (!root.tempCaptureConsumed) Quickshell.execDetached(["rm", "-f", root.screenshotPath]);
    }

    property bool preparationDone: false
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        if (root.isRecording && root.recordingShouldStop) {
            Quickshell.execDetached([Directories.recordScriptPath]);
            root.dismiss();
            return;
        }
        root.visible = true;
    }

    Connections {
        target: Persistent.states.record
        function onEnableChanged() {
            if (!Persistent.states.record.enable && root.isRecording) {
                root.dismiss();
            }
        }
    }

    Process {
        id: imageDetectionProcess
        command: ["bash", "-c", `${Directories.scriptPath}/images/find-regions-venv.sh ` 
            + `--hyprctl ` 
            + `--image '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' ` 
            + `--max-width ${Math.round(root.screen.width * root.monitorScale * root.falsePositivePreventionRatio)} ` 
            + `--max-height ${Math.round(root.screen.height * root.monitorScale * root.falsePositivePreventionRatio)} `]
        stdout: StdioCollector {
            id: imageDimensionCollector
            onStreamFinished: {
                // The script measures the grim capture, so its boxes are in device pixels while
                // everything drawn here is logical.
                const detected = JSON.parse(imageDimensionCollector.text).map(region => {
                    return {
                        at: [region.at[0] / root.monitorScale, region.at[1] / root.monitorScale],
                        size: [region.size[0] / root.monitorScale, region.size[1] / root.monitorScale],
                    }
                });
                root.imageRegions = RegionFunctions.filterImageRegions(
                    detected,
                    root.windowRegions
                );
            }
        }
    }

    function getScreenshotAction() {
        switch(root.action) {
            case RegionSelection.SnipAction.Copy:
                return ScreenshotAction.Action.Copy;
            case RegionSelection.SnipAction.Edit:
                return ScreenshotAction.Action.Edit;
            case RegionSelection.SnipAction.Search:
                return ScreenshotAction.Action.Search;
            case RegionSelection.SnipAction.CharRecognition:
                return ScreenshotAction.Action.CharRecognition;
            case RegionSelection.SnipAction.Record:
                return ScreenshotAction.Action.Record;
            case RegionSelection.SnipAction.RecordWithSound:
                return ScreenshotAction.Action.RecordWithSound;
            case RegionSelection.SnipAction.Claude:
                return ScreenshotAction.Action.Claude;
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                root.dismiss();
                return;
        }
    }

    // Execution after selection
    function snip() {
        // A click that snapped to no region at all: there is nothing to crop (a 0 in an
        // ImageMagick -crop geometry means "the rest of the image", not "nothing"), and the
        // overlay stays up so a slip costs a click instead of the whole capture. Escape and the
        // Cancel button still close it.
        if (root.regionWidth <= 0 || root.regionHeight <= 0) {
            root.dragging = false;
            root.points = [];
            root.dragDiffX = 0;
            root.dragDiffY = 0;
            return;
        }

        // Clamp region to screen bounds
        root.regionX = Math.max(0, Math.min(root.regionX, root.screen.width - root.regionWidth));
        root.regionY = Math.max(0, Math.min(root.regionY, root.screen.height - root.regionHeight));
        root.regionWidth = Math.max(0, Math.min(root.regionWidth, root.screen.width - root.regionX));
        root.regionHeight = Math.max(0, Math.min(root.regionHeight, root.screen.height - root.regionY));

        // Adjust action
        if (root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Edit) {
            root.action = root.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }
        
        const screenshotDir = Config.options.screenSnip.savePath !== "" ? //
            Config.options.screenSnip.savePath : "";
        var screenshotAction = root.getScreenshotAction();
        const command = ScreenshotAction.getCommand(
            root.regionX * root.monitorScale, //
            root.regionY * root.monitorScale, //
            root.regionWidth * root.monitorScale,// 
            root.regionHeight * root.monitorScale, //
            root.screenshotPath, //
            screenshotAction, //
            screenshotDir
        )
        if (!command) {
            root.dismiss();
            return;
        }
        root.tempCaptureConsumed = !root.isRecording;
        Quickshell.execDetached(command);
        if (root.action == RegionSelection.SnipAction.Record || root.action == RegionSelection.SnipAction.RecordWithSound) {
            root.phase = RegionSelection.Phase.Post
            root.selectionMode = RegionSelection.SelectionMode.RectCorners
        } else {
            root.dismiss();
        }
    }

    // Only clickable in Selection phase
    mask: Region {
        item: switch(root.phase) {
            case RegionSelection.Phase.Select: return mouseArea;
            case RegionSelection.Phase.Post: return null;
        }
    }

    ScreencopyView { // For freezing
        anchors.fill: parent
        live: false
        captureSource: root.screen
        visible: root.phase === RegionSelection.Phase.Select

        focus: root.visible
        Keys.onPressed: (event) => { // Esc to close
            if (event.key === Qt.Key_Escape) {
                Qt.callLater(root.dismiss);
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        // Controls
        onPressed: (mouse) => {
            root.dragStartX = mouse.x;
            root.dragStartY = mouse.y;
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragging = true;
            root.mouseButton = mouse.button;
        }
        onReleased: (mouse) => {
            // Detect if it was a click -> Try to select targeted region
            if (root.draggingX === root.dragStartX && root.draggingY === root.dragStartY) {
                if (root.targetedRegionValid()) {
                    root.setRegionToTargeted();
                }
            }
            // Circle dragging?
            else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                const padding = Config.options.regionSelector.circle.padding + Config.options.regionSelector.circle.strokeWidth / 2;
                const dragPoints = (root.points.length > 0) ? root.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                const maxX = Math.max(...dragPoints.map(p => p.x));
                const minX = Math.min(...dragPoints.map(p => p.x));
                const maxY = Math.max(...dragPoints.map(p => p.y));
                const minY = Math.min(...dragPoints.map(p => p.y));
                root.regionX = minX - padding;
                root.regionY = minY - padding;
                root.regionWidth = maxX - minX + padding * 2;
                root.regionHeight = maxY - minY + padding * 2;
            }
            root.snip();
        }
        onPositionChanged: (mouse) => {
            root.updateTargetedRegion(mouse.x, mouse.y);
            if (!root.dragging) return;
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragDiffX = mouse.x - root.dragStartX;
            root.dragDiffY = mouse.y - root.dragStartY;
            root.points.push({ x: mouse.x, y: mouse.y });
        }
        
        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.RectCorners
            sourceComponent: RectCornersSelectionDetails {
                regionX: root.regionX
                regionY: root.regionY
                regionWidth: root.regionWidth
                regionHeight: root.regionHeight
                mouseX: mouseArea.mouseX
                mouseY: mouseArea.mouseY
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                lit: root.litRect
                litRadius: (root.draggedAway || root.phase === RegionSelection.Phase.Post) ? 0 : Appearance.rounding.windowRounding
                animateLit: !root.draggedAway
                breathingBorderOnly: root.phase === RegionSelection.Phase.Post
            }
        }

        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.Circle
            sourceComponent: CircleSelectionDetails {
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                points: root.points
            }
        }

        // Window regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableWindowRegions) {
                        return root.windowRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 2
                required property var modelData
                clientDimensions: modelData
                showIcon: true
                targeted: !root.draggedAway && //
                    (root.targetedRegionX === modelData.at[0]  //
                    && root.targetedRegionY === modelData.at[1] //
                    && root.targetedRegionWidth === modelData.size[0] //
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: targeted ? root.windowBorderColor : root.quietBorderColor
                text: `${modelData.class}`
                radius: Appearance.rounding.windowRounding
            }
        }

        // Layer regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableLayerRegions) {
                        return root.layerRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 3
                required property var modelData
                clientDimensions: modelData
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0] 
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: targeted ? root.windowBorderColor : root.quietBorderColor
                text: `${modelData.namespace}`
                radius: Appearance.rounding.windowRounding
            }
        }

        // Content regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableContentRegions) {
                        return root.imageRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 4
                required property var modelData
                clientDimensions: modelData
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0] 
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.contentRegionOpacity
                borderColor: root.imageBorderColor
                text: Translation.tr("Content region")
            }
        }

        // The mode, the hint and the shape live in the notch's strip; nothing follows the cursor.
        CaptureStrip {
            id: strip
            z: 10
            visible: root.phase === RegionSelection.Phase.Select
            shown: root.visible && root.phase === RegionSelection.Phase.Select
            dragging: root.dragging
            glyph: root.stripGlyph
            hint: root.stripHint
            releaseText: root.stripRelease
            sizeText: root.stripSize
            timeText: DateTime.time
            shapeIndex: root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1
            closedWidth: IslandController.geometryFor(IslandController.transientShowing ? IslandController.transientState : "idle").w
            topMargin: Config.options.island.topMargin
            ground: root.stripGround
            onShapeChosen: index => {
                root.selectionMode = index === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
            }
            onCloseRequested: root.dismiss()
        }
    }
}
