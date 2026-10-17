import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A message you sent, after OpenChamber's user bubble: at most `maxWidth`, 12px corners with
// the bottom-right one tucked in, on the shell's overlay tone (rows hover at 0.94, select at
// 0.86) rather than a new surface. Plain text as typed, so a short message gets a short bubble.
Rectangle {
    id: bubble
    property string text: ""
    property bool mono: false
    property real maxWidth: 600
    property var images: []
    property var viewer: null

    width: Math.min(bubble.maxWidth, Math.max(bubble.text.length ? Math.ceil(measure.implicitWidth) + 46 : 0, bubble.images.length ? 240 : 0))
    height: (bubble.text.length ? body.implicitHeight : -8) + (bubble.images.length ? pics.height + 10 : 0) + 26
    radius: 12
    bottomRightRadius: 4
    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.89)

    StyledText {
        id: measure
        visible: false
        text: bubble.text
        font.family: bubble.mono ? Appearance.font.family.monospace : Appearance.font.family.main
        font.pixelSize: 16
    }
    Thumbs {
        id: pics
        visible: bubble.images.length > 0
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        paths: bubble.images
        viewer: bubble.viewer
    }
    ClaudeText {
        id: body
        visible: bubble.text.length > 0
        anchors { left: parent.left; right: parent.right; top: bubble.images.length ? pics.bottom : parent.top; leftMargin: 20; rightMargin: 20; topMargin: bubble.images.length ? 8 : 13 }
        markdown: bubble.text
        plainText: true
        color: Appearance.colors.colInkMain
        font.family: bubble.mono ? Appearance.font.family.monospace : Appearance.font.family.main
    }
}
