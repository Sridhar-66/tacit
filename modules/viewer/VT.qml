import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Viewer text: one of the four ink levels, never an opacity on text.
StyledText {
    property int ink: 0   // 0 main, 1 secondary, 2 meta, 3 faint
    color: ink === 0 ? Appearance.colors.colInkMain
        : ink === 1 ? Appearance.colors.colInkSecondary
        : ink === 2 ? Appearance.colors.colInkMeta : Appearance.colors.colInkFaint
    font.pixelSize: 14
}
