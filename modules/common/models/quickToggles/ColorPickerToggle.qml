import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    id: root
    name: Translation.tr("Color picker")
    hasStatusText: false
    toggled: false
    icon: "colorize"

    // hyprpicker is not part of this shell. The pill closes the panel and acts 300 ms later
    // through execDetached, which has no exit code, so on a machine without it the press did
    // nothing and said nothing. Checked once, as SongRec and EasyEffects check theirs.
    available: false
    Process {
        running: true
        command: ["bash", "-c", "command -v hyprpicker"]
        onExited: (exitCode) => root.available = (exitCode === 0)
    }

    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        delayedActionTimer.start();
    }
    Timer {
        id: delayedActionTimer
        interval: 300
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["hyprpicker", "-a"]);
        }
    }

    tooltipText: Translation.tr("Color picker")
}
