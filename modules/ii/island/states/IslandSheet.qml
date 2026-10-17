pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.island

/**
 * The open sheet, laid out like boring.notch NotchHomeView with its default settings: the
 * player alone (calendar off, mirror off). Art 90px radius 13 (sizing/matters.swift:21-22) on
 * the left; title, artist, a full-width slider with times, and the control row centred under
 * them - default slots none / previous / play / next / none, 30px buttons, 40px play
 * (MusicControlButton.swift:defaultLayout, HoverButton.swift:20). Layout and sizes are theirs;
 * colours are ours.
 */
Item {
    id: root

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null && IslandController.mediaPresent
    readonly property string title: root.player?.trackTitle || "Unknown track"
    readonly property string artist: root.player?.trackArtist ?? ""
    // Browsers often publish no length (Firefox: mpris:length absent, and MprisPlayer.length
    // then mirrors the position). Without one there is no total and no fill, only the elapsed.
    readonly property bool lengthKnown: (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0
    readonly property real length: root.lengthKnown ? root.player.length : 0
    readonly property real position: root.player?.position ?? 0
    readonly property real progress: root.lengthKnown ? Math.max(0, Math.min(1, root.position / root.length)) : 0

    implicitWidth: 560
    implicitHeight: root.hasPlayer ? 150 : 72
    signal raise()
    // Text is being dragged over the notch: say what a drop does.
    property bool textDragOver: false

    // MprisPlayer.position only refreshes when asked; tick only while the sheet is up.
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    Item {
        id: playerArea
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 6
        anchors.bottomMargin: 16
        visible: root.hasPlayer

        Rectangle {
            id: artBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 90
            implicitHeight: 90
            radius: 13
            color: Appearance.colors.colLayer2

            MaterialSymbol {
                anchors.centerIn: parent
                visible: artImage.status !== Image.Ready
                text: "music_note"
                iconSize: 36
                color: Appearance.colors.colOnLayer2
            }
            Image {
                id: artImage
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                visible: status === Image.Ready
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 180
                sourceSize.height: 180
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBox.width
                        height: artBox.height
                        radius: artBox.radius
                    }
                }
            }
            // boring.notch AlbumArtView: the art shrinks to 0.85 while paused, and a click on
            // it opens the player (openMusicApp); ours raises the player's window.
            scale: MprisController.isPlaying ? 1 : 0.85
            Behavior on scale {
                Anim {}
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    IslandController.raisePlayer();
                    root.raise();
                }
            }
        }

        Column {
            id: infoColumn
            anchors.left: artBox.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                font.family: Appearance.font.family.title
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: IslandController.contentColor
            }
            StyledText {
                width: parent.width
                text: root.artist
                visible: root.artist.length > 0
                elide: Text.ElideRight
                font.family: Appearance.font.family.main
                font.pixelSize: 14
                color: IslandController.subtextColor
            }

            // boring.notch MusicSliderView: slider, then elapsed / total on one line, 36px block.
            // A click on the line seeks there when the player allows it.
            Item {
                width: parent.width
                height: 36

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 22
                    enabled: root.lengthKnown && (root.player?.canSeek ?? false)
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: event => {
                        root.player.position = Math.max(0, Math.min(1, event.x / width)) * root.length;
                    }
                }

                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    height: 4
                    radius: 2
                    color: Appearance.colors.colLayer2
                    Rectangle {
                        height: parent.height
                        width: parent.width * root.progress
                        radius: parent.radius
                        color: Appearance.colors.colPrimary
                        Behavior on width {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                }
                StyledText {
                    anchors.left: parent.left
                    anchors.top: track.bottom
                    anchors.topMargin: 5
                    text: TimerService.formatSeconds(Math.round(root.position))
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: 12
                    color: IslandController.subtextColor
                }
                StyledText {
                    anchors.right: parent.right
                    anchors.top: track.bottom
                    anchors.topMargin: 5
                    visible: root.lengthKnown
                    text: TimerService.formatSeconds(Math.round(root.length))
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: 12
                    color: IslandController.subtextColor
                }
            }

            // Slot toolbar: [shuffle] previous, play, next [repeat], centred. The outer
            // slots only exist when the player supports them (boring.notch's optional slots).
            Item {
                width: parent.width
                height: 40

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    IslandControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        visible: MprisController.shuffleSupported
                        glyph: "shuffle"
                        iconSize: 18
                        toggled: MprisController.hasShuffle
                        onActivated: MprisController.setShuffle(!MprisController.hasShuffle)
                    }
                    IslandControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        glyph: "skip_previous"
                        iconSize: 20
                        enabled: MprisController.canGoPrevious
                        onActivated: MprisController.previous()
                    }
                    IslandControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 40
                        implicitHeight: 40
                        glyph: MprisController.isPlaying ? "pause" : "play_arrow"
                        iconSize: 26
                        toggled: true
                        onActivated: MprisController.togglePlaying()
                    }
                    IslandControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        glyph: "skip_next"
                        iconSize: 20
                        enabled: MprisController.canGoNext
                        onActivated: MprisController.next()
                    }
                    IslandControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        visible: MprisController.loopSupported
                        glyph: MprisController.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                        iconSize: 18
                        toggled: MprisController.loopState !== MprisLoopState.None
                        onActivated: MprisController.setLoopState(
                            MprisController.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                            : MprisController.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                            : MprisLoopState.None)
                    }
                }
            }
        }
    }

    // boring.notch EmptyState: nothing playing.
    Row {
        anchors.centerIn: parent
        // only when the sheet has nothing else: with rows under it the line is noise
        visible: !root.hasPlayer && (IslandController.openRowsHeight === 0 || root.textDragOver)
        spacing: 8
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: root.textDragOver ? "smart_toy" : "music_off"
            iconSize: 20
            color: root.textDragOver ? Appearance.colors.colPrimary : IslandController.subtextColor
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.textDragOver ? "Drop to hand this to Praxis" : "Drop a file to park it · text to hand to Praxis"
            font.family: Appearance.font.family.main
            font.pixelSize: 15
            color: IslandController.subtextColor
        }
    }
}
