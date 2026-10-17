import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Numbers in the notch's strip: the time's own face and size, tabular, so they do not shift as they change.
StyledText {
    property bool point: false
    font.family: Appearance.font.family.numbers
    font.pixelSize: 16
    font.variableAxes: ({ "wght": point ? 560 : 500 })
    font.features: ({ "tnum": 1 })
    color: point ? Tacit.inkMain : Tacit.inkMeta
}
