import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell
import QtQuick
import QtQuick.Layouts

// Wallpaper & style, beside the desktop menu: the nine colour schemes and the change effect.
Item {
    id: root
    implicitHeight: col.implicitHeight + 28

    readonly property var schemes: [
        { "value": "auto", "name": "Auto", "icon": "auto_awesome" },
        { "value": "scheme-content", "name": "Content", "icon": "image" },
        { "value": "scheme-expressive", "name": "Expressive", "icon": "palette" },
        { "value": "scheme-fidelity", "name": "Fidelity", "icon": "equal" },
        { "value": "scheme-fruit-salad", "name": "Fruit Salad", "icon": "nutrition" },
        { "value": "scheme-monochrome", "name": "Monochrome", "icon": "invert_colors" },
        { "value": "scheme-neutral", "name": "Neutral", "icon": "tonality" },
        { "value": "scheme-rainbow", "name": "Rainbow", "icon": "gradient" },
        { "value": "scheme-tonal-spot", "name": "Tonal Spot", "icon": "lens" }
    ]
    readonly property var effects: [
        { "value": "", "name": "None", "icon": "block" },
        { "value": "magic", "name": "Magic", "icon": "auto_awesome" },
        { "value": "stripes", "name": "Stripes", "icon": "texture_minus" },
        { "value": "random", "name": "Random", "icon": "shuffle" }
    ]

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verylarge
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 0.04)
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 14 }
        spacing: 8

        StyledText {
            text: "Colour scheme"
            font.pixelSize: Appearance.font.pixelSize.smallie
            color: Appearance.colors.colSubtext
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 4
            columnSpacing: 4
            Repeater {
                model: root.schemes
                MenuTile {
                    required property var modelData
                    glyph: modelData.icon
                    label: modelData.name
                    on: Config.options.appearance.palette.type === modelData.value
                    onClicked: {
                        Config.options.appearance.palette.type = modelData.value;
                        // The script reads the type back with jq, and Config's write to
                        // config.json is debounced, so it would read the previous scheme.
                        // --type wins on the command line.
                        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--type", modelData.value]);
                    }
                }
            }
        }
        MenuHairline {}
        StyledText {
            text: "When the picture changes"
            font.pixelSize: Appearance.font.pixelSize.smallie
            color: Appearance.colors.colSubtext
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 4
            columnSpacing: 4
            Repeater {
                model: root.effects
                MenuTile {
                    required property var modelData
                    glyph: modelData.icon
                    label: modelData.name
                    on: Config.options.background.wallpaperAnimation === modelData.value
                    onClicked: Config.options.background.wallpaperAnimation = modelData.value
                }
            }
        }
    }
}
