//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    property int conflictCount: 0
    // The pidof probe is a separate process seconds after ConflictKiller's own check, so
    // the conflict can be gone by now -- then no group ever becomes visible, the count never
    // changes, and an empty window used to sit there until it was closed by hand.
    property int pendingChecks: 0
    onConflictCountChanged: root.closeIfNothingToAsk()
    onPendingChecksChanged: root.closeIfNothingToAsk()
    function closeIfNothingToAsk() {
        if (root.pendingChecks === 0 && root.conflictCount === 0) {
            root.close();
        }
    }

    property real contentPadding: 20
    visible: true
    onClosing: {
        Qt.quit()
    }
    title: Translation.tr("Shell conflicts killer")

    Component.onCompleted: {
        Config.readWriteDelay = 0;
        Config.blockWrites = true;
        MaterialThemeLoader.reapplyTheme();
    }

    // Praxis's permission card (modules/claude/PermissionCard.qml) as the window: 420 px wide,
    // as tall as its content.
    minimumWidth: 420
    maximumWidth: 420
    width: 420
    // Bound to the card, not to `height`: the window's own height would pin the size it opens at.
    readonly property real cardHeight: contentColumn.implicitHeight + contentPadding * 2
    minimumHeight: cardHeight
    maximumHeight: cardHeight
    height: cardHeight
    color: Appearance.m3colors.m3surfaceContainer

    component ConflictingProgramGroup: ColumnLayout {
        id: conflictGroup
        required property list<string> programs
        required property string description
        property string icon: "notifications_off"
        visible: false
        spacing: 10
        onVisibleChanged: {
            conflictCount += visible ? 1 : -1
        }

        signal alwaysSelected()

        Process {
            running: true
            command: ["pidof", ...conflictGroup.programs]
            Component.onCompleted: root.pendingChecks++
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    conflictGroup.visible = true
                }
                root.pendingChecks--
            }
        }

        RowLayout {
            spacing: 8
            MaterialSymbol {
                text: conflictGroup.icon
                iconSize: 17
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Stop %1?").arg(conflictGroup.programs.join(Translation.tr(" or ")))
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: conflictGroup.description
            wrapMode: Text.Wrap
            font.pixelSize: 14
            color: Appearance.colors.colSubtext
        }
        Row {
            spacing: 8
            Repeater {
                model: [
                    { label: Translation.tr("Stop it"), tone: 0.86, strong: true, always: false, stop: true },
                    { label: Translation.tr("Always stop it"), tone: 0.93, strong: false, always: true, stop: true },
                    { label: Translation.tr("Leave it"), tone: 1, strong: false, always: false, stop: false }
                ]
                delegate: Rectangle {
                    id: pill
                    required property var modelData
                    width: pillText.implicitWidth + 24
                    height: 30
                    radius: Appearance.rounding.full
                    color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, pillArea.containsMouse ? modelData.tone - 0.05 : modelData.tone)
                    StyledText {
                        id: pillText
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 14
                        font.weight: modelData.strong ? Font.DemiBold : Font.Normal
                        color: modelData.stop ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                    }
                    MouseArea {
                        id: pillArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pill.modelData.stop) {
                                Quickshell.execDetached(["killall", ...conflictGroup.programs])
                            }
                            if (pill.modelData.always) {
                                conflictGroup.alwaysSelected()
                            }
                            conflictGroup.visible = false
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        x: contentPadding
        y: contentPadding
        width: parent.width - contentPadding * 2

        ConflictingProgramGroup {
            id: notificationDaemons
            Layout.fillWidth: true
            programs: ["mako", "dunst"]
            description: Translation.tr("Conflicts with the shell's notification implementation")
            onAlwaysSelected: {
                Config.options.conflictKiller.autoKillNotificationDaemons = true
                Config.writeNow()
            }
        }
    }
}
