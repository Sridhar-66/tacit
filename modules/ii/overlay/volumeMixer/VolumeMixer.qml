import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay
import qs.modules.ii.sidebarRight.volumeMixer

// The control panel's own sound section (sidebarRight/volumeMixer/AudioSection.qml), output then
// input, unfolded.
StyledOverlayWidget {
    id: root
    minimumWidth: 340
    minimumHeight: 300

    contentItem: OverlayBackground {
        radius: root.contentRadius

        StyledFlickable {
            id: scroll
            anchors.fill: parent
            contentHeight: sections.implicitHeight
            clip: true

            ColumnLayout {
                id: sections
                width: scroll.width
                spacing: 0

                AudioSection {
                    input: false
                    shown: true
                }
                Item {
                    implicitHeight: 12
                }
                AudioSection {
                    input: true
                    shown: true
                }
            }
        }
    }
}
