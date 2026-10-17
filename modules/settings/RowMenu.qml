import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * What else can be done to one row, behind a ⋯. These were buttons on every row, so a list of
 * eight networks carried sixteen controls. The menu is ChoiceRow's list, so both open the same way.
 */
Rectangle {
    id: root
    property var items: []   // [{ label, run, checked (optional: a tick when true) }]

    implicitWidth: 32
    implicitHeight: 32
    radius: 8
    color: area.containsMouse || menu.opened ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.92) : "transparent"
    Behavior on color { ColorAnimation { duration: 80 } }
    // keyboard: Tab to it, Enter or Space opens, arrows and Enter inside
    activeFocusOnTab: true
    border.width: root.activeFocus && (root.focusReason === Qt.TabFocusReason || root.focusReason === Qt.BacktabFocusReason) ? 1 : 0
    border.color: Appearance.colors.colPrimary
    Keys.onReturnPressed: menu.open()
    Keys.onEnterPressed: menu.open()
    Keys.onSpacePressed: menu.open()

    MaterialSymbol {
        anchors.centerIn: parent
        text: "more_horiz"
        iconSize: 20
        color: Tacit.inkMeta
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.opened ? menu.close() : menu.open()
    }

    Popup {
        id: menu
        y: root.height + 4
        x: root.width - width
        width: 220
        padding: 6
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 14
            color: Appearance.m3colors.m3surfaceContainerHigh
            border.width: 1
            border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.3)
        }

        onOpened: {
            menuList.currentIndex = 0;
            menuList.forceActiveFocus();
        }
        onClosed: root.forceActiveFocus()

        contentItem: ListView {
            id: menuList
            implicitHeight: contentHeight
            interactive: false
            model: root.items
            keyNavigationEnabled: true
            function runCurrent() {
                const it = root.items[menuList.currentIndex];
                if (it) {
                    menu.close();
                    it.run();
                }
            }
            Keys.onReturnPressed: menuList.runCurrent()
            Keys.onEnterPressed: menuList.runCurrent()
            delegate: Item {
                id: item
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: (itemArea.containsMouse || (item.ListView.isCurrentItem && menuList.activeFocus))
                        ? ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.94) : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }
                }
                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: tick.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: item.modelData.label
                    font.pixelSize: 15
                    color: Appearance.colors.colInkMain
                    elide: Text.ElideRight
                }
                MaterialSymbol {
                    id: tick
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: item.modelData.checked === true
                    text: "check"
                    iconSize: 18
                    color: Appearance.colors.colPrimary
                }
                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menuList.currentIndex = item.index;
                        menuList.runCurrent();
                    }
                }
            }
        }
    }
}
