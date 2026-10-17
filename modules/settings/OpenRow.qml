import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/**
 * A row that opens a section of its page as a page of its own (Accounts' agents, Desktop's dock): its
 * name, what it holds now on the line under it, a short state at the right, and the chevron.
 */
SettingRow {
    id: open
    property string value: ""          // a short state at the right ("On", "3 shown")
    control: Row {
        spacing: 10
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: open.value.length > 0
            text: open.value
            font.pixelSize: 15
            color: Tacit.inkMeta
        }
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_right"
            iconSize: 18
            color: open.hovered ? Appearance.colors.colInkMain : Tacit.inkMeta
        }
    }
}
