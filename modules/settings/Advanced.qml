import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * The exact values behind a page's presets, at its foot: closed it is one quiet line, open it is a
 * group of rows in place, so nobody is sent to another page to find a number.
 */
ColumnLayout {
    id: adv
    property bool open: false
    default property alias rows: panel.rows

    Layout.fillWidth: true
    Layout.topMargin: 40
    spacing: 0

    // its word on the headings' edge (20), like every other start on the page
    Item {
        id: line
        Layout.leftMargin: 14
        implicitWidth: lineRow.implicitWidth + 12
        implicitHeight: 32
        activeFocusOnTab: true
        Keys.onReturnPressed: adv.open = !adv.open
        Keys.onEnterPressed: adv.open = !adv.open
        Keys.onSpacePressed: adv.open = !adv.open

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: lineArea.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.96) : "transparent"
            border.width: line.activeFocus && (line.focusReason === Qt.TabFocusReason || line.focusReason === Qt.BacktabFocusReason) ? 2 : 0
            border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.15)
        }
        Row {
            id: lineRow
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Advanced"
                font.pixelSize: 15
                color: lineArea.containsMouse ? Appearance.colors.colInkMain : Tacit.inkSec
            }
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: adv.open ? "expand_less" : "expand_more"
                iconSize: 17
                color: Tacit.inkMeta
            }
        }
        MouseArea {
            id: lineArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: adv.open = !adv.open
        }
    }

    Group {
        id: panel
        visible: adv.open
        Layout.topMargin: 6
    }
}
