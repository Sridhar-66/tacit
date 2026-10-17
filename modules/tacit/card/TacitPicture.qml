import QtQuick
import QtQuick.Effects

// A picture cropped to fill, with rounded corners.
Item {
    id: root
    property alias source: img.source
    property alias sourceSize: img.sourceSize
    property alias cache: img.cache
    readonly property alias status: img.status
    property real radius: 14

    Image {
        id: img
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
}
