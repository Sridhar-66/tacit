import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * What Praxis needs before it can hold a conversation, said plainly where the conversation would
 * be. With a host that keeps accounts (praxis-composer-accounts-plan §2.15): while no agent has a
 * ready account, a heading over the fresh box, whose agent cove does the setting up; an existing
 * session or none shows as it is. With an older host, which runs every conversation through
 * Claude Code: Claude Code installed, and signed in.
 * The parent shows this while `shown`; `form` "claude" stands in for the conversation and its box.
 */
Item {
    id: notice
    property var accounts: null       // AccountsModel
    property string need: ""          // missing | signedOut: Claude Code, read when the host keeps no accounts
    property bool fresh: false        // the open session is a fresh one: only its box has an agent cove
    property string hostNote: ""      // reconnecting | unreachable | outdated, as the window's host line
    property real reserve: 0          // the height the box and its open cove take at the bottom
    signal recheck()
    signal setupRequested()           // no agent is ready: the fresh box opens its agent cove in setup form

    readonly property var link: notice.accounts?.link ?? null
    // the host has said which agents there are, on this connection or before it dropped
    readonly property bool heard: Object.keys(notice.accounts?.agents ?? {}).length > 0
    // every agent-host hello carries its version: none yet means no host has answered since start
    readonly property bool answered: (notice.link?.hostVersion ?? "").length > 0
    // While the host is away or reconnecting its last word stands, until it answers as an older host.
    readonly property bool managed: !!notice.accounts && (notice.accounts.available
        || (notice.heard && !(notice.link?.connected && notice.link?.protoMismatch)))
    // With an AccountsModel, Claude Code alone counts only once a host has answered without
    // accounts or none can be reached; until then whether the host keeps accounts is not known.
    readonly property bool claudeOnly: !notice.accounts || notice.answered || notice.hostNote === "unreachable"
    readonly property string want: notice.managed ? (notice.fresh && notice.heard && !notice.accounts.anyReady ? "setup" : "")
        : notice.need.length > 0 && notice.claudeOnly ? "claude" : ""
    // `want` once the event that changed it is over: the model takes a state push one property at
    // a time, and between its agents and its accounts no agent is ready
    property string settled: ""
    readonly property string form: notice.settled     // setup | claude | ""
    onWantChanged: Qt.callLater(notice.settle)
    function settle() { notice.settled = notice.want; }
    // the setup heading stays through its fade
    readonly property bool shown: notice.form === "claude" || setupText.opacity > 0
    onFormChanged: if (notice.form === "setup") notice.setupRequested()
    Component.onCompleted: Qt.callLater(notice.settle)

    readonly property string installCommand: "curl -fsSL https://claude.ai/install.sh | bash"
    property bool copied: false

    Item {
        id: room
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Math.max(0, parent.height - notice.reserve)
    }
    Column {
        id: setupText
        anchors.centerIn: room
        width: Math.min(460, parent.width - 48)
        spacing: 14
        opacity: notice.form === "setup" ? 1 : 0
        visible: opacity > 0
        // fades when an agent turns ready; leaving the fresh session takes it at once
        Behavior on opacity { enabled: notice.fresh; NumberAnimation { duration: 140 } }
        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Praxis needs an agent"
            font.pixelSize: 19
            font.weight: Font.Medium
            color: Appearance.colors.colInkMain
        }
        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.2
            text: "Praxis works through an agent on this computer. Sign in to one to start; the others can wait."
            font.pixelSize: 15
            color: Appearance.colors.colInkSecondary
        }
    }

    Column {
        visible: notice.form === "claude"
        anchors.centerIn: parent
        width: Math.min(460, parent.width - 48)
        spacing: 14
        MaterialSymbol {
            text: notice.need === "missing" ? "download" : "login"
            iconSize: 30
            color: Appearance.colors.colInkSecondary
        }
        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            text: notice.need === "missing" ? "Claude Code isn't installed" : "Sign in to Claude"
            font.pixelSize: 19
            font.weight: Font.Medium
            color: Appearance.colors.colInkMain
        }
        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.2
            text: notice.need === "missing"
                ? "Praxis holds your conversations through Claude Code. Install it with this command in a terminal, then check again."
                : "Claude Code is installed but not signed in. Sign in once in a terminal; Praxis notices on its own."
            font.pixelSize: 15
            color: Appearance.colors.colInkSecondary
        }
        // the install command, as a line you can copy
        Rectangle {
            visible: notice.need === "missing"
            width: parent.width
            height: 40
            radius: 14
            color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.92)
            StyledText {
                anchors { left: parent.left; leftMargin: 14; right: copyGlyph.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                text: notice.installCommand
                font.family: Appearance.font.family.monospace
                font.pixelSize: 13
                color: Appearance.colors.colInkMain
            }
            MaterialSymbol {
                id: copyGlyph
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: notice.copied ? "check" : "content_copy"
                iconSize: 16
                color: copyArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colInkSecondary
            }
            MouseArea {
                id: copyArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { Quickshell.clipboardText = notice.installCommand; notice.copied = true; copiedReset.restart(); }
            }
            Timer { id: copiedReset; interval: 1500; onTriggered: notice.copied = false }
        }
        Row {
            spacing: 8
            PillButton {
                visible: notice.need === "signedOut"
                text: "Sign in"
                onClicked: Quickshell.execDetached(["foot", "-T", "Sign in to Claude", "-e", "claude", "auth", "login"])
            }
            PillButton { text: "Check again"; onClicked: notice.recheck() }
        }
    }
}
