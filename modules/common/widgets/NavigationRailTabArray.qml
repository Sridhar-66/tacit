import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int currentIndex: 0
    property bool expanded: false
    property color colToggled: Appearance.colors.colSecondaryContainer
    default property alias data: tabBarColumn.data  
    implicitHeight: tabBarColumn.implicitHeight
    implicitWidth: tabBarColumn.implicitWidth
    Layout.topMargin: 25

    Rectangle {
        // Read off the selected button's own geometry rather than counting baseSize steps, so the
        // highlight cannot drift from the buttons if their height ever stops being uniform.
        readonly property var selectedTab: tabBarColumn.children[root.currentIndex] ?? null
        property real itemHeight: selectedTab?.height ?? (tabBarColumn.children[0]?.baseSize ?? 56)
        property real baseHighlightHeight: selectedTab?.baseHighlightHeight ?? 56
        anchors {
            top: tabBarColumn.top
            left: tabBarColumn.left
            topMargin: (selectedTab?.y ?? 0) + (root.expanded ? 0 : ((itemHeight - baseHighlightHeight) / 2))
        }
        radius: Config.options.settings.style === "minimal" ? Appearance.rounding.small : Appearance.rounding.full
        color: root.colToggled
        implicitHeight: root.expanded ? itemHeight : baseHighlightHeight
        implicitWidth: tabBarColumn?.children[root.currentIndex]?.visualWidth ?? 100

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }

    ColumnLayout {
        id: tabBarColumn
        anchors.fill: parent
        spacing: 0
    }
}
