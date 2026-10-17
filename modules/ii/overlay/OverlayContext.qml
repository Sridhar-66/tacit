pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.services

Singleton {
    id: root
    
    signal requestCenter(string identifier)

    readonly property list<var> availableWidgets: [
        { identifier: "crosshair", materialSymbol: "point_scan", label: Translation.tr("Crosshair") },
        { identifier: "fpsLimiter", materialSymbol: "animation", label: Translation.tr("FPS limit") },
        { identifier: "floatingImage", materialSymbol: "imagesmode", label: Translation.tr("Image") },
        { identifier: "recorder", materialSymbol: "screen_record", label: Translation.tr("Recorder") },
        { identifier: "resources", materialSymbol: "browse_activity", label: Translation.tr("Resources") },
        { identifier: "notes", materialSymbol: "note_stack", label: Translation.tr("Notes") },
        { identifier: "volumeMixer", materialSymbol: "volume_up", label: Translation.tr("Sound") },
    ]
    
    readonly property bool hasPinnedWidgets: root.pinnedWidgetIdentifiers.length > 0

    property list<string> pinnedWidgetIdentifiers: []
    property list<var> clickableWidgets: []

    function pin(identifier: string, pin = true) {
        if (pin) {
            if (!root.pinnedWidgetIdentifiers.includes(identifier)) {
                root.pinnedWidgetIdentifiers.push(identifier)
            }
        } else {
            root.pinnedWidgetIdentifiers = root.pinnedWidgetIdentifiers.filter(id => id !== identifier)
        }
    }

    function registerClickableWidget(widget: var, clickable = true) {
        if (clickable) {
            if (!root.clickableWidgets.includes(widget)) {
                root.clickableWidgets.push(widget)
            }
        } else {
            root.clickableWidgets = root.clickableWidgets.filter(w => w !== widget)
        }
    }
}
