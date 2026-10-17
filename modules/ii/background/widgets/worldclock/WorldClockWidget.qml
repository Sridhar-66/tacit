import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas
import qs.modules.tacit.card
import qs.modules.tacit.overlay
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "worldClock"
    hoverEnabled: true

    readonly property int clockCount: Math.min(Math.max(root.configEntry.clockCount ?? 4, 1), 4)
    property var worldCities: WorldClock.entries
    property bool showingSettings: false

    onShowingSettingsChanged: GlobalStates.desktopWidgetKeyboardFocus = showingSettings
    Component.onDestruction: if (root.showingSettings) GlobalStates.desktopWidgetKeyboardFocus = false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    WidgetCard {
        id: card
        anchors.fill: parent
        configKey: "worldClock"
        glyph: "public"
        title: Translation.tr("World clock")

        buttons: [
            OverlayRoundButton {
                glyph: "tune"
                on: root.showingSettings
                onClicked: root.showingSettings = !root.showingSettings
            }
        ]

        ColumnLayout {
            width: parent.width
            spacing: 0

            // Times
            Repeater {
                model: root.showingSettings ? 0 : Math.min(root.worldCities.length, root.clockCount)
                delegate: TacitRow {
                    id: cityRow
                    required property int index
                    property var city: root.worldCities[index] ?? null
                    first: index === 0
                    glyph: (city?.isDay ?? true) ? "wb_sunny" : "bedtime"
                    label: city?.name ?? ""
                    labelWidth: 110
                    
                    TacitFigure {
                        Layout.fillWidth: true
                        text: cityRow.city?.offset ?? ""
                        font.pixelSize: 13
                        color: Appearance.colors.colSubtext
                        leftPadding: 8
                    }
                    TacitFigure {
                        text: cityRow.city?.time ?? ""
                        font.pixelSize: 18
                    }
                }
            }

            // Editor
            TacitRow {
                visible: root.showingSettings
                first: true
                glyph: "numbers"
                label: Translation.tr("Clocks")
                OverlayRoundButton {
                    glyph: "remove"
                    enabled: root.clockCount > 1
                    opacity: enabled ? 1 : 0.4
                    onClicked: Config.options.background.widgets.worldClock.clockCount = root.clockCount - 1
                }
                TacitFigure {
                    Layout.preferredWidth: 14
                    horizontalAlignment: Text.AlignHCenter
                    text: root.clockCount
                }
                OverlayRoundButton {
                    glyph: "add"
                    enabled: root.clockCount < 4
                    opacity: enabled ? 1 : 0.4
                    onClicked: Config.options.background.widgets.worldClock.clockCount = root.clockCount + 1
                }
            }
            Repeater {
                model: root.showingSettings ? 4 : 0
                delegate: TacitRow {
                    id: zoneRow
                    required property int index
                    rowHeight: 44
                    glyph: "schedule"
                    labelWidth: 14
                    label: (index + 1).toString()
                    StyledComboBoxSearch {
                        Layout.fillWidth: true
                        model: WorldClock.comboModel
                        textRole: "label"
                        colBackground: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93)
                        currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[zoneRow.index])
                        onActivated: idx => WorldClock.setTimezone(zoneRow.index, WorldClock.comboModel[idx].tz)
                    }
                }
            }
        }
    }
}
