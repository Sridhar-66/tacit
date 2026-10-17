import QtQuick
import QtQuick.Pdf

// A PDF's first page as a picture, for a peek. Its own file so QtPdf loads only when a PDF arrives.
PdfPageImage {
    property alias path: doc.source
    document: PdfDocument { id: doc }
    currentFrame: 0
    fillMode: Image.PreserveAspectCrop
    verticalAlignment: Image.AlignTop
    asynchronous: true
    sourceSize.width: 96
    smooth: true
    mipmap: true
    // a page draws its ink only: the paper is ours
    Rectangle {
        anchors.fill: parent
        z: -1
        color: "white"
    }
}
