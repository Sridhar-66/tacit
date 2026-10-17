pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property Component contentComponent

    // Kept up for 450 ms after the request ends, so the content can fold back instead of vanishing.
    property bool lingering: false
    Connections {
        target: PolkitService
        function onActiveChanged() {
            if (!PolkitService.active) {
                root.lingering = true;
                linger.restart();
            }
        }
    }
    Timer {
        id: linger
        interval: 450
        onTriggered: root.lingering = false
    }

    Loader {
        active: PolkitService.active || root.lingering
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
                WlrLayershell.namespace: "quickshell:polkit"
                // Exclusive while asking: with OnDemand the keys went to the focused window until
                // the prompt was clicked, so the password was typed into the terminal.
                WlrLayershell.keyboardFocus: PolkitService.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                Loader {
                    anchors.fill: parent
                    sourceComponent: root.contentComponent
                }
            }
        }
    }
}
