import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The side panel's sections as words in a row: the one showing in full tone and weight with a sand
// line under its word, the others quiet until the pointer is on them. No frame around it.
Row {
    id: tabs
    property var names: []            // [{ key, label }]
    property string current: ""
    signal picked(string key)
    spacing: 0
    Repeater {
        model: tabs.names
        Rectangle {
            id: tab
            required property var modelData
            readonly property bool on: tabs.current === tab.modelData.key
            width: word.implicitWidth + 24
            height: 34
            color: "transparent"
            StyledText {
                id: word
                anchors.centerIn: parent
                text: tab.modelData.label
                font.pixelSize: 15
                font.weight: tab.on ? Font.DemiBold : Font.Normal
                color: tab.on || tabArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
            }
            Rectangle {
                visible: tab.on
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                width: word.implicitWidth
                height: 2
                radius: 1
                color: Appearance.colors.colPrimary
            }
            MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tabs.picked(tab.modelData.key) }
        }
    }
}
