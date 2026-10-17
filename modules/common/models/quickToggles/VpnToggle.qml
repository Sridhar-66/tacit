import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("VPN")
    statusText: Vpn.active?.name ?? (Vpn.connections.length > 0 ? Translation.tr("Off") : Translation.tr("None set up"))
    tooltipText: Vpn.active ? Translation.tr("%1 | Right-click to disconnect").arg(Vpn.active.name) : Translation.tr("VPN")
    icon: Vpn.connected ? "vpn_key" : "vpn_key_off"
    toggled: Vpn.connected
    busy: Vpn.busy
    // Nothing to bring up until a profile exists: the pill said "None set up" and still took a
    // right-click that fell through all three branches below. The list stays reachable (TogglePill).
    available: Vpn.connections.length > 0
    // the pill: back on to the last VPN, or off; the section lists them
    mainAction: () => {
        if (Vpn.connected)
            Vpn.disconnect();
        else if (Vpn.autoVpn.length > 0)
            Vpn.connect(Vpn.autoVpn);
        else if (Vpn.connections.length > 0)
            Vpn.connect(Vpn.connections[0].name);
    }
    hasMenu: true
}
