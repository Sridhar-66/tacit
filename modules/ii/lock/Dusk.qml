import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The dusk at shut down and restart: on every screen the desktop curves away into a planet, its light goes back to the
// edge and the limb sets, down to black (BootSky, mode "dusk"). tacit-dusk calls `dusk play` when logind announces a
// shut down or a restart, holds it back while this plays (a logind delay lock, 3.9 s of logind's 5) and lets go.
// Black is then held by the splash (tacit-bootd --shutdown) until the power goes. Off until tacit-boot-ground has made
// the person's pictures (sky.json), like the boot sky.
Scope {
    id: root
    property bool playing: false
    readonly property string skyState: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/tacit-boot"

    FileView {
        id: skyFile
        path: root.skyState + "/sky.json"
        blockLoading: true
        printErrors: false
    }

    IpcHandler {
        target: "dusk"
        // returns at once; the caller waits the dusk's length
        function play(): string {
            skyFile.reload();
            if (!skyFile.loaded || root.playing)
                return "no";
            root.playing = true;
            return "playing";
        }
    }

    Variants {
        model: root.playing ? Quickshell.screens : []
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "tacit:dusk"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            // the desktop as it was when the dusk began: the planet's surface
            ScreencopyView {
                id: capture
                anchors.fill: parent
                captureSource: win.screen
                live: false
                visible: false
            }
            BootSky {
                id: sky
                anchors.fill: parent
                mode: "dusk"
                material: capture
                palettePath: root.skyState + "/sky.json"
                // nothing is drawn until the desktop has been captured: the first frame is the desktop itself
                opacity: capture.hasContent ? 1 : 0
                onOpacityChanged: if (opacity === 1) sky.play()
            }
        }
    }
}
