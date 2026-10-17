import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The shell's own working indicator (MaterialLoadingIndicator: the M3 Expressive shape that
// morphs as it turns), small and without its container, in the text's tone.
MaterialLoadingIndicator {
    property bool active: true
    loading: active
    implicitSize: 18
    colBg: "transparent"
    colShape: Appearance.colors.colSubtext
}
