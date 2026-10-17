pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions

/**
 * The one way the shell opens Settings, which runs as its own process (tacit-settings.qml). Every
 * button, menu row and palette result goes through here, and so do the old panel's `settings`
 * IPC and shortcut, so nothing opens the old in-shell panel by accident.
 */
Singleton {
    id: root
    readonly property string opener: FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/settings/open.sh"))

    // page: a key of SettingsCatalog; "" keeps whatever page Settings is on
    function open(page: string): void {
        Quickshell.execDetached([root.opener, page ?? ""]);
    }
    function toggle(): void {
        Quickshell.execDetached([root.opener, "--toggle"]);
    }

    // The old panel's page names ("Notch", or "Notch:search term"), for links and scripts
    // written against it.
    readonly property var oldPages: ({
        "Quick": "look", "General": "look", "Bar": "desktop", "Notch": "notch", "Network": "network",
        "Bluetooth": "bluetooth", "Desktop": "look", "Interface": "desktop", "Services": "apps",
        "Hyprland": "windows", "Niri": "windows", "About": "about"
    })
    function keyFor(name: string): string {
        const head = (name ?? "").split(":")[0];
        if (SettingsCatalog.categories.some(c => c.key === head))
            return head;
        return root.oldPages[head] ?? "";
    }
}
