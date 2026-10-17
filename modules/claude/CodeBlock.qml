import QtQuick
import QtQuick.Controls
import Quickshell
import org.kde.syntaxhighlighting
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A fenced code block: one quiet panel, highlighted with the editor's Martida theme, a copy
// button that shows on hover.
Rectangle {
    id: block
    property string code: ""
    property string lang: ""
    implicitHeight: text.implicitHeight + 28
    radius: Appearance.rounding.small
    // see-through like the message box: the window is translucent, a solid grey reads blue on it
    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95)
    border.width: 1
    border.color: ColorUtils.transparentize(Appearance.m3colors.m3outlineVariant, 0.3)

    HoverHandler { id: hover }

    TextEdit {

        // as StyledText: letters as designed, nothing snapped (fontconfig's full hinting widened Tacit Sans)

        font.hintingPreference: Font.PreferNoHinting
        id: text
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        readOnly: true
        selectByMouse: true
        text: block.code.replace(/\n+$/, "")
        wrapMode: TextEdit.Wrap
        font.family: Appearance.font.family.monospace
        font.pixelSize: 15
        color: Appearance.colors.colInkMain
        selectionColor: Appearance.colors.colSecondaryContainer
        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
    }
    SyntaxHighlighter {
        textEdit: text
        repository: Repository
        definition: Repository.definitionForName(block.lang || "plaintext")
        theme: {
            const t = Repository.theme("Martida");
            return t.name === "Martida" ? t : Repository.theme(Appearance.m3colors.darkmode ? "Material You Dark" : "Material You Light");
        }
    }

    MaterialSymbol {
        id: copy
        property bool done: false
        anchors { right: parent.right; top: parent.top; margins: 8 }
        visible: hover.hovered
        text: copy.done ? "check" : "content_copy"
        iconSize: 16
        color: copyArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
        MouseArea {
            id: copyArea
            anchors { fill: parent; margins: -6 }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Quickshell.clipboardText = text.text; copy.done = true; copyTimer.restart(); }
        }
        Timer { id: copyTimer; interval: 1500; onTriggered: copy.done = false }
    }
}
