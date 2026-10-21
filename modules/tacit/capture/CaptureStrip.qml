import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick

// The notch speaking while a region is being chosen: the same shape over the notch (DockedRect
// edge top, radius 14, cove 6, 34 px strip; IslandContent.qml, IslandHeader.qml), the time kept in
// the centre, the mode's hint in the left wing and the shape and close in the right. While a drag
// is in progress the left wing says what release does and the right wing shows the size.
// It grows from the notch's closed width on the notch's spring (the password request's sheet,
// PolkitContent.qml). Plain component, no services: closedWidth and the time come from the caller.
Item {
    id: root

    property bool shown: false
    property bool dragging: false
    property string glyph: ""
    property string hint: ""
    property string releaseText: ""
    property string sizeText: ""
    property string timeText: ""
    // 0 rectangle, 1 circle
    property int shapeIndex: 0
    property real closedWidth: 108
    property real fullWidth: 800
    property real topMargin: 0
    property color ground: "#1a1a1a"
    signal shapeChosen(int index)
    signal closeRequested

    readonly property real edgeInset: 22
    // Clear of the time in the centre, a 12-hour one ("10:33 AM") too.
    readonly property real centreHalf: Math.max(40, IslandController.clockWidth / 2 + 10)

    x: (parent.width - width) / 2
    y: topMargin
    width: shown ? Math.max(fullWidth, closedWidth) : closedWidth
    height: 34

    // Open on the notch's spring, as PolkitContent does.
    readonly property int duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
    readonly property list<real> curve: Appearance.animationCurves.expressiveDefaultSpatial
    Behavior on width {
        NumberAnimation { duration: root.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: root.curve }
    }

    DockedRect {
        anchors.fill: parent
        edge: "top"
        cornerRadius: 14
        fillet: 6
        color: root.ground
    }

    // Presses on the strip must not start a selection underneath it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    StyledText {
        anchors.centerIn: parent
        text: root.timeText
        font.family: Appearance.font.family.numbers
        font.pixelSize: 16
        color: Appearance.colors.colOnLayer0
    }

    // -- left wing
    Item {
        anchors {
            left: parent.left
            leftMargin: root.edgeInset
            right: parent.horizontalCenter
            rightMargin: root.centreHalf
            top: parent.top
            bottom: parent.bottom
        }
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        MaterialSymbol {
            id: modeGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            iconSize: 16
            color: Appearance.colors.colSubtext
        }
        StyledText {
            anchors {
                left: modeGlyph.right
                leftMargin: 8
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            text: root.hint
            elide: Text.ElideRight
            font.pixelSize: 15
            color: Appearance.colors.colOnLayer0
            opacity: root.dragging ? 0 : 1
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
        StyledText {
            anchors {
                left: modeGlyph.right
                leftMargin: 8
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            text: root.releaseText
            elide: Text.ElideRight
            font.pixelSize: 15
            color: Appearance.colors.colOnLayer0
            opacity: root.dragging ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }

    // -- right wing
    Item {
        anchors {
            right: parent.right
            rightMargin: root.edgeInset
            left: parent.horizontalCenter
            leftMargin: root.centreHalf
            top: parent.top
            bottom: parent.bottom
        }
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        // While dragging: the size.
        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.sizeText
            font.family: Appearance.font.family.numbers
            font.pixelSize: 15
            color: Appearance.colors.colOnLayer0
            opacity: root.dragging ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        // Before: the shape as words with the palette strip's dot (WallpaperStrip.qml source tabs),
        // and close.
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            enabled: !root.dragging
            opacity: root.dragging ? 0 : 1
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            Repeater {
                model: ["Rectangle", "Circle"]
                StyledText {
                    id: tab
                    required property string modelData
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: index === root.shapeIndex ? Font.DemiBold : Font.Normal
                    color: index === root.shapeIndex ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                    Rectangle {
                        visible: tab.index === root.shapeIndex
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 3
                        width: 4
                        height: 4
                        radius: 2
                        color: Appearance.colors.colPrimary
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shapeChosen(tab.index)
                    }
                }
            }

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "close"
                iconSize: 16
                color: Appearance.colors.colSubtext
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
