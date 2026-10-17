import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Relocated from the bar's util buttons (UtilButtons.qml wallpaper toggle) into the
// control panel grid. Opens the wallpaper selector; modelled on ScreenSnipToggle.
QuickToggleModel {
    name: Translation.tr("Wallpaper")
    hasStatusText: false
    toggled: GlobalStates.wallpaperSelectorOpen
    icon: "imagesmode"
    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;
        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen;
    }
    tooltipText: Translation.tr("Wallpaper")
}
