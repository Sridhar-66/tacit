import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The facts as the approved mock lays them out: a quiet label, the value, a quieter line under it, a
// clear gap between them; the words and labels are plain, as everywhere in Tacit. What is technical (lens, settings, the real file name,
// the full path) waits behind "More". `info` is Info.facts: { sections, lines, more }.
Column {
    id: root
    property var info: ({ sections: [], lines: [], more: [] })
    property bool moreOn: false
    property real colWidth: 300
    signal moreToggled()
    signal copyPath()
    spacing: 22

    Repeater {
        model: root.info.sections ?? []
        Column {
            required property var modelData
            width: root.colWidth
            spacing: 3
            VT { text: modelData[0]; ink: 2; font.pixelSize: 13 }
            VT { width: parent.width; wrapMode: Text.Wrap; text: modelData[1]; ink: 0; font.pixelSize: 14 }
            VT { visible: modelData[2].length > 0; width: parent.width; wrapMode: Text.Wrap; text: modelData[2]; ink: 2; font.pixelSize: 13 }
        }
    }
    Repeater {
        model: root.info.sections ? [] : root.info.lines
        VT {
            required property string modelData
            required property int index
            width: root.colWidth
            wrapMode: Text.WordWrap
            text: modelData
            ink: index === 0 ? 0 : 1
            font.pixelSize: index === 0 ? 15 : 14
            font.weight: index === 0 ? Font.DemiBold : Font.Normal
        }
    }

    // the disclosure
    Item {
        id: toggle
        visible: root.info.more.length > 0
        width: moreRow.implicitWidth + 12
        height: 32
        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.verysmall
            color: tap.pressed ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.78)
                 : tap.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.90) : "transparent"
        }
        Row {
            id: moreRow
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            VT { anchors.verticalCenter: parent.verticalCenter; text: "More"; ink: 1; font.pixelSize: 14 }
            VGlyph { anchors.verticalCenter: parent.verticalCenter; text: root.moreOn ? "expand_less" : "expand_more"; iconSize: 18; ink: 1 }
        }
        MouseArea { id: tap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.moreToggled() }
    }
    Item {
        id: box
        width: root.colWidth
        height: root.moreOn ? rows.implicitHeight : 0
        clip: true
        opacity: root.moreOn ? 1 : 0
        visible: height > 0.5
        Behavior on height { Anim { type: Anim.DefaultEffects } }
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Column {
            id: rows
            width: parent.width
            spacing: 8
            Repeater {
                model: root.info.more
                Item {
                    required property var modelData
                    width: rows.width
                    height: Math.max(lab.implicitHeight, val.implicitHeight)
                    VT { id: lab; width: 92; text: modelData[0]; ink: 2; font.pixelSize: 13 }
                    VT { id: val; x: 100; width: parent.width - 100; wrapMode: modelData[0] === "Folder" ? Text.NoWrap : Text.Wrap; elide: modelData[0] === "Folder" ? Text.ElideMiddle : Text.ElideNone; text: modelData[1]; ink: 1; font.pixelSize: 13 }
                }
            }
            Item {
                width: copyRow.implicitWidth + 12
                height: 32
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.verysmall
                    color: cp.pressed ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.78)
                         : cp.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.90) : "transparent"
                }
                Row {
                    id: copyRow
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    VGlyph { anchors.verticalCenter: parent.verticalCenter; text: "content_copy"; iconSize: 18; ink: 1 }
                    VT { anchors.verticalCenter: parent.verticalCenter; text: "Copy path"; ink: 1; font.pixelSize: 14 }
                }
                MouseArea { id: cp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.copyPath() }
            }
        }
    }
}
