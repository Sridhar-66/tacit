import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Bluetooth

/**
 * The set-once side of Bluetooth; the quick panel does the moment-to-moment part (discovery,
 * connecting, disconnecting), which is why nothing here scans. Same split as Network: the adapter
 * and what it may tell the world, the devices you have kept, and the one list setting - which used
 * to be a fourth tab on the Network page for want of a page of its own.
 */
ContentPage {
    id: page
    forceWidth: true

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    // What the power switch was last asked for, held until BlueZ confirms it. Powering an adapter
    // on is not instant, and it is the confirmation that moves the thumb, so without this the
    // switch looks like it refused the click and invites a second one.
    property var pendingPower: null
    Timer {
        id: powerGaveUp
        interval: 5000
        onTriggered: page.pendingPower = null
    }
    Connections {
        target: BluetoothStatus
        function onEnabledChanged() {
            page.pendingPower = null;
            powerGaveUp.stop();
        }
    }

    // ================================================================ the adapter
    ContentSection {
        icon: "bluetooth"
        title: page.adapter ? (page.adapter.name.length > 0 ? page.adapter.name : Translation.tr("Bluetooth")) : Translation.tr("No Bluetooth adapter")
        shape: MaterialShape.Shape.Pill

        GroupedList {
            ConfigSwitch {
                buttonIcon: "bluetooth"
                text: Translation.tr("Bluetooth")
                enabled: !!page.adapter
                checked: page.pendingPower ?? BluetoothStatus.enabled
                onSwitched: (value) => {
                    if (!page.adapter) return;
                    page.pendingPower = value;
                    powerGaveUp.restart();
                    page.adapter.enabled = value;
                }
            }
            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Visible to other devices")
                enabled: BluetoothStatus.enabled
                checked: page.adapter?.discoverable ?? false
                onSwitched: (value) => {
                    if (page.adapter) page.adapter.discoverable = value;
                }
            }
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                text: Translation.tr("Visibility is needed only while another device is looking for this one.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
            ConfigSwitch {
                buttonIcon: "handshake"
                text: Translation.tr("Accept pairing requests")
                enabled: BluetoothStatus.enabled
                checked: page.adapter?.pairable ?? false
                onSwitched: (value) => {
                    if (page.adapter) page.adapter.pairable = value;
                }
            }
            // The agent is a separate program, so its absence is a fact about this machine rather
            // than a setting. Said here because this is the page where pairing is arranged.
            StyledText {
                visible: !BluetoothAgent.connected
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                text: Translation.tr("Pairing questions cannot be shown: quiet-btagent is not running, so a device that asks for a confirmation or a PIN will be refused. Start it with `systemctl --user start quiet-btagent.service`.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
        }
    }

    // ================================================================ kept devices
    ContentSection {
        icon: "devices"
        title: Translation.tr("Paired devices")
        shape: MaterialShape.Shape.Cookie4Sided

        GroupedList {
            ColumnLayout {
                id: pairedGroup
                readonly property var list: Bluetooth.devices.values
                    .filter(d => d.paired || d.bonded)
                    .sort((a, b) => (b.connected - a.connected) || (a.name ?? "").localeCompare(b.name ?? ""))
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    visible: pairedGroup.list.length === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    text: BluetoothStatus.enabled
                        ? Translation.tr("Nothing paired yet. Put the device in pairing mode and open Bluetooth in the quick panel to find it.")
                        : Translation.tr("Bluetooth is off.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: ScriptModel {
                        values: pairedGroup.list
                        objectProp: "address"
                    }
                    delegate: RowLayout {
                        id: devRow
                        required property var modelData
                        readonly property bool hasBattery: BluetoothStatus.hasBattery(devRow.modelData)
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            text: Icons.getBluetoothDeviceMaterialSymbol(devRow.modelData?.icon || "")
                            iconSize: Appearance.font.pixelSize.larger
                            color: devRow.modelData.connected ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: devRow.modelData?.name || Translation.tr("Unknown device")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: {
                                if (devRow.modelData.connected)
                                    return devRow.hasBattery
                                        ? Translation.tr("connected · %1%").arg(Math.round(devRow.modelData.battery * 100))
                                        : Translation.tr("connected");
                                return Translation.tr("paired");
                            }
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        StyledSwitch {
                            checked: devRow.modelData.trusted
                            onClicked: {
                                devRow.modelData.trusted = !devRow.modelData.trusted;
                                checked = Qt.binding(() => devRow.modelData.trusted);
                            }
                            StyledToolTip {
                                text: Translation.tr("Trusted: reconnects on its own without asking")
                            }
                        }
                        SmallAction {
                            label: Translation.tr("Forget")
                            onClicked: devRow.modelData.forget()
                        }
                    }
                }
            }
        }
    }

    // ================================================================ the list
    ContentSection {
        icon: "device_unknown"
        title: Translation.tr("What the list shows")
        shape: MaterialShape.Shape.Sunny

        GroupedList {
            ConfigSwitch {
                buttonIcon: "device_unknown"
                text: Translation.tr("Hide devices that broadcast only a random address")
                checked: Config.options.bluetooth.hideUnnamedDevices
                onSwitched: (value) => {
                    Config.options.bluetooth.hideUnnamedDevices = value;
                }
            }
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                text: Translation.tr("Phones and watches nearby rotate a random address every few minutes and carry no name, so they arrive in the list as a bare address. Paired and connected devices are always shown.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
        }
    }

    // A small text button on a row, the Network page's own shape.
    component SmallAction: RippleButton {
        id: act
        property string label: ""
        property bool primary: false
        implicitHeight: 30
        implicitWidth: actLabel.implicitWidth + 24
        buttonRadius: Appearance.rounding.small
        colBackground: primary ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
        colBackgroundHover: primary ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
        colRipple: primary ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active
        opacity: enabled ? 1 : 0.5
        contentItem: StyledText {
            id: actLabel
            anchors.centerIn: parent
            text: act.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: act.primary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        }
    }
}
