import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.tacit.card
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "weather"
    hoverEnabled: true

    Component.onCompleted: Weather.viewers++
    Component.onDestruction: Weather.viewers--

    implicitHeight: card.implicitHeight
    implicitWidth: card.implicitWidth

    // The service gives "6:41:12 AM"; the card shows hours and minutes.
    function clockOnly(text) {
        return (text ?? "--").replace(/:\d{2}(?= |$)/, "");
    }
    readonly property var stats: [
        { glyph: "thermostat", label: Translation.tr("Feels like"), value: Weather.data?.tempFeelsLike ?? "--" },
        { glyph: "air", label: Translation.tr("Wind"), value: Weather.data?.wind ?? "--" },
        { glyph: "water_drop", label: Translation.tr("Humidity"), value: Weather.data?.humidity ?? "--" },
        { glyph: "wb_twilight", label: Translation.tr("Sunrise"), value: root.clockOnly(Weather.data?.sunrise) }
    ]

    WidgetCard {
        id: card
        anchors.fill: parent
        configKey: "weather"
        glyph: "partly_cloudy_day"
        title: Translation.tr("Weather")

        ColumnLayout {
            width: parent.width
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                spacing: 12
                MaterialSymbol {
                    text: Icons.getWeatherIcon(Weather.data?.wCode) ?? "cloud"
                    iconSize: 36
                    fill: 1
                    color: Appearance.colors.colPrimary
                }
                TacitFigure {
                    text: Weather.data?.temp ?? "--°"
                    font.pixelSize: 34
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    TacitCaption {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: Weather.data?.description ?? ""
                    }
                    TacitCaption {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: Weather.data?.city ?? "--"
                    }
                }
            }
            Repeater {
                model: root.stats
                delegate: TacitRow {
                    required property var modelData
                    glyph: modelData.glyph
                    label: modelData.label
                    TacitFigure {
                        text: modelData.value
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}
