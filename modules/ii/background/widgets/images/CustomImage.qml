pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.tacit.card
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "customImage"
    hoverEnabled: true

    property string imagePath: Config.options.background.widgets.customImage.path ?? ""
    property bool dropHover: false
    property real widgetSize: Config.options.background.widgets.customImage.size ?? 200

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // The first dropped file, when it is a picture.
    function setPicture(urls) {
        var cleanPath = urls[0].toString().replace(/^file:\/\//, "")
        var ext = cleanPath.split(".").pop().toLowerCase()
        var accepted = ["png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif"]
        if (accepted.indexOf(ext) !== -1) {
            Config.options.background.widgets.customImage.path = cleanPath
        }
    }

    WidgetCard {
        id: card
        anchors.fill: parent
        configKey: "customImage"
        glyph: "imagesmode"
        title: Translation.tr("Picture")

        TacitPicture {
            id: picture
            width: parent.width
            height: root.widgetSize
            source: root.imagePath !== "" ? root.imagePath : ""
            cache: false
            sourceSize: Qt.size(width, height)

            Rectangle {
                anchors.fill: parent
                radius: 14
                visible: root.imagePath === "" || picture.status === Image.Error
                color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, root.dropHover ? 0.86 : 0.93)
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dropHover ? "download" : "add_photo_alternate"
                        iconSize: 28
                        color: root.dropHover ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Translation.tr("Drop a picture here")
                        font.pixelSize: 13
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: (drag) => {
                    drag.accept(Qt.CopyAction)
                    root.dropHover = true
                }
                onExited: {
                    root.dropHover = false
                }
                onDropped: (drop) => {
                    if (drop.hasUrls && drop.urls.length > 0)
                        root.setPicture(drop.urls)
                    root.dropHover = false
                }
            }
        }
    }
}
