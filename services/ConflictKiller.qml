pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string killDialogQmlPath: FileUtils.trimFileProtocol(Quickshell.shellPath("killDialog.qml"))

    function load() {
        // dummy to force init
    }

    // shell.qml instantiates Config before it calls load(), so the false->true transition can
    // already be over by the time this service exists: then the Connections never fires and the
    // check silently never runs.
    Component.onCompleted: if (Config.ready) checkConflictsProc.running = true

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) checkConflictsProc.running = true
        }
    }

    Process {
        id: checkConflictsProc
        // kded6 is not checked: the shell has no tray while the notch replaces the bar.
        command: ["bash", "-c", `echo "$(pidof mako dunst)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const conflictingNotifications = this.text.trim().length > 0;
                var openDialog = false;
                if (conflictingNotifications) {
                    if (!Config.options.conflictKiller.autoKillNotificationDaemons) openDialog = true;
                    else Quickshell.execDetached(["killall", "mako", "dunst"])
                }
                if (openDialog) {
                    Quickshell.execDetached(["qs", "-p", root.killDialogQmlPath])
                }
            }
        }
    }
}
