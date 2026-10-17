import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.overlay.crosshair
import qs.modules.ii.overlay.volumeMixer
import qs.modules.ii.overlay.floatingImage
import qs.modules.ii.overlay.fpsLimiter
import qs.modules.ii.overlay.recorder
import qs.modules.ii.overlay.resources
import qs.modules.ii.overlay.notes

Item {
    id: root
    focus: true
    readonly property bool usePasswordChars: !PolkitService.flow?.responseVisible ?? true

    Keys.onPressed: (event) => { // Esc to close
        if (event.key === Qt.Key_Escape) {
            GlobalStates.overlayOpen = false;
        }
    }

    // The widget's entry in OverlayContext.availableWidgets when it is in the open list, else nothing.
    function entry(identifier) {
        return Persistent.states.overlay.open.includes(identifier) ? [OverlayContext.availableWidgets.find(w => w.identifier === identifier)] : [];
    }

    // The toolbar grows out of the notch on the notch's own curves: the open spring (500 ms) and the
    // close curve (450 ms) of IslandContent.qml. The widgets settle in with the optional zoom.
    readonly property real grow: GlobalStates.overlayOpen ? 1 : 0
    property real shownGrow: 0
    property bool ready: false
    // Set after creation: a Behavior does not run on values set while the item is being created.
    Component.onCompleted: Qt.callLater(() => {
        ready = true;
        shownGrow = grow;
        widgets.scale = 1;
    })
    onGrowChanged: {
        if (ready)
            shownGrow = grow;
    }
    Behavior on shownGrow {
        NumberAnimation {
            duration: GlobalStates.overlayOpen ? Appearance.animationCurves.expressiveDefaultSpatialDuration : 450
            easing.type: Easing.BezierSpline
            easing.bezierCurve: GlobalStates.overlayOpen ? Appearance.animationCurves.expressiveDefaultSpatial : Appearance.animationCurves.emphasizedDecel
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Appearance.colors.colScrim
        visible: Config.options.overlay.darkenScreen && opacity > 0
        opacity: GlobalStates.overlayOpen ? 1 : 0
        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    WidgetCanvas {
        anchors.fill: parent
        onClicked: GlobalStates.overlayOpen = false

        OverlayTaskbar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            grow: root.shownGrow
        }

        Item {
            id: widgets
            anchors.fill: parent
            scale: Config.options.overlay.openingZoomAnimation ? 1.08 : 1.000001
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
            }

            // One repeater per widget: the open list decides which exist. (A DelegateChooser over the
            // list put the recorder's body into the sound window once the list was reordered.)
            Repeater {
                model: ScriptModel {
                    values: root.entry("crosshair")
                    objectProp: "identifier"
                }
                delegate: Crosshair {
                }
            }
            Repeater {
                model: ScriptModel {
                    values: root.entry("floatingImage")
                    objectProp: "identifier"
                }
                delegate: FloatingImage {
                }
            }
            Repeater {
                model: ScriptModel {
                    values: root.entry("fpsLimiter")
                    objectProp: "identifier"
                }
                delegate: FpsLimiter {
                }
            }
            Repeater {
                model: ScriptModel {
                    values: root.entry("recorder")
                    objectProp: "identifier"
                }
                delegate: Recorder {
                }
            }
            Repeater {
                model: ScriptModel {
                    values: root.entry("resources")
                    objectProp: "identifier"
                }
                delegate: Resources {
                }
            }
            Repeater {
                model: ScriptModel {
                    values: root.entry("notes")
                    objectProp: "identifier"
                }
                delegate: Notes {
                }
            }
            Repeater {
                model: ScriptModel {
                    values: root.entry("volumeMixer")
                    objectProp: "identifier"
                }
                delegate: VolumeMixer {
                }
            }
        }
    }
}
