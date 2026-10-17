import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

// Widgets, beside the desktop menu: lock, then the widgets kept on the desktop (the same
// list as Settings > Desktop widgets).
Item {
    id: root
    implicitHeight: col.implicitHeight + 28

    readonly property var widgetList: [
        { "key": "clock", "name": "Clock", "icon": "schedule" },
        { "key": "weather", "name": "Weather", "icon": "partly_cloudy_day" },
        { "key": "worldClock", "name": "World clock", "icon": "public" },
        { "key": "resources", "name": "System resources", "icon": "monitor_heart" },
        { "key": "timers", "name": "Timers", "icon": "timer" },
        { "key": "images", "name": "Image converter", "icon": "photo_library" },
        { "key": "customImage", "name": "Custom image", "icon": "image" },
        { "key": "userCard", "name": "You card", "icon": "person" }
    ]

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verylarge
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.04)
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 14 }
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            MenuSwitch {
                glyph: Config.options.background.widgetsLocked ? "lock" : "lock_open"
                label: "Lock positions"
                on: Config.options.background.widgetsLocked
                onFlipped: value => Config.options.background.widgetsLocked = value
            }
        }
        MenuHairline {}
        StyledText {
            text: "On the desktop"
            font.pixelSize: Appearance.font.pixelSize.smallie
            color: Appearance.colors.colSubtext
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: root.widgetList
                MenuSwitch {
                    required property var modelData
                    glyph: modelData.icon
                    label: modelData.name
                    on: Config.options.background.widgets[modelData.key].enable
                    onFlipped: value => Config.options.background.widgets[modelData.key].enable = value
                }
            }
        }
    }
}
