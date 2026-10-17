pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.tacit
import qs.services
import QtQuick
import Quickshell

// The centre's list: a Flickable over a Column, as the popup stack is (NotificationPopupList). A ListView placed each
// group at the height it had when it arrived and did not move the rows below when one grew (a second line, an opened
// stack), and its add transition pinned every group added at once (the history loading) to the top: rows drawn over
// each other. A Column follows its children's heights by construction.
Flickable {
    id: root
    property bool popup: false
    // Flat rows with hairlines (the popup look) instead of cards; the sidebar uses it.
    property bool flat: false
    // what NotificationGroup expects from its list (drag-to-dismiss lets neighbours follow)
    property int dragIndex: -1
    property real dragDistance: 0
    function resetDrag() {
        root.dragIndex = -1;
        root.dragDistance = 0;
    }

    contentHeight: column.height
    boundsBehavior: Flickable.StopAtBounds
    GlideWheel { view: root }

    Column {
        id: column
        width: root.width
        spacing: (root.popup || root.flat) ? 0 : 3
        Repeater {
            model: ScriptModel {
                values: root.popup ? Notifications.popupAppNameList : Notifications.appNameList
            }
            delegate: NotificationGroup {
                required property int index
                required property var modelData
                popup: root.popup
                flat: root.flat
                width: column.width
                qmlParent: root
                notificationGroup: popup ?
                    Notifications.popupGroupsByAppName[modelData] :
                    Notifications.groupsByAppName[modelData]
            }
        }
    }
}
