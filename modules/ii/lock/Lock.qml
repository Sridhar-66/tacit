pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.panels.lock
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

LockScreen {
    id: root

    property string lastProcessedLockWall: ""
    property bool lastProcessedDarkmode: Appearance.m3colors.darkmode

    lockSurface: LockSurface {
        context: root.context
    }

    Process {
        id: lockThemeProc
        // argv, not a shell line: a lock wallpaper whose name holds a quote used to end the
        // quoting and hand the rest of the path to bash as words of its own.
        command: [Directories.wallpaperSwitchScriptPath,
            "--mode", Appearance.m3colors.darkmode ? "dark" : "light",
            "--colors_lock",
            "--image", Config.options.background.lockWall
        ]
        onExited: {
            MaterialThemeLoader.useLockTheme()
            root.lastProcessedLockWall = Config.options.background.lockWall
            root.lastProcessedDarkmode = Appearance.m3colors.darkmode
        }
    }

    // Locking used to push every window to workspace 2147483647-N and swap in a slidevert
    // workspace animation so the lock could slide over the desktop. The lock draws its own
    // opaque ground now, so none of that was visible -- and it left every window on a
    // workspace no keybind reaches whenever the shell died while locked, never put the user's
    // `animation workspaces` keyword back, and could restore stale workspaces on unlock.
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            var wallChanged = Config.options.background.lockWall !== root.lastProcessedLockWall
            var modeChanged = Appearance.m3colors.darkmode !== root.lastProcessedDarkmode

            if (GlobalStates.screenLocked) {
                if (Config.options.background.lockWall !== "" && (wallChanged || modeChanged)) {
                    lockThemeProc.running = true
                } else if (Config.options.background.lockWall !== "") {
                    MaterialThemeLoader.useLockTheme()
                }
            } else if (Config.options.background.lockWall !== "") {
                MaterialThemeLoader.useLiveTheme()
            }
        }
    }
}