import QtQuick

// One of a few choices: a ring, the chosen one with a dot of the horizon's light; words 44 in from the edge.
Item {
    id: c
    property string name
    property string detail: ""
    property bool on: false
    signal picked()
    height: col.height
    activeFocusOnTab: true
    Keys.onSpacePressed: picked()
    Keys.onReturnPressed: picked()
    Column {
        id: col
        width: c.width
        spacing: Look.px(6)
        Item {
            width: c.width; height: Look.px(30)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Look.px(22); height: width; radius: width / 2; color: "transparent"; border.width: 1
                border.color: c.on ? Qt.rgba(0.95, 0.77, 0.60, 0.85) : Qt.rgba(1, 1, 1, 0.45)
                Rectangle { visible: c.on; anchors.centerIn: parent; width: Look.px(10); height: width; radius: width / 2; color: Look.light }
            }
            T { x: Look.px(44); anchors.verticalCenter: parent.verticalCenter; text: c.name; font.pixelSize: Look.fs(22)
                font.weight: c.activeFocus ? Font.Medium : Font.Normal; color: c.on || c.activeFocus || ma.containsMouse ? Look.main : Look.meta }
        }
        T { visible: text !== ""; x: Look.px(44); width: c.width - Look.px(44); text: c.detail; wrapMode: Text.Wrap; lineHeight: 1.3
            font.pixelSize: Look.fs(18); color: c.on ? Look.sec : Look.meta }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.picked() }
}
