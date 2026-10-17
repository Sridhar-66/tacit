pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs
import qs.services

Singleton {
    id: root
    property alias agent: polkitAgent
    // Not the agent's own state: under ext-session-lock no layer surface can draw above the
    // lock or take focus from it, so a dialog built while the screen is locked is invisible
    // and unanswerable. The flow survives the lock in the common cases; the window waits.
    readonly property bool active: polkitAgent.isActive && !GlobalStates.screenLocked
    property alias flow: polkitAgent.flow
    property bool interactionAvailable: false
    property string cleanMessage: {
        if (!root.flow) return "";
        return root.flow.message.endsWith(".")
            ? root.flow.message.slice(0, -1)
            : root.flow.message
    }
    property string cleanPrompt: {
        const inputPrompt = PolkitService.flow?.inputPrompt.trim() ?? "";
        const cleanedInputPrompt = inputPrompt.endsWith(":") ? inputPrompt.slice(0, -1) : inputPrompt;
        const usePasswordChars = !(PolkitService.flow?.responseVisible ?? false)
        return cleanedInputPrompt || (usePasswordChars ? Translation.tr("Password") : Translation.tr("Input"))
    }

    function cancel() {
        root.flow?.cancelAuthenticationRequest()
    }

    function submit(string) {
        root.flow?.submit(string)
        root.interactionAvailable = false
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            root.interactionAvailable = true;
        }
    }

    PolkitAgent {
        id: polkitAgent
        onAuthenticationRequestStarted: {
            root.interactionAvailable = true;
        }
    }

    // One agent per seat. A user arriving from another setup very likely still starts
    // hyprpolkitagent, polkit-gnome or lxqt-policykit, and then this one loses the registration
    // and every privileged action - pkexec, a udisks mount from Files, the settings app's system
    // actions - prompts into a dialog nobody will draw. Registration is asynchronous, so the
    // verdict is read once, after it has had time to settle.
    Timer {
        interval: 5000
        running: true
        onTriggered: {
            if (polkitAgent.isRegistered) return;
            console.error("[PolkitService] Not registered as this seat's polkit agent - another agent already owns it. Password prompts for privileged actions will not appear in this desktop.");
            Quickshell.execDetached(["notify-send", "Authentication",
                "Another polkit agent owns this seat, so password prompts will not appear here. Stop it (hyprpolkitagent, polkit-gnome or lxqt-policykit) and restart the shell.",
                "-a", "Shell", "-u", "critical"]);
        }
    }
}
