import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.tacit.card
import qs.modules.tacit.overlay
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "timers"
    hoverEnabled: true

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // One timer: label and glyph, the time, and a start/pause button. Right-click resets it.
    component TimerRow: Item {
        id: timerRow
        property string glyph: ""
        property string label: ""
        property string value: ""
        property bool running: false
        property bool first: false
        property real rowHeight: 40
        default property alias extras: extraRow.data
        signal toggled
        signal reset

        Layout.fillWidth: true
        implicitHeight: row.implicitHeight
        implicitWidth: row.implicitWidth

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: timerRow.reset()
        }
        TacitRow {
            id: row
            width: parent.width
            first: timerRow.first
            rowHeight: timerRow.rowHeight
            glyph: timerRow.glyph
            label: timerRow.label
            Row {
                id: extraRow
                spacing: 4
            }
            TacitFigure {
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignRight
                text: timerRow.value
                font.pixelSize: 16
            }
            OverlayRoundButton {
                glyph: timerRow.running ? "pause" : "play_arrow"
                on: timerRow.running
                onClicked: timerRow.toggled()
            }
        }
    }

    WidgetCard {
        id: card
        anchors.fill: parent
        configKey: "timers"
        glyph: "timer"
        title: Translation.tr("Timers")

        ColumnLayout {
            width: parent.width
            spacing: 0

            TimerRow {
                first: true
                glyph: TimerService.pomodoroBreak ? "coffee" : "self_improvement"
                label: TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
                value: TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
                running: TimerService.pomodoroRunning
                onToggled: TimerService.togglePomodoro()
                onReset: TimerService.resetPomodoro()
            }
            TimerRow {
                glyph: "timer"
                label: Translation.tr("Stopwatch")
                value: TimerService.formatSeconds(TimerService.stopwatchTime / 100)
                running: TimerService.stopwatchRunning
                onToggled: TimerService.toggleStopwatch()
                onReset: TimerService.stopwatchReset()
            }
            TimerRow {
                glyph: "hourglass_top"
                label: Translation.tr("Countdown")
                value: TimerService.formatSeconds(TimerService.countdownSecondsLeft)
                running: TimerService.countdownRunning
                onToggled: TimerService.toggleCountdown()
                onReset: TimerService.resetCountdown()
                Repeater {
                    model: [1, 5]
                    delegate: OverlayPill {
                        required property int modelData
                        implicitHeight: 26
                        label: "+" + modelData + "m"
                        onClicked: TimerService.addCountdownMinutes(modelData)
                    }
                }
            }
        }
    }
}
