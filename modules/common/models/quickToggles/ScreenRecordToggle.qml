import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Relocated from the bar's util buttons (UtilButtons.qml recordingItem) into the
// control panel grid. Same action, same state source; modelled on ScreenSnipToggle.
QuickToggleModel {
    name: Translation.tr("Screen record")
    hasStatusText: false
    toggled: Persistent.states.record.enable
    icon: toggled ? "stop_circle" : "screen_record"
    // the notch's choice (or Stop while one runs), once the panel has gone
    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        IslandController.openRecordSoon();
    }
    tooltipText: Translation.tr("Screen record")
}
