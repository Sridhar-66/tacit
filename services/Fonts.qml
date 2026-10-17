pragma Singleton

import Quickshell
import QtQuick
import "tacit_symbols.js" as TacitSymbolNames

Singleton {
    id: root
    // A failed FontLoader leaves an empty family name, and `??` in MaterialSymbol only catches
    // undefined - Qt then resolved "" to the default sans and every glyph in the shell rendered
    // as its ligature name. Fall back on emptiness, not on nullishness.
    property string iconMaterialFamily: (materialSymbolsLoader.status === FontLoader.Ready && materialSymbolsLoader.name.length > 0)
        ? materialSymbolsLoader.name
        : "Material Symbols Rounded"

    // Tacit's own symbols (~/dev/tacit-icons): two fonts typed by name like Material Symbols, one of lines and
    // one of filled forms. They cover the names listed in tacit_symbols.js; any other name, and every name while
    // either font has not loaded, keeps Material's glyph.
    readonly property bool tacitSymbolsReady: tacitLineLoader.status === FontLoader.Ready && tacitLineLoader.name.length > 0
        && tacitFillLoader.status === FontLoader.Ready && tacitFillLoader.name.length > 0

    function isTacitSymbol(name) {
        return root.tacitSymbolsReady && TacitSymbolNames.names[name] === 1;
    }

    function symbolFamily(name, filled) {
        if (root.isTacitSymbol(name))
            return filled ? tacitFillLoader.name : tacitLineLoader.name;
        return root.iconMaterialFamily;
    }

    FontLoader {
        id: tacitLineLoader
        source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/fonts")}/TacitSymbols.ttf`)
    }

    FontLoader {
        id: tacitFillLoader
        source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/fonts")}/TacitSymbolsFill.ttf`)
    }

    FontLoader {
        id: materialSymbolsLoader
        source: Qt.resolvedUrl(`${Quickshell.shellPath("assets/fonts")}/MaterialSymbolsRounded.ttf`)
        onStatusChanged: {
            if (materialSymbolsLoader.status === FontLoader.Error)
                console.error("[Fonts] Could not load assets/fonts/MaterialSymbolsRounded.ttf - icons will not render.")
        }
    }
}
