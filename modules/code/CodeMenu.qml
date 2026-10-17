import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * A right click's choices, drawn at the pointer inside the window (never a window of its own): the words in the
 * main ink, each one's key in the meta ink beside it, a hairline between groups. Arrows move, Enter picks, Esc or a
 * click anywhere else closes it.
 * items: [{ label, key, run, line }] - `line` draws the hairline above that row.
 */
Item {
    id: menu

    property var items: []
    property int at: 0
    signal closed()

    anchors.fill: parent
    visible: false

    // as wide as its widest row: a word, a gap of at least 32, its key
    TextMetrics { id: wordWidth; font.pixelSize: Tacit.size.row; font.family: Appearance.font.family.main }
    TextMetrics { id: keyWidth; font.pixelSize: Tacit.size.meta; font.family: Appearance.font.family.numbers }
    property real needed: 200
    function open(x, y, list) {
        menu.items = list.filter(i => !!i);
        let w = 0;
        for (const it of menu.items) {
            wordWidth.text = it.label; keyWidth.text = it.key || "";
            w = Math.max(w, wordWidth.advanceWidth + keyWidth.advanceWidth + 32 + 20 + 12);
        }
        menu.needed = Math.max(200, Math.ceil(w));
        menu.at = 0;
        panel.x = Math.max(8, Math.min(x, menu.width - panel.width - 8));
        panel.y = Math.max(8, Math.min(y, menu.height - panel.height - 8));
        menu.visible = true;
        appear.restart();
        panel.forceActiveFocus();
    }
    function close() { if (!menu.visible) return; menu.visible = false; menu.closed(); }
    function pick(i) {
        const it = menu.items[i];
        if (!it) return;
        menu.close();
        it.run();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
    }

    // it opens from the pointer: a short rise in size and light, Praxis's quick curves
    ParallelAnimation {
        id: appear
        Anim { target: panel; property: "opacity"; from: 0; to: 1; type: Anim.FastEffects }
        Anim { target: panel; property: "scale"; from: 0.94; to: 1; type: Anim.FastSpatial }
    }

    Rectangle {
        id: panel
        transformOrigin: Item.TopLeft
        width: menu.needed
        height: col.implicitHeight + 12
        radius: Tacit.radius.panel       // Pinax's menu: one look for both apps' menus
        color: Appearance.m3colors.m3surfaceContainerHigh
        border.width: 1
        border.color: Tacit.hairline
        Keys.onEscapePressed: menu.close()
        Keys.onUpPressed: menu.at = (menu.at - 1 + menu.items.length) % menu.items.length
        Keys.onDownPressed: menu.at = (menu.at + 1) % menu.items.length
        Keys.onReturnPressed: menu.pick(menu.at)
        Keys.onEnterPressed: menu.pick(menu.at)

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            Repeater {
                model: menu.items
                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    width: col.width
                    height: 32 + (modelData.line ? 9 : 0)
                    Rectangle {
                        visible: !!entry.modelData.line
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4; leftMargin: 6; rightMargin: 6 }
                        height: 1
                        color: Tacit.hairline
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 32
                        radius: 7
                        color: menu.at === entry.index ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.9) : "transparent"
                        StyledText {
                            id: label
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: entry.modelData.label
                            font.pixelSize: Tacit.size.row
                            color: Tacit.inkMain
                        }
                        StyledText {
                            id: key
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: entry.modelData.key || ""
                            font.pixelSize: Tacit.size.meta
                            font.family: Appearance.font.family.numbers
                            color: Tacit.inkMeta
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: menu.at = entry.index
                            onClicked: menu.pick(entry.index)
                        }
                    }
                }
            }
        }
    }
}
