import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.tacit.card
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "resources"
    hoverEnabled: true

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    readonly property var items: [
        { glyph: "memory", label: "CPU" },
        { glyph: "developer_board", label: "RAM" },
        { glyph: "hard_drive", label: "Disk" },
        { glyph: "battery_full", label: Translation.tr("Battery") }
    ]
    // Read inside each row, so a new figure changes a binding and not the model.
    function valueFor(i) {
        return [ResourceUsage.cpuUsage, ResourceUsage.memoryUsedPercentage, ResourceUsage.diskUsedPercentage, Battery.percentage][i];
    }

    WidgetCard {
        id: card
        anchors.fill: parent
        configKey: "resources"
        glyph: "monitor_heart"
        title: Translation.tr("System resources")

        ColumnLayout {
            width: parent.width
            spacing: 0

            Repeater {
                model: Battery.available ? 4 : 3
                delegate: TacitRow {
                    required property int index
                    first: index === 0
                    glyph: root.items[index].glyph
                    label: root.items[index].label
                    labelWidth: 64
                    TacitMeter {
                        Layout.fillWidth: true
                        value: root.valueFor(index)
                    }
                    TacitFigure {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(root.valueFor(index) * 100) + "%"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
