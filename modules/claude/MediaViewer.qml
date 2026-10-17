import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../viewer/Info.js" as Info

// One image at full size over the window: dimmed backdrop, the picture fitted, its plain title and
// Open (the default app for pictures) below, in the viewer's quiet text style. Click outside or Esc closes.
Rectangle {
    id: viewer
    property string path: ""
    // A picture the agent renders again keeps its path, and Image caches by URL: each opening asks
    // for the file under a new URL so what is shown is what is on disk now.
    property int rev: 0
    signal closed()
    function show(p) { viewer.rev++; viewer.path = p; viewer.visible = true; viewer.forceActiveFocus(); }
    function hide() { viewer.visible = false; viewer.closed(); }

    visible: false
    color: ColorUtils.transparentize("black", 0.3)
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    focus: visible
    Keys.onEscapePressed: viewer.hide()

    MouseArea { anchors.fill: parent; onClicked: viewer.hide() }
    // The picture itself is not "outside": the dismiss area above covers the whole window, so the
    // painted rect takes its own clicks and keeps them. Not the Image's box - that is letterboxed,
    // and the bands beside the picture are outside it.
    MouseArea {
        anchors.centerIn: pic
        width: pic.paintedWidth
        height: pic.paintedHeight
    }

    Image {
        id: pic
        anchors { centerIn: parent; verticalCenterOffset: -16 }
        width: parent.width - 96
        height: parent.height - 140
        source: viewer.path.length ? `file://${viewer.path}?${viewer.rev}` : ""
        fillMode: Image.PreserveAspectFit
        // a screenshot is decoded at whatever size it was taken: nothing here ever draws more than
        // this box, and the full decode of a 4K one is tens of megabytes held for one look
        sourceSize.width: Math.round(pic.width)
        sourceSize.height: Math.round(pic.height)
        asynchronous: true
        smooth: true
        mipmap: true
        scale: viewer.visible ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
        spacing: 14
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: viewer.path.length ? Info.title(viewer.path.split("/").pop(), "image", 0) : ""
            font.pixelSize: 15
            color: Appearance.colors.colInkMain
        }
        Item {
            width: openRow.implicitWidth + 12
            height: 32
            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.verysmall
                color: openArea.pressed ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.78)
                     : openArea.containsMouse ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.90) : "transparent"
            }
            Row {
                id: openRow
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "open_in_new"; iconSize: 18; color: Appearance.colors.colInkSecondary }
                StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Open"; font.pixelSize: 14; color: Appearance.colors.colInkSecondary }
            }
            MouseArea { id: openArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(`file://${viewer.path}`) }
        }
    }
}
