import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// After a reload the notch says "T A C I T  updated" (IslandController.afterReload,
// IslandHeader.qml). This popup is drawn only when that cannot happen: after a FAILED reload, which
// keeps the old shell running and draws this in the notch's shape, frost and type over it with
// Quickshell's error, and after a reload with the notch switched off. It grows out of the notch's
// current width and folds back into it. Click to dismiss; pointing at it holds it.
Scope {
	id: root
	property bool failed
	property string errorString

	Connections {
		target: Quickshell

		function onReloadCompleted() {
			root.failed = false;
			root.errorString = "";
			// The notch says it (IslandController.afterReload: "T A C I T  updated"). Without the
			// notch, the strip below says it.
			if (IslandController.enabled)
				IslandController.noteReload();
			else
				afterNotch.restart();
		}

		function onReloadFailed(error: string) {
			// Close any existing popup before making a new one.
			popupLoader.active = false;
			root.failed = true;
			root.errorString = error;
			popupLoader.loading = true;
		}
	}

	// A reload rebuilds the notch too; it is gone for about 300 ms. The strip waits for it, so it
	// grows out of the notch instead of appearing on its own. A failed reload keeps the old shell
	// and its notch, so that one shows at once.
	Timer {
		id: afterNotch
		interval: 450
		onTriggered: popupLoader.loading = true
	}

	// Kept in a loader because it isn't needed most of the time.
	LazyLoader {
		id: popupLoader

		PanelWindow {
			id: popup
			// Over the notch, not under the band it reserves (exclusive zone 0 was placed below it).
			exclusionMode: ExclusionMode.Ignore
			WlrLayershell.layer: WlrLayer.Overlay
			anchors.top: true
			margins.top: Config.options.island.topMargin
			implicitWidth: 560 + 2 * sheet.fillet
			implicitHeight: root.failed ? 34 + body.implicitHeight : 34
			WlrLayershell.namespace: "quickshell:reloadPopup"
			color: "transparent"
			mask: Region { item: sheet }

			// The notch's width as it is now (IslandContent.qml headerGeometry), so the strip starts
			// as the notch and ends as it.
			readonly property real notchWidth: IslandController.geometryFor(IslandController.transientShowing ? IslandController.transientState : "idle").w
			property bool shown: false
			Component.onCompleted: shown = true
			Timer {
				id: fold
				interval: 450
				onTriggered: popupLoader.active = false
			}
			function close() {
				popup.shown = false;
				fold.restart();
			}

			Item {
				id: sheet
				readonly property real fillet: 6
				readonly property real openWidth: root.failed ? 560 : Math.max(250, popup.notchWidth)
				width: popup.shown ? openWidth : popup.notchWidth
				height: popup.shown && root.failed ? 34 + body.implicitHeight : 34
				x: (popup.width - width) / 2
				// the notch's open and close curves (IslandContent.qml:153-158)
				readonly property int duration: popup.shown ? Appearance.animationCurves.expressiveDefaultSpatialDuration : 450
				readonly property list<real> curve: popup.shown ? Appearance.animationCurves.expressiveDefaultSpatial : Appearance.animationCurves.emphasizedDecel
				Behavior on width {
					NumberAnimation { duration: sheet.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: sheet.curve }
				}
				Behavior on height {
					NumberAnimation { duration: sheet.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: sheet.curve }
				}
				clip: true

				DockedRect {
					anchors.fill: parent
					cornerRadius: root.failed && popup.shown ? 24 : 14
					fillet: sheet.fillet
					color: Appearance.colors.colPanelFrost
				}

				MouseArea {
					id: mouseArea
					anchors.fill: parent
					hoverEnabled: true
					onPressed: popup.close()
				}

				// The strip: a tone colours the glyph and the words, never the body (IslandController).
				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					height: 34
					spacing: 8
					opacity: popup.shown ? 1 : 0
					Behavior on opacity {
						animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
					}
					MaterialSymbol {
						anchors.verticalCenter: parent.verticalCenter
						text: root.failed ? "error" : "check_circle"
						iconSize: 18
						color: root.failed ? Appearance.colors.colError : Appearance.m3colors.m3success
					}
					StyledText {
						anchors.verticalCenter: parent.verticalCenter
						text: root.failed ? "Tacit couldn't update" : "Tacit updated"
						font.pixelSize: Appearance.font.pixelSize.smallish
						color: root.failed ? Appearance.colors.colError : Appearance.colors.colOnLayer0
					}
				}

				Column {
					id: body
					visible: root.failed
					opacity: popup.shown ? 1 : 0
					x: 20
					y: 34
					width: 560 - 40
					topPadding: 4
					bottomPadding: 16
					spacing: 10
					StyledText {
						width: parent.width
						text: root.errorString
						wrapMode: Text.Wrap
						font.family: Appearance.font.family.monospace
						font.pixelSize: Appearance.font.pixelSize.smallie
						color: Appearance.colors.colOnLayer0
					}
					StyledText {
						text: "Still running the last version · click to dismiss"
						font.pixelSize: Appearance.font.pixelSize.smaller
						color: Appearance.colors.colSubtext
					}
				}

				// The time left: a hairline in the tone that shrinks, held while pointed at.
				Rectangle {
					id: bar
					anchors.horizontalCenter: parent.horizontalCenter
					y: sheet.height - 5
					height: 2
					radius: 1
					color: ColorUtils.transparentize(root.failed ? Appearance.colors.colError : Appearance.m3colors.m3success, 0.4)

					PropertyAnimation {
						id: anim
						target: bar
						property: "width"
						from: sheet.openWidth - 60
						to: 0
						duration: root.failed ? 10000 : 1000
						onFinished: popup.close()
						paused: mouseArea.containsMouse
					}
				}

				Component.onCompleted: anim.start()
			}
		}
	}
}
