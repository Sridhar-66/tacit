import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Power Profile")
    toggled: PowerProfiles.profile !== PowerProfile.Balanced
    // Balanced is the default branch, not a case of its own: with no power-profiles-daemon the
    // profile matches nothing and both of these used to fall through to undefined - no glyph and
    // no state text. Same shape as PaletteSystemActions.powerProfileName.
    icon: switch(PowerProfiles.profile) {
        case PowerProfile.PowerSaver: return "energy_savings_leaf"
        case PowerProfile.Performance: return "local_fire_department"
        default: return "airwave"
    }
    statusText: switch(PowerProfiles.profile) {
        case PowerProfile.PowerSaver: return "Power Saver"
        case PowerProfile.Performance: return "Performance"
        default: return "Balanced"
    }
    
    mainAction: () => {
        if (PowerProfiles.hasPerformanceProfile) {
            switch(PowerProfiles.profile) {
                case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                break;
                case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                break;
                case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                break;
            }
        } else {
            PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
        }
    }
    tooltipText: Translation.tr("Click to cycle through power profiles")
}
