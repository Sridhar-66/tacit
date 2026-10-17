pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The palette's three ways into the desktop's own apps: the projects Graphis remembers, the agent
 * sessions on this machine, and the places Pinax keeps. Each one reads the state the app itself
 * writes - code-projects.txt, AgentSessions, Files.places/pins - so there is nothing new to keep
 * in step, and each row runs the entry point the rest of the shell already uses (code-open,
 * AgentSessions.focus, Files.open).
 *
 * Same shape as PaletteSystemActions and PaletteWindows: ready-made LauncherSearchResults.
 */
Singleton {
    id: root

    readonly property string projectsTitle: Translation.tr("Projects")
    readonly property string sessionsTitle: Translation.tr("Sessions")
    readonly property string placesTitle: Translation.tr("Places")

    readonly property string home: FileUtils.trimFileProtocol(Directories.home)

    // The editor's own list, newest first, written by code.qml when a project opens.
    FileView {
        id: projectsFile
        path: FileUtils.trimFileProtocol(`${Directories.state}/user/code-projects.txt`)
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.projects = projectsFile.text().split("\n").filter(line => line.length > 0)
        onLoadFailed: root.projects = []
    }
    property var projects: []

    function short(path) {
        return path.startsWith(root.home) ? "~" + path.slice(root.home.length) : path;
    }

    // Filtered and cut to size BEFORE the rows are built: every discarded row would otherwise be
    // a parentless QObject nothing destroys (the same reason PaletteWindows slices first).
    function projectQuery(search: string, limit: int): var {
        const needle = (search ?? "").trim().toLowerCase();
        return root.projects.filter(path => needle.length === 0 || path.toLowerCase().includes(needle)).slice(0, limit).map(path => {
            const name = path.split("/").filter(part => part.length > 0).pop() ?? path;
            return resultComp.createObject(null, {
                name: name,
                comment: root.short(path),
                type: root.projectsTitle,
                verb: Translation.tr("Open"),
                iconName: "code",
                iconType: LauncherSearchResult.IconType.Material,
                keywords: [path],
                execute: () => Quickshell.execDetached([`${root.home}/.local/bin/code-open`, path]),
                actions: [resultComp.createObject(null, {
                        name: Translation.tr("Show in Files"),
                        iconName: "folder_open",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => Files.open(path, "")
                    })]
            });
        });
    }

    // Live sessions, as the notch knows them. Enter goes to the terminal the session runs in, or
    // hands it to Praxis when it has no window of its own (AgentSessions.focus).
    function sessionQuery(search: string, limit: int): var {
        const needle = (search ?? "").trim().toLowerCase();
        return AgentSessions.sessions.map(session => ({
            session: session,
            label: AgentSessions.label(session)
        })).filter(row => needle.length === 0
            || row.label.toLowerCase().includes(needle)
            || ((row.session.cwd ?? "") + "").toLowerCase().includes(needle)).slice(0, limit).map(row => {
            const session = row.session;
            return resultComp.createObject(null, {
                name: row.label,
                comment: Voice.facts([session.state ?? "", root.short((session.cwd ?? "") + "")]),
                type: root.sessionsTitle,
                verb: Translation.tr("Go"),
                iconName: "smart_toy",
                iconType: LauncherSearchResult.IconType.Material,
                execute: () => AgentSessions.focus(session),
                actions: [resultComp.createObject(null, {
                        name: Translation.tr("Open in Praxis"),
                        iconName: "smart_toy",
                        iconType: LauncherSearchResult.IconType.Material,
                        execute: () => Claude.openSession(session.id)
                    })]
            });
        });
    }

    // Files' own rail: the standard places, then the folders pinned to it (a pinned place once),
    // each under the name you gave it (Files.placeName).
    readonly property var places: Files.places.map(p => Object.assign({}, p, { "name": Files.placeName(p.path) })).concat(Files.pins.filter(path => !Files.places.some(x => x.path === path)).map(path => ({
        "name": Files.placeName(path),
        "path": path,
        "glyph": "folder"
    })))

    function placeQuery(search: string, limit: int): var {
        const needle = (search ?? "").trim().toLowerCase();
        return root.places.filter(place => needle.length === 0
            || place.name.toLowerCase().includes(needle)
            || place.path.toLowerCase().includes(needle)).slice(0, limit).map(place => resultComp.createObject(null, {
                name: place.name,
                comment: root.short(place.path),
                type: root.placesTitle,
                verb: Translation.tr("Open"),
                iconName: place.glyph,
                iconType: LauncherSearchResult.IconType.Material,
                keywords: [place.path],
                execute: () => Files.open(place.path, "")
            }));
    }

    Component {
        id: resultComp
        LauncherSearchResult {}
    }
}
