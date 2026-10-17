import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Handles EasyEffects active state and presets.
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false

    function fetchAvailability() {
        fetchAvailabilityProc.running = false
        fetchAvailabilityProc.running = true
    }

    function fetchActiveState() {
        fetchActiveStateProc.running = false
        fetchActiveStateProc.running = true
    }

    // `easyeffects --service-mode` never returns, so these stay detached and `active` is only
    // provisional until the probe below answers. The flatpak fallback used to say
    // `flatpak pkill`, which is not a flatpak command, so disabling failed in silence while
    // the tile went off and the effects kept processing audio.
    function disable() {
        root.active = false
        Quickshell.execDetached(["bash", "-c", "pkill easyeffects || flatpak kill com.github.wwmm.easyeffects"])
        confirmTimer.restart()
    }

    function enable() {
        root.active = true
        Quickshell.execDetached(["bash", "-c", "easyeffects --hide-window --service-mode || flatpak run com.github.wwmm.easyeffects --hide-window --service-mode"])
        confirmTimer.restart()
    }

    function toggle() {
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Timer {
        id: confirmTimer
        interval: 1200
        onTriggered: root.fetchActiveState()
    }

    Timer {
        // EasyEffects can be started or killed outside the shell; the tile used to stay wrong
        // until the shell restarted.
        interval: 30000
        running: root.available
        repeat: true
        onTriggered: root.fetchActiveState()
    }

    Process {
        id: fetchAvailabilityProc
        running: true
        command: ["bash", "-c", "command -v easyeffects || flatpak info com.github.wwmm.easyeffects > /dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0
        }
    }

    Process {
        id: fetchActiveStateProc
        running: true
        command: ["bash", "-c", "pidof easyeffects || flatpak ps | grep com.github.wwmm.easyeffects > /dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.active = exitCode === 0
        }
    }
}
