import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The power mode in use now (services/PowerMode.qml): a press steps the one for the charger or the battery, whichever
// is in use, and Settings > Power and battery keeps both. It asked power-profiles-daemon before, which Tacit does not
// install, so it changed nothing.
QuickToggleModel {
    name: Translation.tr("Power mode")
    available: PowerMode.available
    toggled: PowerMode.current !== "balanced"
    icon: PowerMode.glyphOf(PowerMode.current)
    statusText: PowerMode.labelOf(PowerMode.current)
    mainAction: () => PowerMode.cycleCurrent()
    tooltipText: PowerMode.charging ? Translation.tr("The power mode on the charger") : Translation.tr("The power mode on battery")
}
