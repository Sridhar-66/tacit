import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Images the agent looked at or you sent: thumbnails up to 200px tall, rounded; a click opens
// the viewer (claude.qml's MediaViewer, reached through `viewer`).
Flow {
    id: thumbs
    property var paths: []
    property var viewer: null
    spacing: 8

    Repeater {
        model: thumbs.paths
        delegate: Rectangle {
            required property string modelData
            width: Math.min(img.implicitWidth > 0 ? img.paintedWidth : 160, thumbs.width)
            height: img.status === Image.Ready ? img.paintedHeight : 120
            radius: 10
            color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95)
            clip: true
            Image {
                id: img
                anchors.centerIn: parent
                source: `file://${modelData}`
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.height: 400
                width: Math.min(thumbs.width, 360)
                height: 200
                smooth: true
                mipmap: true
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (thumbs.viewer) thumbs.viewer.show(modelData)
            }
        }
    }
}
