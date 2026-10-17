pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * The window the pairing sheet lives in, the shape of the polkit window (FullscreenPolkitWindow.qml):
 * overlay layer, keyboard held while asking, kept up for 450 ms after the answer so the sheet can
 * fold back into the notch.
 *
 * Not shown while the screen is locked: under ext-session-lock no layer surface can draw above the
 * lock or take its focus, so a sheet built there would be invisible and unanswerable. BluetoothAgent
 * holds the question until the session is back, and quiet-btagent gives up after a minute.
 */
Scope {
    id: root

    // Up while asking and for 450 ms after, so the sheet can fold back. Set from the signal, not
    // bound, so the window cannot close ahead of the fold.
    property bool up: BluetoothAgent.asking
    Connections {
        target: BluetoothAgent
        function onAskingChanged() {
            if (BluetoothAgent.asking) {
                linger.stop();
                root.up = true;
            } else {
                linger.restart();
            }
        }
    }
    Timer {
        id: linger
        interval: 450
        onTriggered: root.up = false
    }

    Loader {
        active: root.up
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:btpair"
                // Exclusive while asking: with OnDemand the keys go to the focused window until the
                // sheet is clicked.
                WlrLayershell.keyboardFocus: BluetoothAgent.asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                BluetoothPairContent {
                    anchors.fill: parent
                }
            }
        }
    }
}
