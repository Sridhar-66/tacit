import QtQuick
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    property int ink: 1
    iconSize: 20
    color: ink === 0 ? Appearance.colors.colInkMain
        : ink === 1 ? Appearance.colors.colInkSecondary : Appearance.colors.colInkMeta
}
