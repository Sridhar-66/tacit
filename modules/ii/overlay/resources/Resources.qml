pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.tacit.overlay
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 300
    minimumHeight: 200
    property list<var> resources: [
        {
            "icon": "planner_review",
            "name": Translation.tr("CPU"),
            "history": ResourceUsage.cpuUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableCpuString
        },
        {
            "icon": "memory",
            "name": Translation.tr("RAM"),
            "history": ResourceUsage.memoryUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableMemoryString
        },
        {
            "icon": "swap_horiz",
            "name": Translation.tr("Swap"),
            "history": ResourceUsage.swapUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableSwapString
        },
    ]

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        readonly property int tab: Persistent.states.overlay.resources.tabIndex
        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 12

            // The three tabs as pills, the open one on the stronger wash.
            Row {
                spacing: 6
                Repeater {
                    model: root.resources.length
                    delegate: OverlayPill {
                        required property int index
                        glyph: root.resources[index].icon
                        label: root.resources[index].name
                        on: index === contentItem.tab
                        onClicked: Persistent.states.overlay.resources.tabIndex = index
                    }
                }
            }

            ResourceSummary {
                history: root.resources[contentItem.tab]?.history ?? []
                maxAvailableString: root.resources[contentItem.tab]?.maxAvailableString ?? "--"
            }
        }
    }

    component ResourceSummary: RowLayout {
        id: resourceSummary
        required property list<real> history
        required property string maxAvailableString
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 2
            StyledText {
                text: ((resourceSummary.history[resourceSummary.history.length - 1] ?? 0) * 100).toFixed(1) + "%"
                font {
                    family: Appearance.font.family.numbers
                    variableAxes: Appearance.font.variableAxes.numbers
                    pixelSize: Appearance.font.pixelSize.huge
                }
            }
            StyledText {
                text: Translation.tr("of %1").arg(resourceSummary.maxAvailableString)
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
            }
        }
        Rectangle {
            id: graphBg
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.small
            color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.93)
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: graphBg.width
                    height: graphBg.height
                    radius: graphBg.radius
                }
            }
            Graph {
                anchors.fill: parent
                values: resourceSummary.history
                points: ResourceUsage.historyLength
                alignment: Graph.Alignment.Right
            }
        }
    }
}
