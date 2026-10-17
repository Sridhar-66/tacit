pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common.functions
import QtCore
import QtQuick
import Quickshell

Singleton {
    // XDG Dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string genericCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]
    // $XDG_RUNTIME_DIR: 0700, per user, on tmpfs. What lives here is screen and clipboard
    // content, which sat in /tmp - a directory every account on the machine can read, and whose
    // names a stranger can pre-create.
    readonly property string runtime: StandardPaths.standardLocations(StandardPaths.RuntimeLocation)[0]
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0]
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]

    // Other dirs used by the shell, without "file://"
    property string assetsPath: Quickshell.shellPath("assets")
    property string scriptPath: Quickshell.shellPath("scripts")
    property string favicons: FileUtils.trimFileProtocol(`${Directories.cache}/media/favicons`)
    property string coverArt: FileUtils.trimFileProtocol(`${Directories.cache}/media/coverart`)
    property string tempImages: FileUtils.trimFileProtocol(`${Directories.runtime}/quickshell/media/images`)
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse`)
    property string shellConfigName: "config.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
	property string todoPath: FileUtils.trimFileProtocol(`${Directories.state}/user/todo.json`)
	property string notesPath: FileUtils.trimFileProtocol(`${Directories.state}/user/notes.txt`)
    property string desktopNotesPath: FileUtils.trimFileProtocol(`${Directories.state}/user/desktopnotes.txt`)
	property string conflictCachePath: FileUtils.trimFileProtocol(`${Directories.cache}/conflict-killer`)
    property string notificationsPath: FileUtils.trimFileProtocol(`${Directories.cache}/notifications/notifications.json`)
    property string generatedMaterialThemePath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/colors.json`)
    property string generatedWallpaperCategoryPath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/wallpaper/category.txt`)
    property string cliphistDecode: FileUtils.trimFileProtocol(`${Directories.runtime}/quickshell/media/cliphist`)
    property string screenshotTemp: FileUtils.trimFileProtocol(`${Directories.runtime}/quickshell/media/screenshot`)
    // Screen crops handed to Praxis (agent-host reads them back), so shared with ~/dev/agent-host
    property string agentHostRegion: FileUtils.trimFileProtocol(`${Directories.cache}/agent-host/region`)
    property string wallpaperSwitchScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/switchwall.sh`)
    property string userActions: FileUtils.trimFileProtocol(`${Directories.shellConfig}/actions`)
    property string recordScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/videos/record.sh`)
    property string userAvatarPathAccountsService: FileUtils.trimFileProtocol(`/var/lib/AccountsService/icons/${SystemInfo.username}`)
    property string userAvatarPathRicersAndWeirdSystems: FileUtils.trimFileProtocol(`${Directories.home}/.face`)
    property string userAvatarPathRicersAndWeirdSystems2: FileUtils.trimFileProtocol(`${Directories.home}/.face.icon`)
    property string userPresetsPath: FileUtils.trimFileProtocol(`${Directories.shellConfig}/presets`)
    property string presetsScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/presets.sh`)
    property string generatedLockMaterialThemePath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/colors-lock.json`)
    property string eqScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/eq/equalizer.sh`)
    property string eqStateDir: FileUtils.trimFileProtocol(`${Directories.state}/user/eq`)
    // states.json's directory and everything else under it (first_run.txt, todo.json, notes.txt,
    // desktopnotes.txt, generated/). A fresh user has none of it, and every writer assumes it.
    property string userStateDir: FileUtils.trimFileProtocol(`${Directories.state}/user`)
    // Cleanup on init
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${userPresetsPath}`])
        Quickshell.execDetached(["mkdir", "-p", `${shellConfig}`])
        Quickshell.execDetached(["mkdir", "-p", `${favicons}`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${coverArt}'; mkdir -p '${coverArt}'`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${cliphistDecode}'; mkdir -p '${cliphistDecode}'`])
        // A crash leaves the full-screen capture of a region selection behind, and with it a
        // picture of whatever was on screen. Nothing here survives a restart on purpose.
        Quickshell.execDetached(["bash", "-c", `rm -rf '${screenshotTemp}'; mkdir -p '${screenshotTemp}'`])
        Quickshell.execDetached(["mkdir", "-p", `${userActions}`])
        Quickshell.execDetached(["mkdir", "-p", `${eqStateDir}`])
        Quickshell.execDetached(["mkdir", "-p", `${userStateDir}`])
        Quickshell.execDetached(["rm", "-rf", `${tempImages}`])
    }
}
