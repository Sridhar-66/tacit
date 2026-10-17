import qs.modules.common
import qs.services
import QtQuick

StyledText {
    id: root

    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0

    property real resolvedFill: fill >= 0.5 ? 1.0 : 0.0
    // A name Tacit's symbols cover is drawn from them (the filled font when fill is on); the rest stay Material's.
    readonly property bool tacit: Fonts?.isTacitSymbol(root.text) ?? false

    renderType: Text.NativeRendering

    font {
        hintingPreference: Font.PreferNoHinting
        family: Fonts?.symbolFamily(root.text, resolvedFill > 0.5) ?? "Material Symbols Rounded"
        pixelSize: iconSize
        // Tacit's fonts have one weight: asking for more would make Qt embolden the outline.
        weight: (resolvedFill > 0.5 && !root.tacit) ? Font.DemiBold : Font.Normal
        variableAxes: {
            "FILL": resolvedFill,
            "opsz": iconSize,
        }
    }
}