pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * What a screen corner can open, once. Read by the shell (GlobalStates.toggleState validates a
 * configured action against it) and by the Settings app, which runs in its own process - so this
 * holds the list and nothing else: no shortcuts, no IPC, nothing that would register a second
 * time from another process.
 */
Singleton {
    readonly property var list: [
        { displayName: Translation.tr("None"),                    value: "none" },
        { displayName: Translation.tr("Control panel"),           value: "sidebarRightOpen" },
        { displayName: Translation.tr("Notification centre"),     value: "notificationCenterOpen" },
        { displayName: Translation.tr("Palette"),                 value: "overviewOpen" },
        { displayName: Translation.tr("Wallpaper selector"),      value: "wallpaperSelectorOpen" },
        { displayName: Translation.tr("Media controls"),          value: "mediaControlsOpen" },
        { displayName: Translation.tr("Overlay"),                 value: "overlayOpen" },
        { displayName: Translation.tr("Screenshot region"),       value: "regionSelectorOpen" },
        { displayName: Translation.tr("Screen translator"),       value: "screenTranslatorOpen" },
        { displayName: Translation.tr("On-screen keyboard"),      value: "oskOpen" },
        { displayName: Translation.tr("Session menu"),            value: "sessionOpen" }
    ]
}
