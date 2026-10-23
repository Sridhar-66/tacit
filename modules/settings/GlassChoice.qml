import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * One look of the see-through setting as a picture: a small window over the real wallpaper at that
 * transparency, its name under it. Chosen like a wallpaper, by sight.
 */
Column {
    id: gl
    property string word: ""
    property string wallpaper: ""
    property color ground: Appearance.m3colors.m3surfaceContainerLow
    property real seeThrough: 0.15
    property bool blurred: true
    property bool chosen: false
    signal picked()
    spacing: 8

    activeFocusOnTab: true
    readonly property bool keyboardFocus: gl.activeFocus
        && (gl.focusReason === Qt.TabFocusReason || gl.focusReason === Qt.BacktabFocusReason)
    Keys.onReturnPressed: gl.picked()
    Keys.onEnterPressed: gl.picked()
    Keys.onSpacePressed: gl.picked()

    Rectangle {
        width: 120
        height: 76
        radius: 10
        color: "transparent"
        border.width: gl.chosen || gl.keyboardFocus ? 2 : 0
        border.color: gl.chosen ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)

        Item {
            id: pic
            anchors.fill: parent
            anchors.margins: gl.chosen ? 4 : 0
            visible: false
            Image {
                id: wall
                anchors.fill: parent
                // escaped, as Miniature's: a '#', '?' or '%' in the picture's name left the tile empty
                source: gl.wallpaper.length > 0 ? "file://" + gl.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
                sourceSize.width: 256
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Item {
                id: pane
                x: 16
                y: 12
                width: parent.width - 32
                height: parent.height - 24
                // the blur is clipped square; on the wallpaper its corners don't show under the rounded tint
                Item {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    MultiEffect {
                        x: -pane.x - 1
                        y: -pane.y - 1
                        width: pic.width
                        height: pic.height
                        source: wall
                        blurEnabled: true
                        blur: gl.blurred ? 1 : 0
                        blurMax: 24
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: ColorUtils.transparentize(gl.ground, gl.seeThrough)
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.m3colors.m3outlineVariant, 0.5)
                }
                Column {
                    x: 8
                    y: 9
                    spacing: 5
                    Repeater {
                        model: [44, 32, 50]
                        Rectangle {
                            required property int modelData
                            width: modelData
                            height: 3
                            radius: 1.5
                            color: ColorUtils.transparentize(Appearance.colors.colInkMain, 0.7)
                        }
                    }
                }
            }
        }
        Rectangle {
            id: picMask
            anchors.fill: pic
            radius: gl.chosen ? 6 : 10
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: pic
            source: pic
            maskEnabled: true
            maskSource: picMask
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: gl.picked()
        }
    }
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: gl.word
        font.pixelSize: 15
        color: gl.chosen ? Appearance.colors.colInkMain : Tacit.inkMeta
    }
}
