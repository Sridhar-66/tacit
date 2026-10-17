import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

MaterialShape { // App icon
    id: root
    property var appIcon: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property bool isUrgent: urgency === NotificationUrgency.Critical
    property var image: ""
    property bool message: false   // a person's message: initials stand in for a missing picture
    property string appName: ""
    // The app's real icon as Android themes it: its one-colour glyph (the phone sends it) in Tacit's ink on the disc.
    // iconKind "glyph": `image` is that glyph; `glyph` is the app's glyph from another of its notifications, for a stack
    // of several, a row whose picture is lost, and the badge on a person's photo.
    property string iconKind: ""
    property string glyph: ""
    readonly property string glyphSource: root.iconKind === "glyph" && root.image != "" ? root.image : (root.image == "" ? root.glyph : "")
    property bool glyphBroken: false
    onGlyphSourceChanged: glyphBroken = false
    readonly property bool showGlyph: root.glyphSource !== "" && !root.glyphBroken
    // KDE Connect relays every phone app under its own icon name, so Gmail, Instagram and Reddit all showed the same
    // phone: a phone app is drawn as itself - its icon when the theme has one, else its initials in the disc
    readonly property bool fromPhone: root.appIcon === "kdeconnect" && root.appName !== ""
    readonly property string phoneIcon: {
        if (!root.fromPhone)
            return "";
        const a = root.appName.toLowerCase();
        for (const t of [a, a.replace(/\s+/g, "-"), a.split(" ")[0]]) {
            const p = Quickshell.iconPath(t, true);
            if (p !== "")
                return p;
        }
        return "";
    }
    readonly property string initialsText: root.message && NotificationUtils.initials(root.summary) !== "" ? NotificationUtils.initials(root.summary)
        : root.fromPhone ? NotificationUtils.initials(root.appName) : ""
    property real materialIconScale: 0.57
    property real appIconScale: 0.8
    property real smallAppIconScale: 0.49
    property real materialIconSize: implicitSize * materialIconScale
    property real appIconSize: implicitSize * appIconScale
    property real smallAppIconSize: implicitSize * smallAppIconScale

    implicitSize: 38 * scale
    // An app's own icon stands alone at full size: the theme's icons are shaped already, and a
    // disc behind them reads as a clipped ring. The disc is for our glyphs and for images.
    // An image that cannot load (a notification restored after a reload loses its provider
    // image) falls back to the glyph or initials instead of an empty disc. An app icon given
    // as a file path is drawn as an image, since the icon theme cannot resolve a path.
    property bool imageBroken: false
    readonly property bool appIconIsFile: /^(\/|file:)/.test(root.appIcon)
    readonly property string picture: root.image != "" && root.iconKind !== "glyph" ? root.image : (appIconIsFile ? root.appIcon : "")
    readonly property bool hasPicture: picture != "" && !imageBroken
    // an icon name the theme cannot resolve (kdeconnect here) counts as no icon
    readonly property string appIconPath: root.fromPhone ? root.phoneIcon : (root.appIcon != "" && !appIconIsFile) ? Quickshell.iconPath(root.appIcon, true) : ""
    readonly property bool hasAppIcon: appIconPath != ""
    readonly property bool ownIcon: !hasPicture && !showGlyph && hasAppIcon
    onPictureChanged: imageBroken = false
    shape: MaterialShape.Shape.Circle
    color: ownIcon ? "transparent" : Appearance.colors.colSecondaryContainer
    Loader {
        id: materialSymbolLoader
        active: !root.hasPicture && !root.hasAppIcon && !root.showGlyph
        anchors.fill: parent
        sourceComponent: root.initialsText !== "" ? initialsComponent : symbolComponent
    }
    Component {
        id: symbolComponent
        MaterialSymbol {
            text: {
                const defaultIcon = NotificationUtils.findSuitableMaterialSymbol("")
                const guessedIcon = NotificationUtils.findSuitableMaterialSymbol(root.summary)
                return (root.urgency == NotificationUrgency.Critical && guessedIcon === defaultIcon) ?
                    "priority_high" : guessedIcon
            }
            anchors.fill: parent
            color: isUrgent ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
            iconSize: root.materialIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Component {
        id: initialsComponent
        StyledText {
            anchors.fill: parent
            text: root.initialsText
            font.pixelSize: root.implicitSize * 0.4
            font.weight: Font.Medium
            color: Appearance.colors.colOnSecondaryContainer
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Loader {
        id: appIconLoader
        active: root.ownIcon
        anchors.centerIn: parent
        sourceComponent: IconImage {
            id: appIconImage
            implicitSize: root.implicitSize
            asynchronous: true
            source: root.appIconPath
        }
    }
    Loader {
        active: root.showGlyph && !root.hasPicture
        anchors.centerIn: parent
        // written out, not an inline component: the running shell's reload refused one ("not a type")
        sourceComponent: Image {
            readonly property real size: root.implicitSize * 0.56
            width: size
            height: size
            sourceSize: Qt.size(size * 2, size * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: root.glyphSource
            onStatusChanged: if (status === Image.Error) root.glyphBroken = true
            layer.enabled: true
            layer.effect: ColorOverlay { color: Appearance.colors.colOnSecondaryContainer }
        }
    }
    Loader {
        id: notifImageLoader
        active: root.hasPicture
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            Image {
                id: notifImage
                anchors.fill: parent
                readonly property int size: parent.width

                source: root.picture
                onStatusChanged: if (status === Image.Error) root.imageBroken = true
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                asynchronous: true

                width: size
                height: size
                sourceSize.width: size
                sourceSize.height: size

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: notifImage.size
                        height: notifImage.size
                        radius: Appearance.rounding.full
                    }
                }
            }
            // a person's photo carries the app's glyph, as a phone does
            Rectangle {
                visible: root.glyph !== ""
                anchors { bottom: parent.bottom; right: parent.right; margins: -2 }
                width: root.smallAppIconSize + 2
                height: width
                radius: width / 2
                color: Appearance.colors.colSecondaryContainer
                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.62
                    height: width
                    sourceSize: Qt.size(width * 2, width * 2)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: root.glyph
                    layer.enabled: true
                    layer.effect: ColorOverlay { color: Appearance.colors.colOnSecondaryContainer }
                }
            }
            Loader {
                id: notifImageAppIconLoader
                active: root.hasAppIcon && root.glyph === ""
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                sourceComponent: IconImage {
                    implicitSize: root.smallAppIconSize
                    asynchronous: true
                    source: root.appIconPath
                }
            }
        }
    }
}