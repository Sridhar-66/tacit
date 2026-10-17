import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * What this page is about, as it is right now, before any setting: the device playing, the
 * network you are on, what is connected. No slab: a headline on the page's edges (glyph on the
 * glyphs' edge, words on the labels'), as a side-panel page opens with its subject; the glyph takes
 * the accent while something is live.
 */
Item {
    id: root
    property string glyph: ""
    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""
    property bool live: true            // false quiets the glyph: nothing is connected or playing
    default property alias extra: below.data

    Layout.fillWidth: true
    Layout.topMargin: 24
    implicitHeight: column.implicitHeight + 4

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.rightMargin: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 22
                text: root.glyph
                iconSize: 22
                color: root.live ? Appearance.colors.colPrimary : Appearance.colors.colInkFaint
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    visible: root.eyebrow.length > 0
                    text: root.eyebrow
                    font.pixelSize: 13
                    color: Tacit.inkMeta
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colInkMain
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.subtitle.length > 0
                    text: root.subtitle
                    font.pixelSize: 15
                    color: Tacit.inkSec
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            id: below
            Layout.fillWidth: true
            Layout.leftMargin: 34
            visible: children.length > 0
            spacing: 8
        }
    }
}
