pragma Singleton

import Quickshell

/**
 * Starting apps, each in its own systemd scope (~/.local/bin/app-scope), instead of as a
 * child of the shell. The kernel and systemd-oomd then see apps one by one: memory is
 * taken from the app in the background, an app can be stopped without the desktop, and
 * focus-priority can favour the app in front. The way GNOME and KDE start apps.
 */
Singleton {
    id: root

    readonly property string runner: `${Quickshell.env("HOME")}/.local/bin/app-scope`

    /** A DesktopEntry or one of its DesktopActions. A terminal app keeps the caller's own path. */
    function launch(entry) {
        if (!entry)
            return;
        const command = entry.command ?? [];
        if (command.length === 0) {
            entry.execute();
            return;
        }
        // The runner lives outside this repo, and execDetached fails silently when it is not
        // there, so every dock, taskbar, launcher and palette launch did nothing at all on a
        // machine without it. Tested at launch time rather than once at startup because the
        // first click can come before any probe has answered; positional, so nothing is quoted
        // twice. Without the runner the app starts as it did before scopes, unisolated.
        const context = { command: ["bash", "-c", '[ -x "$0" ] && exec "$0" "$@"; shift; exec "$@"',
            root.runner, entry.id || command[0]].concat(command) };
        if ((entry.workingDirectory ?? "").length)
            context.workingDirectory = entry.workingDirectory;
        Quickshell.execDetached(context);
    }
}
