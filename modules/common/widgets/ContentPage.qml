import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real baseWidth: 600
    property bool forceWidth: false
    property real bottomContentPadding: Config.options.settings.style === "minimal" ? 40 : 90

    default property alias data: contentColumn.data

    clip: true
    contentHeight: contentColumn.y + contentColumn.implicitHeight + root.bottomContentPadding // y is the column's own top margin
    implicitWidth: contentColumn.implicitWidth
    
    ColumnLayout {
        id: contentColumn
        // forceWidth is a maximum, not a fixed width: the page cannot be flicked sideways and
        // clips, so on a window narrower than baseWidth the right-hand controls were unreachable.
        width: root.forceWidth
            ? (root.width > 0 ? Math.min(root.baseWidth, root.width - 40) : root.baseWidth)
            : Math.max(root.baseWidth, implicitWidth)
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            margins: 20
        }
        spacing: 30
    }

}
