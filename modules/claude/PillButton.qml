import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A small action as a pill with a soft raised fill and no outline (the control panel's "on" wash),
// for Stop on a running agent, workflow or command.
Rectangle {
    id: button
    property string text: ""
    signal clicked()
    implicitWidth: label.implicitWidth + 28
    implicitHeight: 28
    radius: 14
    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, area.pressed ? 0.8 : area.containsMouse ? 0.84 : 0.9)
    Behavior on color { ColorAnimation { duration: 140 } }
    StyledText {
        id: label
        anchors.centerIn: parent
        text: button.text
        font.pixelSize: 13
        font.weight: Font.Medium
        color: Appearance.colors.colInkMain
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
}
