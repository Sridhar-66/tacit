import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/** A number with a floor and a ceiling: two quiet buttons and the value between them. */
SettingRow {
    id: root
    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property string suffix: ""
    property var format: null           // value => text, for a unit the value is not stored in
    signal moved(int value)
    clickable: false
    Keys.onLeftPressed: if (root.value > root.from) root.moved(Math.max(root.from, root.value - root.stepSize))
    Keys.onRightPressed: if (root.value < root.to) root.moved(Math.min(root.to, root.value + root.stepSize))

    control: RowLayout {
        spacing: 2
        Step {
            glyph: "remove"
            enabled: root.enabled && root.value > root.from
            onPressed: root.moved(Math.max(root.from, root.value - root.stepSize))
        }
        StyledText {
            // fits "120 min", so the minus of every stepper on a page lines up
            Layout.preferredWidth: 64
            horizontalAlignment: Text.AlignHCenter
            text: root.format ? root.format(root.value) : `${root.value}${root.suffix}`
            font.pixelSize: 15
            font.features: { "tnum": 1 }
            color: Appearance.colors.colInkMain
        }
        Step {
            glyph: "add"
            enabled: root.enabled && root.value < root.to
            onPressed: root.moved(Math.min(root.to, root.value + root.stepSize))
        }
    }

    component Step: Rectangle {
        id: step
        property string glyph: ""
        signal pressed()
        implicitWidth: 28
        implicitHeight: 28
        radius: 8
        color: stepArea.containsMouse && step.enabled ? Appearance.m3colors.m3surfaceContainerHigh : "transparent"
        opacity: step.enabled ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 80 } }
        MaterialSymbol {
            anchors.centerIn: parent
            text: step.glyph
            iconSize: 18
            color: Appearance.colors.colInkMain
        }
        MouseArea {
            id: stepArea
            anchors.fill: parent
            enabled: step.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: step.pressed()
        }
    }
}
