import QtQuick
import QtQuick.Pdf
import QtQuick.Shapes
import QtMultimedia
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import "Info.js" as Info

// One file of the folder. The viewer lays it out in the roll (where, how big) and, as it settles,
// the framed file grows into the bare window while every other frame is pushed out past the edge.
// `wgt` is how much this frame is THE file (1 at rest, 0 a file away), so nothing jumps when the
// roll is between two files while it settles or unsettles.
Item {
    id: fr
    required property var v
    required property int modelData      // the file's place in the folder; the viewer keeps frames only near the roll
    readonly property int index: modelData
    Component.onCompleted: v.framesMade++
    readonly property var e: v.entries[index]
    readonly property string kind: e?.kind ?? "file"
    readonly property real d: index - v.pos
    readonly property real wgt: Math.max(0, 1 - Math.abs(d))
    readonly property bool near: Math.abs(d) < 5
    readonly property bool live: Math.abs(d) < 3.6 + 2 * v.fold    // its content is loaded: one more each side than shows, so a step lands on a ready card
    readonly property bool isLanded: index === v.landed
    readonly property real s: v.settle * wgt                        // 0 framed in the roll, 1 bare
    readonly property size rs: near ? v.rollSize(index) : Qt.size(0, 0)
    readonly property rect br: err.length > 0 && kind !== "audio" ? Qt.rect(0, 0, v.width, v.height) : v.bareRect(kind)
    // why there is nothing to show, in a few plain words; empty when the file is fine
    property bool imageBad: false
    readonly property string err: {
        if (!e) return "";
        if (kind === "image") return imageBad ? "Can't read this picture" : "";
        if (kind === "pdf") return !locked && pdfDoc?.status === PdfDocument.Error && v.fallbackFailed[e.path] === true ? "This PDF is damaged" : "";
        if (kind === "video" || kind === "audio") return isLanded && v.mediaError.length > 0 ? "Can't play this " + kind : "";
        const x = e.name.indexOf(".") > 0 ? e.name.split(".").pop() : "";
        return x.length ? "Can't show ." + x + " files" : "Can't show this file";
    }
    readonly property real away: v.settle * (1 - wgt) * (d < 0 ? -1 : 1) * v.width * 0.6
    readonly property real radius: Appearance.rounding.card * (1 - s)
    readonly property string url: e ? v.urlOf(e.path) : ""
    property bool locked: false
    Binding { target: fr.v; property: "lockedDoc"; value: fr.locked ? pdfDoc : null; when: fr.isLanded; restoreMode: Binding.RestoreNone }

    visible: near && width > 0
    opacity: 1 - v.settle * (1 - wgt)
    x: (near ? v.cx + v.rollOffset(index) - rs.width / 2 + away : 0) * (1 - s) + br.x * s
    y: v.ry * (1 - s) + br.y * s
    width: rs.width * (1 - s) + br.width * s
    height: rs.height * (1 - s) + br.height * s

    // ---- the file itself
    Loader {
        id: docL
        active: fr.kind === "pdf" && fr.live
        sourceComponent: PdfDocument {
            id: d
            source: fr.url
            onPasswordRequired: fr.locked = true
            onStatusChanged: {
                if (d.status === PdfDocument.Ready) { fr.locked = false; fr.v.setAspectOf(fr.e.path, d.pagePointSize(0).width / d.pagePointSize(0).height); }
                else if (d.status === PdfDocument.Error && !fr.locked) fr.v.needFallback(fr.e.path);
            }
        }
    }
    readonly property var pdfDoc: docL.item
    readonly property bool pdfReady: pdfDoc !== null && pdfDoc.status === PdfDocument.Ready

    Item {
        id: box     // hugs the file's own shape inside the frame; rounded while framed
        // a PDF's page fades out as its reading view fades in, so a scrolled column never has the
        // framed page showing through between its pages
        opacity: fr.kind === "pdf" && fr.isLanded && readerL.status === Loader.Ready ? 1 - host.opacity : 1
        readonly property real a: v.aspectOf(fr.index)
        readonly property real fa: fr.height > 0 ? fr.width / fr.height : 1
        width: fr.kind === "audio" || fr.err.length > 0 ? fr.width : (a > fa ? fr.width : fr.height * a)
        height: fr.kind === "audio" || fr.err.length > 0 ? fr.height : (a > fa ? fr.width / a : fr.height)
        anchors.centerIn: parent
        // a picture turned by the title row: the view turns, shrinking to stay inside the window
        readonly property real turn: fr.isLanded && fr.kind === "image" ? fr.v.rotAnim : 0
        readonly property real tc: Math.abs(Math.cos(turn * Math.PI / 180))
        readonly property real ts: Math.abs(Math.sin(turn * Math.PI / 180))
        rotation: turn
        scale: turn === 0 || width <= 0 || height <= 0 ? 1 : Math.min(fr.width / (width * tc + height * ts), fr.height / (width * ts + height * tc))
        layer.enabled: fr.radius > 0.5
        layer.effect: OpacityMask { maskSource: Rectangle { width: box.width; height: box.height; radius: fr.radius } }
        Loader {
            anchors.fill: parent
            active: fr.live
            visible: fr.err.length === 0
            sourceComponent: fr.kind === "image" ? imageC : fr.kind === "pdf" ? pdfC : fr.kind === "video" ? videoC : fr.kind === "audio" ? audioC : otherC
        }
        // an unreadable file: a quiet slab while framed, plain words either way
        Rectangle { anchors.fill: parent; visible: fr.err.length > 0; color: Qt.rgba(1, 1, 1, 0.06); opacity: 1 - fr.s }
        VT {
            visible: fr.err.length > 0
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, implicitWidth)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            ink: 1
            font.pixelSize: 16
            text: fr.err
        }
        // the files beside the framed one sit back
        Rectangle { anchors.fill: parent; color: v.ground; opacity: v.dimOthers * (1 - fr.wgt) }
        Rectangle {
            anchors.fill: parent
            radius: fr.radius
            color: "transparent"
            border.width: 2 * v.fold * fr.wgt
            border.color: Appearance.colors.colInkMain
        }
    }

    // ---- the reading view of a PDF: the window's own size, shown through the frame as it grows
    Item {
        id: host
        anchors.fill: parent
        clip: fr.s < 0.999     // settled, the column has the whole window, not the first page's rect
        opacity: Math.max(0, (fr.s - 0.45) / 0.55)
        visible: opacity > 0 && fr.isLanded && fr.kind === "pdf"
        Loader {
            id: readerL
            x: -fr.x
            y: -fr.y
            width: fr.v.width
            height: fr.v.height
            active: fr.isLanded && fr.kind === "pdf" && (fr.pdfReady || fr.v.fallbackPages(fr.e.path).length > 0)
            sourceComponent: PdfReader {
                id: reader
                doc: fr.pdfReady ? fr.pdfDoc : null
                images: fr.v.fallbackPages(fr.e.path)
                query: fr.v.query
                pw: fr.v.pdfBase
                zoom: fr.v.pdfZoom
                leftInset: fr.v.pdfLeft
                rightInset: fr.v.pdfRight
                // the column ends inside the solid part of the top fade, so a page scrolled up dissolves
                // into it instead of showing through under the line
                topInset: 50
                Component.onCompleted: { fr.v.reader = reader; push(); }
                Component.onDestruction: if (fr.v.reader === reader) fr.v.reader = null
                // what the viewer's ticks, ruler and facts read about the document
                function push() {
                    fr.v.pdfPage = reader.page; fr.v.pdfPages = reader.count; fr.v.pdfCounts = reader.counts; fr.v.pdfMarks = reader.marks;
                    fr.v.pdfTop = reader.fracTop; fr.v.pdfSpan = reader.fracSpan;
                    fr.v.pdfPaper = reader.searchable ? Info.paper(reader.doc.pagePointSize(0).width, reader.doc.pagePointSize(0).height) : "";
                }
                onPageChanged: push()
                onCountChanged: push()
                onCountsChanged: push()
                onMarksChanged: push()
                onFracTopChanged: push()
                onFracSpanChanged: push()
                onSearchableChanged: push()
            }
        }
    }

    // ---- what each kind puts in the box
    Component {
        id: imageC
        Item {
            Item {
                id: zoomed
                width: parent.width
                height: parent.height
                scale: fr.isLanded ? fr.v.zoom : 1
                x: fr.isLanded ? fr.v.panX : 0
                y: fr.isLanded ? fr.v.panY : 0
                // GIF and WebP may be animated and play when the file is the bare one; every other
                // picture is a plain Image, which is what applies the EXIF rotation
                Loader {
                    anchors.fill: parent
                    sourceComponent: /\.(gif|webp)$/i.test(fr.e?.path ?? "") ? animatedC : stillC
                }
                Component {
                    id: stillC
                    Item {
                        // the folder's cached preview, the one Pinax shows, at once; the picture itself
                        // replaces it when decoded. In the roll it is decoded at roll size, and at full
                        // size once landed, keeping what it has while the bigger one loads.
                        ThumbnailImage {
                            anchors.fill: parent
                            sourcePath: fr.kind === "image" ? fr.e.path : ""
                            sourceSize.width: 256
                            sourceSize.height: 256
                            fillMode: Image.PreserveAspectFit
                            autoTransform: true
                            visible: full.status !== Image.Ready
                        }
                        Image {
                            id: full
                            anchors.fill: parent
                            source: fr.kind === "image" ? fr.url : ""
                            asynchronous: true
                            cache: false
                            retainWhileLoading: true
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            autoTransform: true
                            sourceSize.width: fr.isLanded ? 1800 : 900
                            sourceSize.height: 0
                            onStatusChanged: { fr.imageBad = status === Image.Error; if (status === Image.Ready && implicitHeight > 0) fr.v.setImageSize(fr.e.path, implicitWidth, implicitHeight); }
                        }
                    }
                }
                Component {
                    id: animatedC
                    AnimatedImage {
                        source: fr.kind === "image" ? fr.url : ""
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        playing: fr.isLanded && fr.v.settle > 0.99
                        onStatusChanged: { fr.imageBad = status === Image.Error; if (status === Image.Ready && implicitHeight > 0) fr.v.setImageSize(fr.e.path, implicitWidth, implicitHeight); }
                    }
                }
                // sharp when zoomed in: the full picture, decoded only then
                Image {
                    anchors.fill: parent
                    source: fr.isLanded && fr.v.zoom > 1.25 ? fr.url : ""
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    autoTransform: true
                    sourceSize.width: 4096
                    sourceSize.height: 0
                    opacity: status === Image.Ready ? 1 : 0
                }
            }
        }
    }
    Component {
        id: pdfC
        Item {
            Rectangle { anchors.fill: parent; color: fr.locked ? Qt.rgba(1, 1, 1, 0.06) : "#fbfaf8" }
            PdfPageImage {
                anchors.fill: parent
                document: pdfDoc
                currentFrame: fr.isLanded ? Math.min(fr.v.pdfPage, Math.max(0, (fr.pdfDoc?.pageCount ?? 1) - 1)) : 0
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 1000
                sourceSize.height: 0
            }
            // the matches on the page that is showing
            Shape {
                id: hitShape
                anchors.fill: parent
                visible: fr.isLanded && fr.v.query.length > 0 && fr.v.reader !== null
                readonly property real k: fr.pdfReady ? width / fr.pdfDoc.pagePointSize(fr.v.pdfPage).width : 1
                ShapePath {
                    strokeWidth: -1
                    fillColor: Qt.rgba(Appearance.m3colors.m3primary.r, Appearance.m3colors.m3primary.g, Appearance.m3colors.m3primary.b, 0.55)
                    scale: Qt.size(hitShape.k, hitShape.k)
                    PathMultiline {
                        id: pageHits
                        function refresh() { paths = fr.v.reader ? fr.v.reader.polysOn(fr.v.pdfPage) : []; }
                        property var follow: Connections { target: fr.v; function onPdfPageChanged() { pageHits.refresh(); } function onReaderChanged() { pageHits.refresh(); } }
                        property var follow2: Connections { target: fr.v.reader; ignoreUnknownSignals: true; function onStampChanged() { pageHits.refresh(); } }
                    }
                }
                ShapePath {
                    strokeWidth: 1.5
                    strokeColor: Appearance.m3colors.m3primaryContainer
                    fillColor: Qt.rgba(Appearance.m3colors.m3primary.r, Appearance.m3colors.m3primary.g, Appearance.m3colors.m3primary.b, 0.9)
                    scale: Qt.size(hitShape.k, hitShape.k)
                    PathMultiline { paths: fr.v.reader && fr.v.reader.search.currentResult >= 0 && fr.v.reader.search.currentPage === fr.v.pdfPage ? fr.v.reader.search.currentResultBoundingPolygons : [] }
                }
            }
            Image {
                anchors.fill: parent
                visible: !fr.pdfReady
                source: fr.v.fallbackPages(fr.e.path)[0] ?? ""
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            // PDFium is waiting for the password
            VT {
                visible: fr.locked && !fr.isLanded
                anchors.centerIn: parent
                ink: 2
                text: "Locked"
            }
        }
    }
    Component {
        id: videoC
        Item {
            Rectangle { anchors.fill: parent; color: "black" }
            Image { anchors.fill: parent; source: fr.v.thumbOf(fr.e.path); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true }
            VideoOutput {
                id: vo
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                visible: fr.isLanded && fr.v.played
                Binding { target: fr.v; property: "videoSink"; value: vo; when: fr.isLanded; restoreMode: Binding.RestoreNone }
            }
            VGlyph { visible: !(fr.isLanded && fr.v.playing); anchors.centerIn: parent; text: "play_arrow"; fill: 1; iconSize: 40; color: "white"; opacity: 1 - fr.s }
        }
    }
    Component {
        id: audioC
        Item {
            Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.06) }
            VGlyph { visible: cover.status !== Image.Ready; anchors.centerIn: parent; text: "music_note"; fill: 1; iconSize: parent.width * 0.25; ink: 2 }
            Image { id: cover; anchors.fill: parent; source: fr.v.thumbOf(fr.e.path); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true }
        }
    }
    Component { id: otherC; Item {} }

    // ---- folder view: what each frame is called
    Item {
        y: parent.height + 16
        width: parent.width
        opacity: fr.v.fold * fr.v.fold * (fr.x > -10 && fr.x < fr.v.width - 200 ? 1 : 0)
        visible: opacity > 0.01
        VT { width: parent.width; elide: Text.ElideRight; text: Info.title(fr.e?.name ?? "", fr.e?.kind, fr.e?.at); ink: fr.wgt > 0.5 ? 0 : 2; font.pixelSize: 14; font.weight: fr.wgt > 0.5 ? Font.DemiBold : Font.Normal }
        VT { y: 22; width: parent.width; elide: Text.ElideRight; text: fr.v.detailOf(fr.index); ink: fr.wgt > 0.5 ? 1 : 3; font.pixelSize: 13 }
    }

    // the framed file or a neighbour: a click in the roll opens or steps to it
    MouseArea {
        anchors.fill: parent
        enabled: fr.v.settle < 0.5 && fr.near
        cursorShape: Qt.PointingHandCursor
        onClicked: if (fr.index === fr.v.cur) fr.v.settleNow(true); else fr.v.goTo(fr.index)
    }
}
