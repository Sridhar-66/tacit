import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// PermissionCard's answer button (onSurface wash, full rounding, 30 high, 13 px) as a control.
// `on` takes the stronger wash (NotificationActionButton urgent) and the primary glyph.
// Plain component, no services: the login lock's tree may load it.
Rectangle {
    id: root
    property string glyph: ""
    property string label: ""
    property bool on: false
    property bool enabled: true
    readonly property bool hovered: area.containsMouse
    signal clicked
    signal rightClicked

    implicitHeight: 30
    implicitWidth: row.implicitWidth + 24
    radius: Appearance.rounding.full
    opacity: root.enabled ? 1 : 0.4
    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, root.on ? (root.hovered ? 0.82 : 0.86) : (root.hovered ? 0.89 : 0.93))
    Behavior on color {
        CAnim {}
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        MaterialSymbol {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            iconSize: 18
            fill: root.on ? 1 : 0
            color: root.on ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
        }
        StyledText {
            visible: root.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer0
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
