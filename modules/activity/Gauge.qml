import QtQuick
import qs.modules.common.widgets

// How full the thing that matters is, under the sentence: a bar across the column (a word at its end if given).
Item {
    id: g
    property real value: 0
    property string word: ""
    property bool warn: false
    height: 20
    T {
        id: label
        anchors.right: parent.right
        text: g.word
        font.pixelSize: 15
        color: Ink.sec
    }
    Rectangle {
        y: 7
        width: Math.max(0, g.width - (g.word !== "" ? label.width + 16 : 0))
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.1)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, g.value))
            height: 6
            radius: 3
            color: g.warn ? Ink.sand : Ink.sec
            Behavior on width { Anim { type: Anim.DefaultSpatial } }
        }
    }
}
