import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 275
    minimumHeight: 60
    contentItem: FpsLimiterContent {
        radius: root.contentRadius
    }
}
