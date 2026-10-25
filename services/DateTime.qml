pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    // The time, ticking on the minute (on the second with seconds shown or the screen locked). Not Quickshell's
    // SystemClock: it schedules its next tick from local clock time, and in the hour that repeats when the clocks go
    // back that lands in the past, so it fired every millisecond for the whole hour (25 October 2026: 340 MB of log,
    // an hour of CPU). This waits on elapsed time, which never runs backwards.
    property QtObject clock: QtObject {
        id: clock
        property var date: new Date()
        readonly property int hours: date.getHours()
        readonly property int minutes: date.getMinutes()
        readonly property int seconds: date.getSeconds()
        readonly property int unit: (Config.options.time.secondPrecision || GlobalStates.screenLocked) ? 1000 : 60000
        onUnitChanged: { clock.date = new Date(); tick.restart(); }
    }
    Timer {
        id: tick
        // to the next whole second or minute, a few ms past it so the new value is already there
        interval: clock.unit - (Date.now() % clock.unit) + 5
        running: true
        repeat: false
        onTriggered: {
            clock.date = new Date();
            tick.interval = clock.unit - (Date.now() % clock.unit) + 5;
            tick.restart();
        }
    }

    property string time: Qt.locale().toString(clock.date, Config.options?.time.format ?? "hh:mm")
    property string shortDate: Qt.locale().toString(clock.date, Config.options?.time.shortDateFormat ?? "dd/MM")
    property string date: Qt.locale().toString(clock.date, Config.options?.time.dateWithYearFormat ?? "dd/MM/yyyy")
    property string longDate: Qt.locale().toString(clock.date, Config.options?.time.dateFormat ?? "dddd, dd/MM")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dddd, MMMM dd")
    readonly property bool use12HourFormat: (Config.options?.time.format ?? "hh:mm").toLowerCase().indexOf("ap") !== -1
    readonly property int hour24: clock.date.getHours()
    readonly property int hour12: (hour24 % 12 === 0) ? 12 : hour24 % 12
    readonly property string hourStr: (use12HourFormat ? hour12 : hour24).toString().padStart(2, "0")
    readonly property string minuteStr: Qt.locale().toString(clock.date, "mm")
    readonly property string digitH0: hourStr.charAt(0)
    readonly property string digitH1: hourStr.charAt(1)
    readonly property string digitM0: minuteStr.charAt(0)
    readonly property string digitM1: minuteStr.charAt(1)
    property string uptime: "0h, 0m"

    Timer {
        interval: 60000   // ms; uptime is shown to the minute. At 10 it read /proc/uptime 100x a second.
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fileUptime.reload()
    }

    FileView {
        id: fileUptime
        path: "/proc/uptime"
        // reload() lands here, not on the line after the call: read on the tick and the value
        // was always one tick old, and empty on the first.
        onLoaded: {
            const uptimeSeconds = Number(fileUptime.text().split(" ")[0] ?? 0);

            // Convert seconds to days, hours, and minutes
            const days = Math.floor(uptimeSeconds / 86400);
            const hours = Math.floor((uptimeSeconds % 86400) / 3600);
            const minutes = Math.floor((uptimeSeconds % 3600) / 60);

            // Build the formatted uptime string
            let formatted = "";
            if (days > 0)
                formatted += `${days}d`;
            if (hours > 0)
                formatted += `${formatted ? ", " : ""}${hours}h`;
            if (minutes > 0 || !formatted)
                formatted += `${formatted ? ", " : ""}${minutes}m`;
            uptime = formatted;
        }
    }
}