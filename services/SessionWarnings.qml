pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool packageManagerRunning: false
    property bool downloadRunning: false

    function refresh() {
        packageManagerRunning = false;
        downloadRunning = false;
        detectPackageManagerProc.running = false;
        detectPackageManagerProc.running = true;
        detectDownloadProc.running = false;
        detectDownloadProc.running = true;
    }

    Process {
        id: detectPackageManagerProc
        command: ["bash", "-c", "pidof yay paru dnf zypper apt apx xbps snap apk yum epsi pikman || ls /var/lib/pacman/db.lck"]
        onExited: (exitCode, exitStatus) => {
            root.packageManagerRunning = (exitCode === 0);
        }
    }

    Process {
        id: detectDownloadProc
        // Not `pidof curl wget`: any health check, script or agent satisfied that, and a
        // warning row that cries wolf teaches the user to ignore the one beside it. A partial
        // file in ~/Downloads, or one of the two tools that only ever download.
        command: ["bash", "-c", "pidof aria2c yt-dlp || find ~/Downloads -maxdepth 1 -type f \\( -name '*.part' -o -name '*.crdownload' \\) -print -quit | grep -q ."]
        onExited: (exitCode, exitStatus) => {
            root.downloadRunning = (exitCode === 0);
        }
    }
}
