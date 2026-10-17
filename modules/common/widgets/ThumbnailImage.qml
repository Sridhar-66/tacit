import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Thumbnail image. It currently generates to the right place at the right size, but does not handle metadata/maintenance on modification.
 * See Freedesktop's spec: https://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property string thumbnailPath: {
        if (sourcePath.length == 0) return;
        const resolvedUrlWithoutFileProtocol = FileUtils.trimFileProtocol(`${Qt.resolvedUrl(sourcePath)}`);
        const encodedUrlWithoutFileProtocol = resolvedUrlWithoutFileProtocol.split("/").map(part => encodeURIComponent(part)).join("/");
        const md5Hash = Qt.md5(`file://${encodedUrlWithoutFileProtocol}`);
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`;
    }
    source: thumbnailPath

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onSourceSizeChanged: {
        if (!root.generateThumbnail) return;
        root.requestGeneration();
    }
    // a size set once (the gallery's strip) never changes, so ask once at the start too; when the thumbnail is
    // already there this is one quick test
    Component.onCompleted: if (root.generateThumbnail) root.requestGeneration()

    // A slot from Images caps how many magick processes run at once across the shell; a folder
    // of photos spawns one per visible tile otherwise. Held from spawn to exit, and handed back
    // if the tile is destroyed first so a scrolled-away cell cannot hold the cap down.
    property bool holdsThumbnailSlot: false
    function requestGeneration() {
        if (thumbnailGeneration.running) return;
        if (!root.holdsThumbnailSlot) {
            if (!Images.requestThumbnailSlot(root)) return;
            root.holdsThumbnailSlot = true;
        }
        thumbnailGeneration.running = true;
    }
    function releaseThumbnailSlot() {
        if (!root.holdsThumbnailSlot) return;
        root.holdsThumbnailSlot = false;
        Images.releaseThumbnailSlot();
    }
    Component.onDestruction: root.releaseThumbnailSlot()

    Process {
        id: thumbnailGeneration
        // argv, not a shell string: a file name is attacker-controlled input here (this runs
        // for every visible file the moment a picture-heavy folder opens in grid view), and
        // a name containing a quote used to end up as shell words. The exit codes are the
        // caller's contract: 0 = the thumbnail was already there, 1 = it was just made.
        // -nt is the spec's Thumb::MTime in cheaper form: a cached thumbnail older than the
        // picture is remade, so an edited or replaced file stops showing its old self.
        command: {
            const maxSize = Images.thumbnailSizes[root.thumbnailSizeName];
            const thumb = FileUtils.trimFileProtocol(root.thumbnailPath);
            const src = FileUtils.trimFileProtocol(root.sourcePath);
            return ["bash", "-c",
                'set -- "$1" "$2" "$3"; [ -f "$2" ] && [ ! "$1" -nt "$2" ] && exit 0; mkdir -p "$(dirname -- "$2")" || exit 0; magick "$1" -resize "$3" "$2" && exit 1; exit 0',
                "thumbgen", src, thumb, `${maxSize}x${maxSize}`
            ]
        }
        onExited: (exitCode, exitStatus) => {
            root.releaseThumbnailSlot();
            // reload when it was just made, or when another tile made it after this one had looked and failed
            if (exitCode === 1 || root.status === Image.Error) {
                root.source = "";
                root.source = root.thumbnailPath; // Force reload
            }
        }
    }
}
