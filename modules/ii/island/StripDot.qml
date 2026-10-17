import QtQuick
import qs.modules.common

// A mark beside a name: meta, or sand for an agent at work (the one meaning light has in the notch).
Rectangle {
    property bool sand: false
    implicitWidth: 6
    implicitHeight: 6
    radius: 3
    color: sand ? Appearance.colors.colPrimary : Tacit.inkMeta
}
