pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "calendar/calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// The control panel's bottom group: the collapsed line is the tab row (date, tasks, timer), the
// open one on a quiet pill, and the tab opens under it in place. Parts come from the panel
// (SidebarRightContent.qml: TogglePill, TextAction, Hairline), Praxis's answer buttons
// (PermissionCard.qml soft washes), the notification rows' pills under the text
// (NotificationActionButton.qml) and the notch's numerals (IslandHeader.qml, numbers font).
// Saved state is the old group's: Persistent.states.sidebar.bottomGroup.{tab,collapsed}; tasks go
// through Todo, the timers through TimerService, which the notch reads.
Item {
    id: root
    readonly property bool collapsed: Persistent.states.sidebar.bottomGroup.collapsed
    readonly property int tab: Persistent.states.sidebar.bottomGroup.tab
    property int monthShift: 0
    property int timerKind: 0          // 0 pomodoro, 1 stopwatch
    property bool showDone: false
    readonly property date today: {
        const d = DateTime.clock.date;
        return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }
    readonly property var viewing: CalendarLayout.getDateInXMonthsTime(monthShift, today)
    readonly property var layout: CalendarLayout.getCalendarLayout(viewing, monthShift === 0)
    readonly property var open: Todo.list.map((t, i) => Object.assign({}, t, {originalIndex: i})).filter(t => !t.done)
    readonly property var finished: Todo.list.map((t, i) => Object.assign({}, t, {originalIndex: i})).filter(t => t.done)
    readonly property string pomodoroText: TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
    readonly property string stopwatchText: root.hundredths(TimerService.stopwatchTime)
    readonly property string phase: TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")

    function hundredths(t) {
        const n = Math.floor(t);
        const s = Math.floor(n / 100);
        return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, "0")}.${(n % 100).toString().padStart(2, "0")}`;
    }

    function stepFocus(delta) {
        const v = Math.max(300, Math.min(3600, Config.options.time.pomodoro.focus + delta));
        Config.options.time.pomodoro.focus = v;
        if (!TimerService.pomodoroBreak)
            TimerService.pomodoroSecondsLeft = v;
    }

    function pick(i) {
        const g = Persistent.states.sidebar.bottomGroup;
        if (!g.collapsed && g.tab === i) {
            g.collapsed = true;
        } else {
            g.tab = i;
            g.collapsed = false;
        }
    }

    // In-place growth inside a content-sized panel: the standard curve, no overshoot (the
    // panel follows this height frame by frame).
    implicitHeight: view.implicitHeight
    onCollapsedChanged: foldHold.restart()
    Timer {
        id: foldHold
        interval: Appearance.animation.elementMove.duration
    }
    clip: true
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
        }
    }

    component Hairline: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.colors.colLayer0Border
    }
    // A round glyph button, the size of the panel's toggle pills (32 here, as TextAction).
    component IconPill: RippleButton {
        id: ip
        property string glyph: ""
        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: 16
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: ip.glyph
            iconSize: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Appearance.colors.colSubtext
        }
    }
    // Praxis's answer button, as the notification actions take it.
    component Wash: RippleButton {
        id: wash
        property string label: ""
        property real tone: 0.93
        implicitHeight: 30
        leftPadding: 12
        rightPadding: 12
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, tone)
        colBackgroundHover: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, tone - 0.05)
        contentItem: StyledText {
            horizontalAlignment: Text.AlignHCenter
            text: wash.label
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer0
        }
    }
    // A text choice: quiet disc when it is the one shown, as an "on" toggle pill.
    component Choice: RippleButton {
        id: ch
        property string label: ""
        property string glyph: ""
        property bool numeral: false
        property bool bright: false
        implicitWidth: chRow.implicitWidth + 24
        implicitHeight: 32
        buttonRadius: 16
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colLayer2
        colBackgroundToggledHover: Appearance.colors.colLayer2Hover
        contentItem: Row {
            id: chRow
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                visible: ch.glyph.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: ch.glyph
                iconSize: 18
                color: Appearance.colors.colSubtext
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: ch.label
                font.family: ch.numeral ? Appearance.font.family.numbers : Appearance.font.family.main
                font.pixelSize: ch.numeral ? 15 : Appearance.font.pixelSize.small
                color: ch.toggled || ch.bright ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
            }
        }
    }
    // The add line: a wash field, the "+" inside it.
    component AddLine: Rectangle {
        id: al
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 16
        color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 8
            MaterialSymbol {
                text: "add"
                iconSize: 18
                color: Appearance.colors.colSubtext
            }
            TextField {
                Layout.fillWidth: true
                background: null
                padding: 0
                color: Appearance.m3colors.m3onSurface
                placeholderText: Translation.tr("Add a task")
                placeholderTextColor: Appearance.colors.colSubtext
                font.pixelSize: 15
                onAccepted: {
                    if (text.length > 0) {
                        Todo.addTask(text);
                        text = "";
                    }
                }
            }
        }
    }
    // One month, seven columns.
    component MonthGrid: ColumnLayout {
        id: mg
        readonly property real cell: width / 7
        spacing: 0
        Row {
            Layout.fillWidth: true
            Repeater {
                model: CalendarLayout.weekDays
                delegate: StyledText {
                    required property var modelData
                    width: mg.cell
                    height: 26
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr(modelData.day)
                    font.pixelSize: 13
                    color: Appearance.colors.colSubtext
                }
            }
        }
        Repeater {
            model: 6
            delegate: Row {
                id: weekRow
                required property int index
                Layout.fillWidth: true
                Repeater {
                    model: 7
                    delegate: Item {
                        id: dayCell
                        required property int index
                        readonly property var d: root.layout[weekRow.index][index]
                        width: mg.cell
                        height: 32
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            visible: dayCell.d.today === 1
                            color: Appearance.colors.colLayer2
                        }
                        StyledText {
                            anchors.centerIn: parent
                            text: dayCell.d.day
                            font.family: Appearance.font.family.numbers
                            font.pixelSize: 15
                            font.weight: dayCell.d.today === 1 ? Font.DemiBold : Font.Normal
                            color: dayCell.d.today === 1 ? Appearance.colors.colPrimary
                                : dayCell.d.today === 0 ? Appearance.colors.colOnLayer0 : Appearance.colors.colOutlineVariant
                        }
                    }
                }
            }
        }
    }
    component MonthHead: RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Row {
            spacing: 6
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.viewing.toLocaleDateString(Qt.locale(), "MMMM")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.viewing.toLocaleDateString(Qt.locale(), "yyyy")
                font.family: Appearance.font.family.numbers
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
        Item {
            Layout.fillWidth: true
        }
        Wash {
            visible: root.monthShift !== 0
            label: Translation.tr("Today")
            onClicked: root.monthShift = 0
        }
        IconPill {
            glyph: "chevron_left"
            onClicked: root.monthShift--
        }
        IconPill {
            glyph: "chevron_right"
            onClicked: root.monthShift++
        }
    }
    // Pomodoro or stopwatch: the two doors, as text.
    component KindRow: RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Choice {
            label: Translation.tr("Pomodoro")
            toggled: root.timerKind === 0
            onClicked: root.timerKind = 0
        }
        Choice {
            label: Translation.tr("Stopwatch")
            toggled: root.timerKind === 1
            onClicked: root.timerKind = 1
        }
    }
    component TimerButtons: RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        Wash {
            tone: 0.86
            label: root.timerKind === 0
                ? (TimerService.pomodoroRunning ? Translation.tr("Pause") : (TimerService.pomodoroSecondsLeft === TimerService.focusTime) ? Translation.tr("Start") : Translation.tr("Resume"))
                : (TimerService.stopwatchRunning ? Translation.tr("Pause") : Translation.tr("Start"))
            onClicked: root.timerKind === 0 ? TimerService.togglePomodoro() : TimerService.toggleStopwatch()
        }
        Wash {
            visible: root.timerKind === 1
            label: Translation.tr("Lap")
            onClicked: TimerService.stopwatchRecordLap()
        }
        Wash {
            label: Translation.tr("Reset")
            enabled: root.timerKind === 0
                ? (TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration || TimerService.pomodoroCycle > 0 || TimerService.pomodoroBreak)
                : (TimerService.stopwatchTime > 0 || TimerService.stopwatchLaps.length > 0)
            onClicked: root.timerKind === 0 ? TimerService.resetPomodoro() : TimerService.stopwatchReset()
        }
    }

    // The group
    ColumnLayout {
        id: view
        width: parent.width
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Choice {
                label: Qt.locale().toString(DateTime.clock.date, "ddd d MMM")
                toggled: !root.collapsed && root.tab === 0
                bright: root.collapsed
                onClicked: root.pick(0)
            }
            Choice {
                readonly property int n: root.open.length
                label: n === 1 ? Translation.tr("1 task") : Translation.tr("%1 tasks").arg(n)
                toggled: !root.collapsed && root.tab === 1
                bright: root.collapsed
                onClicked: root.pick(1)
            }
            Choice {
                glyph: "timer"
                label: root.pomodoroText
                numeral: true
                toggled: !root.collapsed && root.tab === 2
                bright: root.collapsed
                onClicked: root.pick(2)
            }
            Item {
                Layout.fillWidth: true
            }
            IconPill {
                glyph: root.collapsed ? "expand_less" : "expand_more"
                onClicked: Persistent.states.sidebar.bottomGroup.collapsed = !root.collapsed
            }
        }
        // Kept while the height is still shrinking, so the fold does not blank first.
        Loader {
            Layout.fillWidth: true
            active: !root.collapsed || foldHold.running
            visible: active
            sourceComponent: root.tab === 0 ? calA : root.tab === 1 ? todoA : timerA
        }
    }

    Component {
        id: calA
        ColumnLayout {
            spacing: 2
            Hairline {
                Layout.bottomMargin: 6
            }
            MonthHead {}
            MonthGrid {
                Layout.fillWidth: true
            }
        }
    }
    Component {
        id: todoA
        ColumnLayout {
            spacing: 0
            Hairline {
                Layout.bottomMargin: 6
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Choice {
                    label: Translation.tr("%1 open").arg(root.open.length)
                    toggled: !root.showDone
                    onClicked: root.showDone = false
                }
                Choice {
                    label: Translation.tr("%1 done").arg(root.finished.length)
                    toggled: root.showDone
                    onClicked: root.showDone = true
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            AddLine {
                Layout.topMargin: 6
                Layout.bottomMargin: 6
            }
            Repeater {
                model: ScriptModel {
                    values: root.showDone ? root.finished : root.open
                }
                delegate: ColumnLayout {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    Hairline {}
                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        text: row.modelData.content
                        wrapMode: Text.Wrap
                        font.pixelSize: 15
                        color: Appearance.colors.colOnLayer0
                    }
                    RowLayout {
                        Layout.topMargin: 6
                        Layout.bottomMargin: 10
                        spacing: 6
                        Wash {
                            label: row.modelData.done ? Translation.tr("Undo") : Translation.tr("Done")
                            onClicked: row.modelData.done ? Todo.markUnfinished(row.modelData.originalIndex) : Todo.markDone(row.modelData.originalIndex)
                        }
                        Wash {
                            label: Translation.tr("Delete")
                            onClicked: Todo.deleteItem(row.modelData.originalIndex)
                        }
                    }
                }
            }
            StyledText {
                visible: (root.showDone ? root.finished : root.open).length === 0
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                text: root.showDone ? Translation.tr("Finished tasks will go here") : Translation.tr("Nothing here!")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
    }
    Component {
        id: timerA
        ColumnLayout {
            spacing: 0
            Hairline {
                Layout.bottomMargin: 6
            }
            KindRow {}
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                text: root.timerKind === 0 ? root.pomodoroText : root.stopwatchText
                font.family: Appearance.font.family.numbers
                font.pixelSize: 44
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: root.timerKind === 0
                text: `${root.phase} · ${Translation.tr("round %1").arg(TimerService.pomodoroCycle + 1)}`
                font.pixelSize: 13
                color: Appearance.colors.colSubtext
            }
            // The setting as a stepper: focus length in 5-minute steps, held while the timer runs (as the
            // old dial did).
            RowLayout {
                visible: root.timerKind === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                spacing: 6
                IconPill {
                    glyph: "remove"
                    enabled: !TimerService.pomodoroRunning
                    onClicked: root.stepFocus(-300)
                }
                StyledText {
                    Layout.preferredWidth: 96
                    horizontalAlignment: Text.AlignHCenter
                    text: `${Math.round(TimerService.focusTime / 60)} min`
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: 15
                    color: Appearance.colors.colOnLayer0
                }
                IconPill {
                    glyph: "add"
                    enabled: !TimerService.pomodoroRunning
                    onClicked: root.stepFocus(300)
                }
            }
            TimerButtons {
                Layout.topMargin: 14
                Layout.bottomMargin: 6
            }
            // Laps, newest first, one hairline row each.
            Repeater {
                model: ScriptModel {
                    values: root.timerKind === 1 ? TimerService.stopwatchLaps.map((v, i, arr) => arr[arr.length - 1 - i]) : []
                }
                delegate: ColumnLayout {
                    id: lap
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    Hairline {}
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        StyledText {
                            text: `${TimerService.stopwatchLaps.length - lap.index}.`
                            font.family: Appearance.font.family.numbers
                            font.pixelSize: 15
                            color: Appearance.colors.colSubtext
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: root.hundredths(lap.modelData)
                            font.family: Appearance.font.family.numbers
                            font.pixelSize: 15
                            color: Appearance.colors.colOnLayer0
                        }
                    }
                }
            }
        }
    }
}
