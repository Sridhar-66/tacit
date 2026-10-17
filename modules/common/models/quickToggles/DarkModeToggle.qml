import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Dark Mode")
    statusText: Appearance.m3colors.darkmode ? Translation.tr("Dark") : Translation.tr("Light")

    toggled: Appearance.m3colors.darkmode
    icon: "contrast"
    // Regenerating the scheme takes a moment, and execDetached had no exit code: a switch script
    // that is missing or fails left the pill on the old mode with nothing said. Through bash, so
    // a script that cannot be run reports 126/127 instead of never starting.
    busy: switchProc.running

    mainAction: () => {
        if (switchProc.running)
            return;
        switchProc.command = ["bash", "-c", 'exec "$@"', "_", Directories.wallpaperSwitchScriptPath,
            "--mode", Appearance.m3colors.darkmode ? "light" : "dark", "--noswitch"];
        switchProc.running = true;
    }

    Process {
        id: switchProc
        onExited: (exitCode) => {
            if (exitCode === 0)
                return;
            Quickshell.execDetached(["notify-send",
                Translation.tr("Dark Mode"),
                Translation.tr("The colour switch exited %1. Nothing changed.").arg(exitCode),
                "-a", "Shell"]);
        }
    }

    tooltipText: Translation.tr("Dark Mode")
}
