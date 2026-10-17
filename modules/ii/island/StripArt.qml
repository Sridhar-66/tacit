import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.functions

// A real thing, small, one treatment: rounded, a hairline so dark art keeps its edge, a veil that tames a bright page
// (a PDF's first page 30 %, a screenshot 15 %, album art none); a screenshot shows whole at 32 x 20.
Item {
    id: art
    property string source: ""   // a URL or a path
    property real veil: 0
    property bool wide: false
    readonly property string url: art.source === "" || /^[a-z]+:/.test(art.source) ? art.source : "file://" + art.source
    readonly property bool pdf: /\.pdf$/i.test(art.source)
    readonly property real r: art.wide ? 4 : 5
    implicitWidth: art.wide ? 32 : 20
    implicitHeight: 20
    Rectangle {
        anchors.fill: parent
        radius: art.r
        color: Tacit.raised
    }
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: art.width
                height: art.height
                radius: art.r
            }
        }
        Image {
            anchors.fill: parent
            visible: !art.pdf
            source: art.pdf ? "" : art.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize.width: 96
        }
        // its own file, so QtPdf loads only when a PDF arrives; told its file as it is made (set later, it never drew),
        // and made again when a reused side shows another file
        Loader {
            id: page
            anchors.fill: parent
            active: art.pdf
            function load() {
                if (art.pdf)
                    page.setSource("PdfFirstPage.qml", { "path": art.url });
            }
            Component.onCompleted: page.load()
            Connections {
                target: art
                function onUrlChanged() { page.load(); }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Tacit.ground
            opacity: art.veil
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: art.r
        color: "transparent"
        border.width: 1
        border.color: ColorUtils.transparentize("#ffffff", 0.92)
    }
}
