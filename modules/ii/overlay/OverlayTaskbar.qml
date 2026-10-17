pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.tacit.overlay

// The notch grown into the overlay's toolbar (modules/ii/island/IslandContent.qml): docked into the
// top edge, radius 14 closed and 24 open, cove 6, the ground of the overlay's windows (surfaceContainer
// at 0.96), the 34 px strip with the time in the centre and the battery in the right wing, and under it
// one labelled pill per widget, the open ones on the stronger wash. `grow` (0 = the closed notch, 1 =
// open) is driven by OverlayContent.
Item {
    id: root
    property real grow: 1

    readonly property var closedGeo: IslandController.geometryFor("idle")
    readonly property real stripHeight: 34
    readonly property real openWidth: Math.max(560, pillRow.implicitWidth + 48)
    readonly property real openHeight: stripHeight + 8 + 30 + 14

    visible: grow > 0.01
    width: closedGeo.w + (openWidth - closedGeo.w) * grow
    height: stripHeight + (openHeight - stripHeight) * grow

    DockedRect {
        anchors.fill: parent
        edge: "top"
        cornerRadius: root.closedGeo.r + (24 - root.closedGeo.r) * Math.min(1, Math.max(0, root.grow))
        fillet: 6
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.04)
    }
    // The toolbar's own ground: a click between pills must not reach the canvas and close the overlay.
    MouseArea {
        anchors.fill: parent
    }

    Item {
        id: contents
        anchors.fill: parent
        opacity: GlobalStates.overlayOpen ? 1 : 0
        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        StyledText {
            width: parent.width
            height: root.stripHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: DateTime.time
            font.family: Appearance.font.family.numbers
            font.variableAxes: Appearance.font.variableAxes.numbers
            font.pixelSize: 15
            color: Appearance.colors.colOnLayer0
        }
        Row {
            visible: Battery.available
            anchors.right: parent.right
            anchors.rightMargin: 20
            height: root.stripHeight
            spacing: 4
            property color tone: Battery.isLowAndNotCharging ? Appearance.colors.colError : Appearance.colors.colSubtext
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.isCharging ? "bolt" : "battery_android_full"
                fill: 1
                iconSize: 18
                color: parent.tone
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Battery.percentage * 100) + "%"
                font.family: Appearance.font.family.numbers
                font.variableAxes: Appearance.font.variableAxes.numbers
                font.pixelSize: 13
                color: parent.tone
            }
        }
        Row {
            id: pillRow
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.stripHeight + 8
            spacing: 6
            Repeater {
                model: OverlayContext.availableWidgets
                delegate: OverlayPill {
                    id: pill
                    required property var modelData
                    readonly property bool isOpen: Persistent.states.overlay.open.includes(modelData.identifier)
                    glyph: modelData.materialSymbol
                    label: modelData.label
                    on: pill.isOpen
                    onClicked: {
                        if (pill.isOpen)
                            Persistent.states.overlay.open = Persistent.states.overlay.open.filter(type => type !== pill.modelData.identifier);
                        else
                            Persistent.states.overlay.open = [...Persistent.states.overlay.open, pill.modelData.identifier];
                    }
                    onRightClicked: OverlayContext.requestCenter(pill.modelData.identifier)
                }
            }
        }
    }
}
