import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.tacit.card
import qs.modules.tacit.overlay

// The desktop widgets' card: Super+G's card (TacitCard) with the widget's rows as its body and a
// close button that switches the widget off, as its Settings switch does.
Item {
    id: root
    required property string configKey
    property string glyph: ""
    property string title: ""
    property real bodyWidth: 336
    property bool closable: true
    // Buttons between the title and the close button.
    property alias buttons: extraButtons.data
    default property alias content: body.data
    readonly property alias body: body

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    TacitCard {
        id: card
        anchors.fill: parent
        glyph: root.glyph
        title: root.title
        masked: false

        headerData: [
            Row {
                id: extraButtons
                spacing: 4
            },
            OverlayRoundButton {
                visible: root.closable
                glyph: "close"
                onClicked: Config.options.background.widgets[root.configKey].enable = false
            }
        ]

        Item {
            id: body
            Layout.fillWidth: true
            Layout.margins: 12
            implicitWidth: root.bodyWidth
            implicitHeight: childrenRect.height
        }
    }
}
