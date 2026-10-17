import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Words in the notch's strip: condensed 15; the point at weight 560 in the main ink, the rest at 450 in meta.
StyledText {
    property bool point: false
    font.family: Appearance.font.family.condensed
    font.pixelSize: 15
    font.variableAxes: ({ "wght": point ? 560 : 450 })
    color: point ? Tacit.inkMain : Tacit.inkMeta
    elide: Text.ElideRight
    maximumLineCount: 1   // one line; a text with line breaks (a script Claude asks to run) painted all of them
}
