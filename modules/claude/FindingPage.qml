import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * One finding on the Results trail: what it is and how bad, what the agent said, the fix it
 * proposed, what a checker made of it, the words of the report it comes from (a written report read
 * by Sonnet), the file and line, and the agents that reported it (each opens its page).
 */
PanelPage {
    id: fp
    bodyHeight: col.implicitHeight
    readonly property var p: fp.pane
    readonly property var f: fp.entry.f.finding ?? ({})
    readonly property var statusWord: ({ problem: "Problem", open: "Open", fixed: "Fixed", done: "Done", confirmed: "Confirmed", not_a_bug: "Not a bug" })
    readonly property string file: fp.f.files?.[0] ?? ""
    // a path the Files tab can open: absolute or from home
    readonly property bool openable: fp.file.startsWith("/") || fp.file.startsWith("~/")

    component Words: StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        font.pixelSize: 16
        lineHeight: 1.3
        color: Appearance.colors.colInkMain
    }

    Column {
        id: col
        width: parent.width
        spacing: 2
        StyledText {
            width: parent.width
            topPadding: 4
            text: [fp.statusWord[fp.f.status] ?? "", fp.f.severity ? fp.f.severity : "", fp.f.checked?.real ? "checked: real" : ""].filter(x => x).join(" · ")
            font.pixelSize: 14
            color: fp.f.level === "high" && fp.f.need === "look" ? Appearance.colors.colClay : Appearance.colors.colInkMeta
        }
        StyledText {
            width: parent.width
            topPadding: 2
            wrapMode: Text.Wrap
            text: fp.f.title ?? ""
            font.pixelSize: 22
            font.weight: Font.DemiBold
            lineHeight: 1.1
            color: Appearance.colors.colInkMain
        }
        // where and who, before the words: the file (it opens), the agent that reported it, its time
        Row {
            readonly property var a0: fp.p.findAgent(fp.p.info, fp.f.sources?.[0]?.source ?? "")
            topPadding: 6
            spacing: 6
            StyledText {
                visible: fp.file.length > 0
                text: fp.file.split("/").pop() + (fp.f.line ? `:${fp.f.line}` : "")
                font.pixelSize: 14
                color: fp.openable ? (whereArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colPrimary) : Appearance.colors.colInkSecondary
                MouseArea { id: whereArea; anchors.fill: parent; enabled: fp.openable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (fp.p.files) fp.p.files.openFile(fp.file, Number(fp.f.line) || 0, "") }
            }
            StyledText {
                text: [fp.file.length ? "·" : "", fp.p.niceLabel(fp.f.sources?.[0]?.name ?? ""), parent.a0 ? `· ${fp.p.took(parent.a0)}` : ""].filter(x => x).join(" ")
                font.pixelSize: 14
                color: Appearance.colors.colInkSecondary
            }
        }
        Words { visible: (fp.f.detail ?? "").length > 0; topPadding: 12; text: fp.f.detail ?? "" }
        // its file was written after the report: it may be fixed
        StyledText {
            visible: !!fp.f.changedSince
            width: parent.width
            topPadding: 8
            wrapMode: Text.Wrap
            text: `The file changed on ${new Date(fp.f.changedSince ?? 0).toLocaleString(Qt.locale(), "d MMM, HH:mm")}, after this was reported. It may be fixed.`
            font.pixelSize: 14
            color: Appearance.colors.colPrimary
        }

        PanelSection { topPadding: 22; visible: (fp.f.fix ?? "").length > 0; text: "Fix" }
        Words { visible: (fp.f.fix ?? "").length > 0; text: fp.f.fix ?? "" }

        PanelSection { topPadding: 22; visible: !!fp.f.checked; text: "Checked" }
        Words {
            visible: !!fp.f.checked
            text: [fp.f.checked?.real ? "Real" : "Not real", fp.f.checked?.verdict ?? "", fp.f.checked?.severity ? `should be ${fp.f.checked.severity}` : ""].filter(x => x).join(" · ")
                  + (fp.f.checked?.why ? `\n${fp.f.checked.why}` : "")
        }

        PanelSection { topPadding: 22; visible: (fp.f.quote ?? "").length > 0; text: "From the report, read by Sonnet" }
        Rectangle {
            visible: (fp.f.quote ?? "").length > 0
            width: parent.width
            height: quote.implicitHeight + 20
            radius: 10
            color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95)
            StyledText {
                id: quote
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                wrapMode: Text.Wrap
                text: `“${fp.f.quote ?? ""}”`
                font.pixelSize: 15
                color: Appearance.colors.colInkSecondary
            }
        }

        PanelSection { topPadding: 22; visible: fp.file.length > 0; text: "Where" }
        PanelRow {
            visible: fp.file.length > 0
            glyph: "description"
            title: fp.file.split("/").pop() + (fp.f.line ? `:${fp.f.line}` : "")
            line: fp.file.split("/").slice(0, -1).join("/")
            chevron: fp.openable
            onClicked: if (fp.openable && fp.p.files) fp.p.files.openFile(fp.file, Number(fp.f.line) || 0, "")
        }

        PanelSection { topPadding: 22; visible: (fp.f.sources ?? []).length > 0; text: (fp.f.sources ?? []).length === 1 ? "Reported by" : `Reported by ${(fp.f.sources ?? []).length} agents` }
        Repeater {
            model: fp.f.sources ?? []
            PanelRow {
                required property var modelData
                readonly property var a: fp.p.findAgent(fp.p.info, modelData.source)
                mark: a?.state ?? "done"
                title: fp.p.niceLabel(modelData.name)
                line: a ? fp.p.lineOf(a) : ""
                meta: a ? fp.p.took(a) : ""
                chevron: !!a
                onClicked: if (a) fp.p.openAgent(modelData.source)
            }
        }
    }
}
