import QtQuick
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Bluetooth")
    // "Not connected" with the radio off reads as "on and idle"; the palette's Bluetooth row
    // says "Off" and this follows it. The extra-device count rides along, since the pill's
    // tooltip is built from name and statusText only.
    statusText: !BluetoothStatus.available ? Translation.tr("No adapter")
        : !BluetoothStatus.enabled ? Translation.tr("Off")
        : (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Not connected"))
            + (BluetoothStatus.activeDeviceCount > 1 ? ` +${BluetoothStatus.activeDeviceCount - 1}` : "")
    tooltipText: Translation.tr("%1 | Right-click to configure").arg(
        (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Bluetooth"))
        + (BluetoothStatus.activeDeviceCount > 1 ? ` +${BluetoothStatus.activeDeviceCount - 1}` : "")
    )
    icon: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"

    available: BluetoothStatus.available
    toggled: BluetoothStatus.enabled
    mainAction: () => {
        BluetoothStatus.togglePower()
    }
    hasMenu: true
}
