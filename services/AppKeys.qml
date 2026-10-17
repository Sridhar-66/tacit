pragma Singleton

import qs.services
import Quickshell

/**
 * What the keyboard does inside the desktop's own three apps, for the palette's Keybinds section
 * (Super+/), which otherwise knows compositor binds only. Praxis and Graphis are their own
 * Quickshell instances and cannot be asked while they are closed, so the tables live here.
 *
 * Each table is the app's key block written out: claude.qml's Shortcut list, code.qml's Shortcut
 * list, and the Keys.onPressed handler in modules/ii/files/FilesWindow.qml. A key changed there
 * is changed here.
 *
 * Shape: { mods, key, comment }, the same three fields services/HyprlandKeybinds.qml produces,
 * so the two lists merge without a second renderer.
 */
Singleton {
    id: root

    function table(app, pairs) {
        return pairs.map(pair => ({ "mods": [], "key": pair[0], "comment": `${app} · ${pair[1]}` }));
    }

    readonly property var praxis: root.table("Praxis", [
        ["Ctrl+P", Translation.tr("Search sessions")],
        ["Ctrl+N", Translation.tr("New session")],
        ["Ctrl+F", Translation.tr("Find in this conversation")],
        ["Ctrl+B", Translation.tr("Fold the session list")],
        ["Ctrl+Alt+B", Translation.tr("Show or hide the side panel")],
        ["Alt+Down", Translation.tr("Next session")],
        ["Alt+Up", Translation.tr("Previous session")],
        ["Ctrl+Q", Translation.tr("Hide the window (the instance stays)")]
    ])

    readonly property var graphis: root.table("Graphis", [
        ["Ctrl+P", Translation.tr("Go to a file in this project")],
        ["Ctrl+F", Translation.tr("Find in this file")],
        ["Ctrl+Shift+F", Translation.tr("Search the project")],
        ["Ctrl+G", Translation.tr("Go to a line")],
        ["F3", Translation.tr("Find again")],
        ["Shift+F3", Translation.tr("Find backwards")],
        ["Ctrl+S", Translation.tr("Save")],
        ["Ctrl+W", Translation.tr("Close this file")],
        ["Ctrl+B", Translation.tr("Show or hide the file tree")],
        ["Ctrl+O", Translation.tr("Another project")],
        ["Ctrl+PgDown", Translation.tr("Next file")],
        ["Ctrl+PgUp", Translation.tr("Previous file")],
        ["Alt+1…9", Translation.tr("Straight to that file")],
        ["Ctrl+Alt+T", Translation.tr("Type out changes")],
        ["Ctrl+Q", Translation.tr("Quit")]
    ])

    readonly property var pinax: root.table("Files", [
        ["Enter", Translation.tr("Open")],
        ["Backspace", Translation.tr("Up one folder")],
        ["Alt+Left", Translation.tr("Back")],
        ["Alt+Right", Translation.tr("Forward")],
        ["Alt+Up", Translation.tr("Up one folder")],
        ["Ctrl+L", Translation.tr("Edit the path")],
        ["Ctrl+F", Translation.tr("Filter this folder")],
        ["Ctrl+Shift+F", Translation.tr("Search the whole tree")],
        ["Ctrl+H", Translation.tr("Show hidden files")],
        ["Ctrl+A", Translation.tr("Select everything")],
        ["Ctrl+B", Translation.tr("Fold the rail")],
        ["Ctrl+1", Translation.tr("List")],
        ["Ctrl+2", Translation.tr("Grid")],
        ["Space", Translation.tr("Show or hide the preview")],
        ["F2", Translation.tr("Rename")],
        ["Delete", Translation.tr("Move to the trash")],
        ["Shift+Delete", Translation.tr("Delete for good")],
        ["Ctrl+C", Translation.tr("Copy")],
        ["Ctrl+X", Translation.tr("Cut")],
        ["Ctrl+V", Translation.tr("Paste")],
        ["Ctrl+Z", Translation.tr("Undo the last file job")],
        ["Ctrl+Shift+C", Translation.tr("Copy the path")],
        ["Ctrl+Shift+N", Translation.tr("New folder")],
        ["Ctrl+Shift+S", Translation.tr("Send to")],
        ["Ctrl+Shift+T", Translation.tr("Open a terminal here")],
        ["Ctrl+W", Translation.tr("Close the window")],
        [Translation.tr("any letter"), Translation.tr("Jump to a name")],
        ["Esc", Translation.tr("Clear the filter, then the selection")]
    ])

    readonly property var binds: root.praxis.concat(root.graphis, root.pinax)
}
