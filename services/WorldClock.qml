pragma Singleton
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // just fb fixme later
    readonly property var fallbackTimezones: [
        // O
        "Pacific/Auckland", "Pacific/Fiji", "Pacific/Guam", "Pacific/Honolulu", 
        "Pacific/Pago_Pago", "Pacific/Apia", "Pacific/Tahiti",
        "Australia/Sydney", "Australia/Melbourne", "Australia/Brisbane", 
        "Australia/Adelaide", "Australia/Darwin", "Australia/Perth",

        // A
        "Asia/Tokyo", "Asia/Seoul", "Asia/Shanghai", "Asia/Hong_Kong", 
        "Asia/Taipei", "Asia/Singapore", "Asia/Kuala_Lumpur", "Asia/Manila", 
        "Asia/Makassar", "Asia/Jakarta", "Asia/Bangkok", "Asia/Ho_Chi_Minh", 
        "Asia/Yangon", "Asia/Dhaka", "Asia/Kathmandu", "Asia/Kolkata", 
        "Asia/Karachi", "Asia/Tashkent", "Asia/Kabul", "Asia/Dubai", 
        "Asia/Muscat", "Asia/Tehran", "Asia/Baghdad", "Asia/Riyadh", 
        "Asia/Kuwait", "Asia/Qatar", "Asia/Jerusalem", "Asia/Beirut", 
        "Asia/Damascus", "Asia/Nicosia",

        // UE
        "Europe/Moscow", "Europe/Istanbul", "Europe/Athens", "Europe/Bucharest", 
        "Europe/Helsinki", "Europe/Kiev", "Europe/Minsk", "Europe/Warsaw", 
        "Europe/Vienna", "Europe/Prague", "Europe/Budapest", "Europe/Berlin", 
        "Europe/Paris", "Europe/Brussels", "Europe/Amsterdam", "Europe/Zurich", 
        "Europe/Madrid", "Europe/Rome", "Europe/London", "Europe/Dublin", 
        "Europe/Lisbon", "Atlantic/Reykjavik", "Atlantic/Azores",

        // A
        "Africa/Cairo", "Africa/Johannesburg", "Africa/Nairobi", "Africa/Addis_Ababa", 
        "Africa/Khartoum", "Africa/Lagos", "Africa/Kinshasa", "Africa/Algiers", 
        "Africa/Casablanca", "Africa/Tunis", "Africa/Accra", "Africa/Dakar",

        // SA
        "America/Sao_Paulo", "America/Rio_Branco", "America/Buenos_Aires", 
        "America/Cordoba", "America/Santiago", "America/Asuncion", "America/Montevideo", 
        "America/La_Paz", "America/Cuiaba", "America/Lima", "America/Bogota", 
        "America/Guayaquil", "America/Caracas",

        // CA
        "America/Panama", "America/Costa_Rica", "America/El_Salvador", 
        "America/Guatemala", "America/Managua", "America/Tegucigalpa", 
        "America/Havana", "America/Santo_Domingo", "America/Puerto_Rico", 
        "America/Jamaica",

        // NA
        "America/Mexico_City", "America/Monterrey", "America/Tijuana", 
        "America/New_York", "America/Miami", "America/Detroit", "America/Chicago", 
        "America/Houston", "America/Denver", "America/Phoenix", "America/Los_Angeles", 
        "America/Anchorage", "America/Vancouver", "America/Edmonton", 
        "America/Winnipeg", "America/Toronto", "America/Halifax", "America/St_Johns"
    ]

    readonly property var timezoneList: {
        if (typeof Intl !== "undefined" && typeof Intl.supportedValuesOf === "function") {
            try {
                return Intl.supportedValuesOf("timeZone")
            } catch (e) {
                return root.fallbackTimezones
            }
        }
        return root.fallbackTimezones
    }

    function labelFor(tz) {
        const parts = tz.split("/")
        const city = (parts[parts.length - 1] ?? tz).replace(/_/g, " ")
        const region = parts[0] ?? ""
        return region ? `${city} (${region})` : city
    }

    readonly property var comboModel: root.timezoneList.map(tz => ({ label: root.labelFor(tz), tz: tz, icon: "" }))

    property list<string> timezones: Config.options?.background?.widgets?.worldClock?.timezones ?? [
        "Australia/Sydney", "Asia/Tokyo", "Europe/London", "America/New_York"
    ]

    function setTimezone(index, tz) {
        let updated = root.timezones.slice()
        updated[index] = tz
        root.timezones = updated
        Config.options.background.widgets.worldClock.timezones = updated
    }

    onTimezonesChanged: root.refreshOffsets()
    Component.onCompleted: root.refreshOffsets()

    readonly property string ampmToken: {
        const fmt = Config.options?.time.format ?? "HH:mm"
        if (fmt.includes("AP")) return "AP"
        if (fmt.includes("ap")) return "ap"
        return ""
    }
    readonly property bool use24h: root.ampmToken === ""

    property var now: new Date()

    // Only the desktop widget reads any of this, and nothing it shows has seconds in it. This
    // used to wake the shell every second for the whole session and rebuild the formatted
    // entries for every city each time.
    readonly property bool widgetEnabled: Config.options?.background?.widgets?.worldClock?.enable ?? false

    Timer {
        id: minuteTick
        // Land on the minute, and re-read the offsets while we are here: they were refreshed
        // only every five minutes, so a city showed the pre-transition hour across a DST change.
        interval: 60000 - (Date.now() % 60000)
        running: root.widgetEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date()
            root.refreshOffsets()
            minuteTick.interval = 60000 - (Date.now() % 60000)
        }
    }

    // Empty, not four zeros: an offset that has not been read yet is unknown, and a zone that
    // cannot be resolved stays unknown instead of quietly reading as UTC.
    property var offsetsMinutes: []

    function refreshOffsets() {
        offsetProc.running = false
        offsetProc.running = true
    }

    Process {
        id: offsetProc
        // One argument per zone rather than one interpolated shell string. `date` prints +0000
        // for a name glibc does not know, so the zone file is what decides whether it exists.
        command: ["bash", "-c", 'for tz in "$@"; do if [ -e "/usr/share/zoneinfo/$tz" ]; then TZ="$tz" date +%z; else echo bad; fi; done', "_", ...root.timezones]
        stdout: StdioCollector {
            id: offsetCollector
            onStreamFinished: {
                const lines = offsetCollector.text.trim().split("\n")
                root.offsetsMinutes = lines.map(line => {
                    const m = line.trim().match(/^([+-])(\d{2})(\d{2})$/)
                    if (!m) return null
                    const sign = m[1] === "-" ? -1 : 1
                    return sign * (parseInt(m[2]) * 60 + parseInt(m[3]))
                })
            }
        }
    }

    function resolved(index) {
        const offsetMin = root.offsetsMinutes[index]
        return offsetMin !== undefined && offsetMin !== null
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n
    }

    function cityDate(index) {
        const offsetMin = root.offsetsMinutes[index] ?? 0
        return new Date(root.now.getTime() + offsetMin * 60000)
    }

    function timeStringFor(index) {
        if (!root.resolved(index)) return "--:--"
        const cd = root.cityDate(index)
        let h = cd.getUTCHours()
        let m = cd.getUTCMinutes()
        if (root.use24h) {
            return pad(h) + ":" + pad(m)
        }
        let h12 = h % 12
        if (h12 === 0) h12 = 12
        const base = pad(h12) + ":" + pad(m)
        if (root.ampmToken === "AP") return base + " " + (h >= 12 ? "PM" : "AM")
        return base + " " + (h >= 12 ? "pm" : "am")
    }

    function offsetLabelFor(index) {
        if (!root.resolved(index)) return Translation.tr("no such zone")
        const offsetMin = root.offsetsMinutes[index] ?? 0
        const sign = offsetMin >= 0 ? "+" : "-"
        const abs = Math.abs(offsetMin)
        const h = Math.floor(abs / 60)
        const m = abs % 60
        return "UTC" + sign + h + (m > 0 ? ":" + pad(m) : "")
    }

    function isDaytimeFor(index) {
        if (!root.resolved(index)) return true
        const cd = root.cityDate(index)
        const h = cd.getUTCHours()
        return h >= 6 && h < 18
    }

    readonly property var entries: root.timezones.map((tz, i) => ({
        tz: tz,
        name: root.labelFor(tz).split(" (")[0],
        time: root.timeStringFor(i),
        offset: root.offsetLabelFor(i),
        isDay: root.isDaytimeFor(i)
    }))
}
