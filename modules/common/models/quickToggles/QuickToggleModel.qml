import QtQuick

QtObject {
    // Textual info
    required property string name
    property string statusText
    property string tooltipText: ""
    property string icon: "close"

    // State
    property bool hasStatusText: true
    property bool available: true
    property bool toggled: false
    // An action the service has taken but not finished. The pill stays clickable while busy,
    // deliberately: the sections do the same (see BluetoothSection's row.busy), because
    // disabling a control is how a stuck operation becomes unrecoverable. The cue is the
    // statusText the tooltip already shows, plus a dimmed glyph.
    property bool busy: false

    // Interactions
    required property var mainAction
    property bool hasMenu: false
    property var altAction: null

    // Allow stuff like Processes to be declared freely
    default property list<QtObject> data
}
