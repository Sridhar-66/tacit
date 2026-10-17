pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.tacit.overlay
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 310
    minimumHeight: 130

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 0

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                OverlayPill {
                    Layout.fillWidth: true
                    glyph: "screenshot_region"
                    label: Translation.tr("Screenshot region")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                    }
                }

                OverlayPill {
                    Layout.fillWidth: true
                    glyph: "photo_camera"
                    label: Translation.tr("Screenshot")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        // grim reads the framebuffer, so the wait has to outlive this widget: the
                        // overlay surface is still mapped for a compositor round trip after closing,
                        // and its scrim would end up in the shot.
                        const settle = (Appearance.animation.elementMoveFast.duration + Config.options.hacks.arbitraryRaceConditionDelay) / 1000;
                        Quickshell.execDetached(["bash", "-c", `sleep ${settle} && grim - | wl-copy`]);
                    }
                }

                OverlayPill {
                    Layout.fillWidth: true
                    glyph: "screen_record"
                    label: Translation.tr("Record region")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "recordWithSound"]);
                    }
                }

                OverlayPill {
                    Layout.fillWidth: true
                    glyph: "capture"
                    label: Translation.tr("Record screen")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]);
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Appearance.colors.colLayer0Border
            }
            RippleButton {
                Layout.topMargin: 6
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: foldersRow.implicitWidth + 20
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: {
                    GlobalStates.overlayOpen = false;
                    Qt.openUrlExternally(`file://${Config.options.screenRecord.savePath}`);
                }
                contentItem: Row {
                    id: foldersRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "folder_open"
                        iconSize: 18
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Open recordings folder")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                    }
                }
            }
        }
    }
}
