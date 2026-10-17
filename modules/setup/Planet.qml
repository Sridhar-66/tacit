import QtQuick
import Qt5Compat.GraphicalEffects

// A picture to choose: a planet from Tacit's renderer, in a circle. The chosen one has a ring of the horizon's light.
Item {
    id: p
    property string name
    property bool on: false
    signal picked()
    width: Look.px(58); height: width
    activeFocusOnTab: true
    Keys.onSpacePressed: picked()
    Keys.onReturnPressed: picked()
    Image { id: img; anchors.fill: parent; source: Qt.resolvedUrl("../../assets/setup/planets/" + p.name + ".jpg"); visible: false; sourceSize: Qt.size(256, 256) }
    Rectangle { id: mask; anchors.fill: parent; radius: width / 2; visible: false }
    OpacityMask { anchors.fill: parent; source: img; maskSource: mask }
    Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12) }
    scale: p.activeFocus || ma.containsMouse ? 1.1 : 1
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Rectangle {
        visible: p.on
        anchors.fill: parent; anchors.margins: -Look.px(6); radius: width / 2; color: "transparent"
        border.width: 1.5
        border.color: Qt.rgba(0.95, 0.77, 0.60, 0.9)
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.picked() }
}
