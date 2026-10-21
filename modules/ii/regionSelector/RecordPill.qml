import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// A recording's pill over the area picker (RegionSelection): Cancel and Record under a drawn area, "Record <App>" on a
// window. The way forward has the accent.
Rectangle {
    id: pill
    property string label
    property string glyph: ""
    property bool strong: false   // the way forward: the accent
    signal picked()
    implicitWidth: pillRow.implicitWidth + (pill.glyph !== "" ? 26 : 28)
    implicitHeight: 34
    radius: 17
    color: pill.strong ? Tacit.accent : ColorUtils.transparentize(Tacit.inkMain, pillArea.containsMouse ? 0.8 : 0.88)
    Row {
        id: pillRow
        x: pill.glyph !== "" ? 11 : 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7
        MaterialSymbol {
            visible: pill.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pill.glyph
            fill: 1
            iconSize: 15
            color: pill.strong ? Tacit.onAccent : Tacit.inkSec
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.label
            font.pixelSize: 14
            font.variableAxes: ({ "wght": pill.strong ? 600 : 450 })
            color: pill.strong ? Tacit.onAccent : Tacit.inkSec
        }
    }
    MouseArea {
        id: pillArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.picked()
    }
}
