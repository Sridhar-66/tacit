//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
// the notch's sand (Tacit.Sand, native/sand/build.sh) is installed in ~/.local/lib/qml
//@ pragma Env QML_IMPORT_PATH=/home/abdul/.local/lib/qml
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// Remove two slashes below and adjust the value to change the UI scale
////@ pragma Env QT_SCALE_FACTOR=1
import "modules/common"
import "services"
import "panelFamilies"
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    ReloadPopup {}

    Process {
        id: autostartProc
        command: ["python3", `${Directories.scriptPath}/hyprland/autostart.py`]
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (!Config.ready) return

            if (WM.compositor === "niri") {
                Config.options.background.lockWall = ""
                Config.options.overview.enable = false
            }

            if (Config.options.hyprland.autostartApps.enable &&
                Config.options.hyprland.autostartApps.apps.length > 0) {
                autostartProc.running = true
            }
        }
    }

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Hyprsunset.load()
        FirstRunExperience.load()
        ConflictKiller.load()
        Cliphist.refresh()
        Wallpapers.load()
        Updates.load()
    }
    
    // GlobalStates' shortcuts and IPC, here so only the shell holds them. GlobalStates is also
    // read in the Settings app's process (DateTime and BluetoothAgent watch screenLocked), where
    // they registered a second time: a key press reached both processes, and the wallpaper toggle
    // flipped the config twice.
    CompositorGlobalShortcut {
        name: "workspaceNumber"
        description: "Held while dragging a Files window: it snaps to an edge or maximises"
        onPressed: GlobalStates.superDown = true
        onReleased: GlobalStates.superDown = false
    }
    CompositorGlobalShortcut {
        name: "centeredWallpaperToggle"
        description: "Toggles centered wallpaper"
        onPressed: Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
    }
    IpcHandler {
        target: "background"
        function toggleCenteredWallpaper(): void {
            Config.options.background.centeredWallpaper = !Config.options.background.centeredWallpaper
        }
    }

    PanelFamilyLoader {
        identifier: "ii"
        component: IllogicalImpulseFamily {}
    }

    component PanelFamilyLoader: LazyLoader {
        required property string identifier
        // config.json has the last word on panelFamily and panelFamilies/ ships one family, so
        // this loader also answers for a string that names no family: a typo or a preset used to
        // leave the shell running with nothing on screen at all - no island, no background, no
        // launcher - and no way back but editing JSON from a TTY. A second family means listing
        // it here too, and then only one of them may take the unknown case.
        readonly property var knownFamilies: ["ii"]
        active: Config.ready && (Config.options.panelFamily === identifier
            || !knownFamilies.includes(Config.options.panelFamily))
    }
}
