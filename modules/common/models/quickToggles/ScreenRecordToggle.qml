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
    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start();
    }
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false
        onTriggered: {
            Quickshell.execDetached([Directories.recordScriptPath]);
        }
    }
    tooltipText: Translation.tr("Screen record")
}
