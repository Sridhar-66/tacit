pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

// The window band (tacit-frame, Tacit's Hyprland plugin) in the shell: what a gesture did, said in the notch with the
// way back (Reopen, Show, Undo); the hint, until each gesture has been used once; the menu a right click on a
// window's top edge asks for. Without the plugin no tacitgrip events come, and none of this shows.
Singleton {
    id: root

    // the menu while it is open: { address, monitor, x, y } (logical, on that monitor)
    property var menu: null
    // the gestures the person has used (close, hide, side), kept across restarts: the hint stops once all are known
    property var used: ({})
    property real hintedAt: 0
    readonly property int hintEvery: 10 * 60 * 1000
    readonly property string filePath: FileUtils.trimFileProtocol(`${Directories.state}/user/window-band.json`)

    function command(verb, address) {
        Quickshell.execDetached(["hyprctl", "tacitgrip", verb, address]);
    }
    // the menu's rows and the notch's pill
    function act(verb, address) {
        root.menu = null;
        root.command(verb, address);
    }

    // a window the band holds away, by the plugin's special workspaces: "hidden", "closed" (closed after a few seconds
    // unless reopened), or "" for any other
    function heldAs(toplevel) {
        const h = Hyprland.toplevels.values.find(x => x.wayland === toplevel);
        const ws = h?.workspace?.name ?? "";
        return ws === "special:tacit-hidden" ? "hidden" : ws === "special:tacit-closed" ? "closed" : "";
    }
    function addressOf(toplevel) {
        const a = Hyprland.toplevels.values.find(x => x.wayland === toplevel)?.address ?? "";
        return a.length === 0 || a.startsWith("0x") ? a : `0x${a}`;
    }

    function nameFor(cls) {
        const e = DesktopEntries.byId(cls) ?? DesktopEntries.heuristicLookup(cls);
        return e?.name || (cls.length > 0 ? cls.charAt(0).toUpperCase() + cls.slice(1) : "Window");
    }
    function say(text, icon, pill, verb, address, hold) {
        IslandController.request("window", {
            "text": text,
            "icon": icon,
            "pill": pill,
            "verb": verb,
            "address": address,
            "hold": hold
        }, 65);
    }
    function mark(gesture) {
        if (root.used[gesture])
            return;
        const u = Object.assign({}, root.used);
        u[gesture] = true;
        root.used = u;
        bandFile.setText(JSON.stringify({ "used": u }));
    }
    function hint() {
        if (root.used.close && root.used.hide)
            return;
        const now = Date.now();
        if (now - root.hintedAt < root.hintEvery)
            return;
        root.hintedAt = now;
        IslandController.request("window", {
            "text": "Drag up to close · down to hide",
            "icon": "swipe_vertical",
            "hold": 4000
        }, 40);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "tacitgrip")
                return;
            const f = event.data.split(",");
            switch (f[0]) {
            case "closed":
                root.mark("close");
                root.say(`${root.nameFor(f[2] ?? "")} closed`, "close", "Reopen", "reopen", f[1], 7000);
                break;
            case "hidden":
                root.mark("hide");
                root.say(`${root.nameFor(f[2] ?? "")} hidden`, "minimize", "Show", "reopen", f[1], 3500);
                break;
            case "side":
                root.mark("side");
                root.say(`${root.nameFor(f[3] ?? "")} on the ${f[2]}`, f[2] === "left" ? "splitscreen_left" : "splitscreen_right",
                         "Undo", "unside", f[1], 6000);
                break;
            case "restored":
                if (IslandController.transientState === "window" && IslandController.payload?.address === f[1])
                    IslandController.dismiss();
                break;
            case "hover":
                root.hint();
                break;
            case "menu":
                root.menu = { "address": f[1], "monitor": f[2], "x": Number(f[3]), "y": Number(f[4]) };
                break;
            }
        }
    }

    FileView {
        id: bandFile
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            try {
                root.used = JSON.parse(bandFile.text()).used ?? ({});
            } catch (e) {
                root.used = ({});
            }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                bandFile.setText(JSON.stringify({ "used": {} }));
        }
    }
}
