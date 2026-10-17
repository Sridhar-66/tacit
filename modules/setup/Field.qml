import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A field: a soft neutral well, no outline (owner: outlines and focus lines "look bad"; a warm tint read as a forced
// brown on the dark sky). The label sits inside
// until the field is used, then stays small at the top; the one in use is a little lighter and has the caret.
// Password fields offer Show and say which keyboard they type with.
Item {
    id: f
    property string label
    property alias text: input.text
    property bool secret: false
    property string layout: ""
    property bool shown: false
    property string error: ""
    signal accepted()
    readonly property bool raised: input.text !== "" || input.activeFocus
    height: Look.px(68) + (error !== "" ? Look.px(32) : 0)
    function focusIn() { input.forceActiveFocus(); }
    Rectangle {
        id: well
        width: f.width; height: Look.px(68)
        radius: Look.px(20)
        color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.10 : (ma.containsMouse ? 0.075 : 0.06))
        Behavior on color { ColorAnimation { duration: 160 } }
        T {
            x: Look.px(26)
            y: f.raised ? Look.px(10) : (parent.height - height) / 2
            text: f.label
            font.pixelSize: f.raised ? Look.fs(14) : Look.fs(20)
            color: f.raised ? Look.sec : Look.meta
            Behavior on y { Anim { type: Anim.FastSpatial } }
        }
        TextInput {
            id: input
            x: Look.px(26); y: Look.px(31)
            width: parent.width - x - (f.secret ? Look.px(150) : Look.px(26))
            height: Look.px(28)
            color: Look.main
            selectionColor: Qt.rgba(0.95, 0.77, 0.60, 0.4)
            font.family: Appearance.font.family.main
            font.pixelSize: Look.fs(21)
            font.letterSpacing: f.secret && !f.shown ? Look.px(3) : 0
            echoMode: f.secret && !f.shown ? TextInput.Password : TextInput.Normal
            passwordCharacter: "●"
            cursorDelegate: Rectangle { width: 2; color: Look.light; visible: input.activeFocus
                SequentialAnimation on opacity { running: input.activeFocus; loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine } } }
            clip: true
            activeFocusOnTab: true
            onAccepted: f.accepted()
        }
        Row {
            visible: f.secret
            anchors.right: parent.right; anchors.rightMargin: Look.px(22); anchors.verticalCenter: parent.verticalCenter
            spacing: Look.px(14)
            T {
                text: f.shown ? "Hide" : "Show"; font.pixelSize: Look.fs(16); color: showMa.containsMouse ? Look.main : Look.sec
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { id: showMa; anchors.fill: parent; anchors.margins: -Look.px(8); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: f.shown = !f.shown }
            }
            Rectangle {
                visible: f.layout !== ""
                width: lt.width + Look.px(14); height: Look.px(24); radius: Look.px(7); color: Qt.rgba(1, 1, 1, 0.08)
                anchors.verticalCenter: parent.verticalCenter
                T { id: lt; anchors.centerIn: parent; text: f.layout.toUpperCase(); font.pixelSize: Look.fs(13); font.weight: Font.Medium; color: Look.sec }
            }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; cursorShape: Qt.IBeamCursor }
    }
    T { visible: f.error !== ""; x: Look.px(26); y: Look.px(78); text: f.error; font.pixelSize: Look.fs(17); color: Look.light }
}
