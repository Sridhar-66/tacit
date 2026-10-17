import QtQuick

// The other way (Back, Not now): a quieter ring, so it still reads as a button.
Item {
    id: q
    property string text
    signal clicked()
    width: qt.width + Look.px(56)
    height: Look.px(50)
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, q.activeFocus ? 0.09 : ma.containsMouse ? 0.05 : 0)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.42)
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    T { id: qt; anchors.centerIn: parent; text: q.text; font.pixelSize: Look.fs(18); color: q.activeFocus || ma.containsMouse ? Look.main : Look.sec }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: q.clicked() }
}
