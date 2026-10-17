import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * The way back from a section opened as a page of its own: a chevron and the page's name, on the
 * headings' edge.
 */
Item {
    id: back
    property string text: ""
    signal clicked()
    Layout.leftMargin: 10
    Layout.topMargin: 8
    implicitWidth: backRow.implicitWidth + 16
    implicitHeight: 32
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, backArea.pressed ? 0.88 : backArea.containsMouse ? 0.95 : 1)
        Behavior on color { enabled: !backArea.pressed; ColorAnimation { duration: 110 } }
    }
    Row {
        id: backRow
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "chevron_left"; iconSize: 20; color: backArea.containsMouse ? Appearance.colors.colInkMain : Tacit.inkSec }
        StyledText { anchors.verticalCenter: parent.verticalCenter; text: back.text; font.pixelSize: 15; color: backArea.containsMouse ? Appearance.colors.colInkMain : Tacit.inkSec }
    }
    MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: back.clicked() }
}
