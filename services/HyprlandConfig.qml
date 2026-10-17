pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root
    signal reloaded()

    readonly property string configuratorScriptPath: Quickshell.shellPath("scripts/hyprland/hyprconfigurator.py")
    readonly property string shellOverridesPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/shellOverrides/main.lua`)

    // Every writer goes through one queued Process. Detached, they were fire-and-forget: a
    // dragged slider started several python3 runs rewriting main.lua at once, and a run that
    // never wrote - no python3, a raise in hyprconfigurator.py - reported nothing at all, since
    // the only other feedback is the configreloaded event, which then never comes.
    Process {
        id: writer
        property var queue: []
        property var current: []
        function push(args) {
            writer.queue.push(args)
            if (!writer.running) writer.next()
        }
        function next() {
            if (writer.queue.length === 0) return
            writer.current = writer.queue.shift()
            writer.command = writer.current
            writer.running = true
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const keys = writer.current.filter((arg, i) => i > 0 && (writer.current[i - 1] === "--set" || writer.current[i - 1] === "--reset"))
                Quickshell.execDetached(["notify-send", Translation.tr("Hyprland settings"),
                    keys.length > 0 ? Translation.tr("Could not write %1").arg(keys.join(", "))
                                    : Translation.tr("Could not write the Hyprland override"), "-a", "Shell"])
            } else {
                reloadTimer.restart()
            }
            writer.next()
        }
    }

    // Writing the Lua file changes nothing by itself: Hyprland reads it once, at load. Nothing in
    // the shell reloaded the compositor, so every control on the Hyprland page and the Game mode
    // toggle stored a value and left the desktop as it was until the next login. The delay lets a
    // dragged spinbox settle into one reload instead of one per step.
    Timer {
        id: reloadTimer
        interval: 300
        onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
    }

    function set(key: string, value: var) {
        writer.push([
            "python3", root.configuratorScriptPath,
            "--file", root.shellOverridesPath,
            "--set", key, String(value)
        ])
    }

    function setMany(entries: var) {
        let args = ["python3", root.configuratorScriptPath, "--file", root.shellOverridesPath]
        for (let key in entries) {
            args.push("--set", key, String(entries[key]))
        }
        writer.push(args)
    }

    function reset(key: string) {
        writer.push([
            "python3", root.configuratorScriptPath,
            "--file", root.shellOverridesPath,
            "--reset", key
        ])
    }

    function resetMany(keys: list<string>) {
        let args = ["python3", root.configuratorScriptPath, "--file", root.shellOverridesPath]
        for (let i = 0; i < keys.length; i++) {
            args.push("--reset", keys[i])
        }
        writer.push(args)
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                root.reloaded()
            }
        }
    }
}