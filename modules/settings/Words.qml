import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Two to four choices as words, as Praxis's panel tabs: the chosen one in full ink and weight with a
 * sand line under it, the others quiet until the pointer is on them. ChoiceRow's side-by-side form
 * without the row around it, for a place where the label sits above. Arrows step when focused.
 */
Row {
    id: words
    property var options: []          // [{ value, label }]
    property var current: ""
    signal picked(var value)
    spacing: 0

    activeFocusOnTab: true
    readonly property bool keyboardFocus: words.activeFocus
        && (words.focusReason === Qt.TabFocusReason || words.focusReason === Qt.BacktabFocusReason)
    function step(by) {
        const i = words.options.findIndex(o => o.value === words.current);
        const j = Math.max(0, Math.min(words.options.length - 1, i < 0 ? 0 : i + by));
        if (j !== i)
            words.picked(words.options[j].value);
    }
    Keys.onLeftPressed: words.step(-1)
    Keys.onRightPressed: words.step(1)

    Repeater {
        model: words.options
        Rectangle {
            id: opt
            required property var modelData
            readonly property bool isCurrent: words.current === modelData.value
            implicitHeight: 32
            implicitWidth: optText.implicitWidth + 24
            radius: 8
            color: "transparent"
            border.width: opt.isCurrent && words.keyboardFocus ? 2 : 0
            border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.15)
            StyledText {
                id: optText
                anchors.centerIn: parent
                text: opt.modelData.label
                font.pixelSize: 15
                font.weight: opt.isCurrent ? Font.DemiBold : Font.Normal
                color: opt.isCurrent || optArea.containsMouse ? Appearance.colors.colInkMain : Tacit.inkSec
            }
            Rectangle {
                visible: opt.isCurrent
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                width: optText.implicitWidth
                height: 2
                radius: 1
                color: Appearance.colors.colPrimary
            }
            MouseArea {
                id: optArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: words.picked(opt.modelData.value)
            }
        }
    }
}
