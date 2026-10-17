import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// A round icon button: a bare glyph; when `on`, the primary glyph on a quiet disc (TogglePill in
// SidebarRightContent.qml). Plain component, no services: the login lock's tree may load it.
Rectangle {
    id: root
    property string glyph: ""
    property bool on: false
    property real size: 26
    property real iconSize: 18
    readonly property bool hovered: area.containsMouse
    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: root.on ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.9) : (root.hovered ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93) : "transparent")
    Behavior on color {
        CAnim {}
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        iconSize: root.iconSize
        fill: root.on ? 1 : 0
        color: root.on ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
