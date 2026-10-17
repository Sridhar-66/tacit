pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * The browser's sign-in in the notch (~/book4-edge/signin-notch-plan.md, IslandController's sign-in). The page is
 * the browser's own window under the sheet's hole (IslandContent); this draws what grows from the notch body under
 * it, never over it: the page's ask in the browser's words (its first line and buttons in one row, its notes,
 * fields and options under it; "1 of N" when more wait, in the stacked order of the browser's PLAN 11), a code from
 * your phone while the page's code field has the keys, and the grabber at the bottom edge: flick it up and the
 * sign-in closes. Laid out to IslandController.signinBandFor's numbers, which size the sheet.
 */
Item {
    id: sheet
    signal close()
    function focusInput() {}

    readonly property var ask: IslandController.signinAsk
    readonly property bool code: IslandController.signinCodeShown
    // under the 2 px gap and the page
    readonly property real pageBottom: 2 + IslandController.signinPageHeight
    readonly property var extraLines: sheet.ask ? (sheet.ask.lines ?? []).slice(1).map(l => l.text).concat(sheet.ask.notes ?? []) : []
    readonly property var choices: sheet.ask ? ((sheet.ask.buttons ?? []).length > 0 ? sheet.ask.buttons : (sheet.ask.actions ?? [])) : []
    property int picked: 0
    onAskChanged: {
        sheet.picked = 0;
        sheet.releaseKeys();
    }
    Component.onDestruction: sheet.releaseKeys()

    // a field takes the keyboard into the notch, and gives it back to the page once answered
    function takeKeys(input) {
        IslandController.keyboardScreen = IslandController.signinScreen;
        IslandController.keyboard = true;
        input.forceActiveFocus();
    }
    function releaseKeys() {
        if (IslandController.keyboard && IslandController.signinPhase === "open")
            IslandController.keyboard = false;
    }
    function answer(choice) {
        if (!sheet.ask || choice === "")
            return;
        const data = { "picked": sheet.picked };
        for (let i = 0; i < fieldRepeater.count; i++) {
            const f = fieldRepeater.itemAt(i);
            if (f)
                data[f.key] = f.text;
        }
        IslandController.signinAnswer(sheet.ask.id, choice, data);
        sheet.releaseKeys();
    }
    function glyphFor(kind) {
        switch (kind) {
        case "password":
        case "signin":
        case "proxy":
            return "lock";
        case "passkey":
            return "fingerprint";
        case "certificate":
            return "badge";
        case "permission":
        case "screen":
            return "shield";
        case "external":
            return "open_in_new";
        case "save":
            return "save";
        case "leave":
            return "warning";
        }
        return "info";
    }

    // the first choice stands out (primary, filled), the others are quiet words, the first at the far right
    component Choice: Rectangle {
        id: choice
        property string label: ""
        property bool strong: false
        signal picked()
        implicitWidth: choiceText.implicitWidth + 28
        implicitHeight: 28
        radius: 14
        color: choice.strong ? ColorUtils.transparentize(Appearance.colors.colPrimary, choiceArea.containsMouse ? 0.7 : 0.78)
            : choiceArea.containsMouse ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9) : "transparent"
        Behavior on color {
            ColorAnimation { duration: Appearance.animationCurves.expressiveFastEffectsDuration }
        }
        StyledText {
            id: choiceText
            anchors.centerIn: parent
            text: choice.label
            font.pixelSize: 14
            font.weight: choice.strong ? Font.DemiBold : Font.Medium
            color: choice.strong ? Appearance.colors.colPrimary : IslandController.contentColor
        }
        MouseArea {
            id: choiceArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.picked()
        }
    }

    Column {
        id: askColumn
        visible: sheet.ask !== null
        x: 20
        y: sheet.pageBottom + 8
        width: parent.width - 40

        Item {
            width: parent.width
            height: 40
            MaterialSymbol {
                id: askGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: sheet.glyphFor(sheet.ask?.kind ?? "")
                iconSize: 16
                color: IslandController.subtextColor
            }
            StyledText {
                id: askLine
                anchors.left: askGlyph.right
                anchors.leftMargin: 8
                anchors.right: askOf.left
                anchors.rightMargin: askOf.visible ? 8 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: (sheet.ask?.lines ?? [])[0]?.text ?? ""
                elide: Text.ElideRight
                font.pixelSize: 15
                color: IslandController.contentColor
            }
            StyledText {
                id: askOf
                anchors.right: choiceRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: IslandController.signinAskCount > 1
                width: visible ? implicitWidth : 0
                text: `1 of ${IslandController.signinAskCount}`
                font.pixelSize: 13
                color: IslandController.subtextColor
            }
            Row {
                id: choiceRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: Qt.RightToLeft
                spacing: 4
                Repeater {
                    model: sheet.choices
                    delegate: Choice {
                        required property var modelData
                        required property int index
                        label: modelData.label
                        strong: index === 0
                        onPicked: sheet.answer(modelData.choice)
                    }
                }
            }
        }
        // its other lines and notes
        Repeater {
            model: sheet.extraLines
            delegate: StyledText {
                required property string modelData
                x: 24
                width: askColumn.width - 24
                height: 18
                text: modelData
                elide: Text.ElideRight
                font.pixelSize: 13
                color: IslandController.subtextColor
            }
        }
        Item {
            width: 1
            height: ((sheet.ask?.fields ?? []).length + (sheet.ask?.options ?? []).length) > 0 ? 6 : 0
        }
        // its fields: the keys come into the notch while one is typed in
        Repeater {
            id: fieldRepeater
            model: sheet.ask?.fields ?? []
            delegate: Item {
                id: fieldRow
                required property var modelData
                required property int index
                readonly property string key: modelData.key
                readonly property alias text: input.text
                width: askColumn.width
                height: 36
                StyledText {
                    id: fieldLabel
                    x: 24
                    width: 64
                    anchors.verticalCenter: parent.verticalCenter
                    text: fieldRow.modelData.label
                    font.pixelSize: 13
                    color: IslandController.subtextColor
                }
                Rectangle {
                    anchors.left: fieldLabel.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    radius: 10
                    color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, input.activeFocus ? 0.88 : 0.93)
                    StyledTextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: fieldRow.modelData.secret ? TextInput.Password : TextInput.Normal
                        color: IslandController.contentColor
                        clip: true
                        Keys.onReturnPressed: sheet.answer(sheet.ask?.submit || (sheet.choices[0]?.choice ?? ""))
                        Keys.onEnterPressed: sheet.answer(sheet.ask?.submit || (sheet.choices[0]?.choice ?? ""))
                        Keys.onEscapePressed: sheet.answer(sheet.ask?.negative ?? "cancel")
                    }
                    MouseArea {
                        anchors.fill: parent
                        visible: !input.activeFocus
                        cursorShape: Qt.IBeamCursor
                        onClicked: sheet.takeKeys(input)
                    }
                }
            }
        }
        // its options: one picked
        Repeater {
            model: sheet.ask?.options ?? []
            delegate: Item {
                id: optionRow
                required property string modelData
                required property int index
                width: askColumn.width
                height: 30
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    radius: 8
                    color: sheet.picked === optionRow.index ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
                        : optionArea.containsMouse ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.94) : "transparent"
                }
                MaterialSymbol {
                    id: optionGlyph
                    x: 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: sheet.picked === optionRow.index ? "radio_button_checked" : "radio_button_unchecked"
                    iconSize: 15
                    color: sheet.picked === optionRow.index ? Appearance.colors.colPrimary : IslandController.subtextColor
                }
                StyledText {
                    anchors.left: optionGlyph.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: optionRow.modelData
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    color: IslandController.contentColor
                }
                MouseArea {
                    id: optionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sheet.picked = optionRow.index
                }
            }
        }
    }

    // A code from your phone (KDE Connect), only while the page's code field has the keys; Fill types it there.
    Item {
        id: codeRow
        visible: sheet.code
        x: 20
        y: sheet.ask ? askColumn.y + askColumn.height : sheet.pageBottom + 8
        width: parent.width - 40
        height: 40
        readonly property string digits: IslandController.phoneCode?.code ?? ""
        MaterialSymbol {
            id: phoneGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "smartphone"
            iconSize: 16
            color: IslandController.subtextColor
        }
        StyledText {
            id: codeText
            anchors.left: phoneGlyph.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            // grouped in threes, as a person reads it out
            text: codeRow.digits.length === 6 ? `${codeRow.digits.slice(0, 3)} ${codeRow.digits.slice(3)}` : codeRow.digits
            font.family: Appearance.font.family.numbers
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: IslandController.contentColor
        }
        StyledText {
            anchors.left: codeText.right
            anchors.leftMargin: 10
            anchors.right: fill.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "from your phone, just now"
            elide: Text.ElideRight
            font.pixelSize: 13
            color: IslandController.subtextColor
        }
        Choice {
            id: fill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "Fill"
            strong: true
            onPicked: IslandController.signinFill()
        }
    }

    // The grabber on the bottom edge: flicked up, the sign-in closes (its page may still ask to leave).
    Item {
        id: grabber
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 120
        height: 18
        property real lift: 0
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 7 + grabber.lift
            width: 36
            height: 4
            radius: 2
            color: ColorUtils.transparentize(IslandController.subtextColor, grabArea.containsMouse || grabArea.pressed ? 0.2 : 0.5)
            Behavior on color {
                ColorAnimation { duration: Appearance.animationCurves.expressiveFastEffectsDuration }
            }
        }
        MouseArea {
            id: grabArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real startY: 0
            onPressed: mouse => grabArea.startY = mouse.y
            onPositionChanged: mouse => {
                if (grabArea.pressed)
                    grabber.lift = Math.max(-10, Math.min(0, (mouse.y - grabArea.startY) / 2));
            }
            onReleased: mouse => {
                const flicked = mouse.y - grabArea.startY < -16;
                grabber.lift = 0;
                if (flicked)
                    IslandController.signinClose();
            }
        }
        Behavior on lift {
            enabled: !grabArea.pressed
            NumberAnimation { duration: Appearance.animationCurves.expressiveFastSpatialDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial }
        }
    }
}
