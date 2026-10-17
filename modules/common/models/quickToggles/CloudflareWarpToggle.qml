import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

QuickToggleModel {
    id: root
    name: Translation.tr("Cloudflare WARP")

    toggled: false
    icon: "cloud_lock"

    // No warp-cli, no pill: `warp-cli status` prints nothing when it is not installed.
    available: false

    // warp-cli's own answer decides, not the click: the pill used to write toggled itself and fire
    // execDetached, so a refused connect showed "on" with the tunnel down for the rest of the
    // session. The failure notification written in this file was only ever reachable from a
    // first-time registration; now every action goes through it.
    function run(arg) {
        root.busy = true
        actionProc.wantOn = (arg === "connect")
        actionProc.command = ["warp-cli", arg]
        actionProc.running = true
    }

    mainAction: () => {
        if (root.busy)
            return
        root.run(root.toggled ? "disconnect" : "connect")
    }

    Process {
        id: actionProc
        property bool wantOn: false
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode === 0) {
                root.toggled = actionProc.wantOn
            } else {
                Quickshell.execDetached(["notify-send",
                    Translation.tr("Cloudflare WARP"),
                    Translation.tr("Connection failed. Please inspect manually with the <tt>warp-cli</tt> command")
                    , "-a", "Shell"
                ])
            }
            // What warp-cli says it is now, in case the command half-succeeded.
            fetchActiveState.running = false
            fetchActiveState.running = true
        }
    }

    Process {
        id: registrationProc
        command: ["warp-cli", "registration", "new"]
        onExited: (exitCode, exitStatus) => {
            console.log("Warp registration exited with code and status:", exitCode, exitStatus)
            if (exitCode === 0) {
                root.run("connect")
            } else {
                Quickshell.execDetached(["notify-send", 
                    Translation.tr("Cloudflare WARP"), 
                    Translation.tr("Registration failed. Please inspect manually with the <tt>warp-cli</tt> command"),
                    "-a", "Shell"
                ])
            }
        }
    }

    Process {
        id: fetchActiveState
        running: true
        command: ["bash", "-c", "warp-cli status"]
        stdout: StdioCollector {
            id: warpStatusCollector
            onStreamFinished: {
                if (warpStatusCollector.text.length > 0) {
                    root.available = true
                }
                if (warpStatusCollector.text.includes("Unable")) {
                    registrationProc.running = true
                } else if (warpStatusCollector.text.includes("Connected")) {
                    root.toggled = true
                } else if (warpStatusCollector.text.includes("Disconnected")) {
                    root.toggled = false
                }
            }
        }
    }
    tooltipText: Translation.tr("Cloudflare WARP (1.1.1.1)")
}
