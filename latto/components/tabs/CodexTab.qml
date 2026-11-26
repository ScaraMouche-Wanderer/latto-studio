import QtQuick
import QtQuick.Controls as QQC
import "../../services"
import "../../theme"
import ".."

Item {
    id: root
    property string prompt: "Help me understand the task on this screen. Provide a concise answer as plain ASCII text. For coding tasks output only code without Markdown fences."
    property bool promptHeld: false
    readonly property string statusTitle: Codex.phase === "capturing" ? "Capturing screen"
        : Codex.phase === "thinking" ? "Codex is working"
        : Codex.phase === "typing" ? "Typing answer"
        : Codex.phase === "ready" ? "Answer ready"
        : Codex.phase === "error" ? "Action needs attention" : "Ready when you are"
    readonly property string availabilityMessage: {
        if (!Codex.ready || Codex.busy) return "";
        const reasons = [];
        if (!Codex.captureAvailable) reasons.push(Codex.captureReason || "Screen capture is unavailable.");
        if (!Settings.codexTypingEnabled) reasons.push("Keyboard typing is disabled in Latto Studio.");
        else if (!Codex.typeAvailable) reasons.push(Codex.typeReason || (Codex.answer === "" ? "Capture a screen before typing an answer." : "Typing is unavailable."));
        return reasons.join(" ");
    }

    function syncPromptHold() {
        const hold = visible && promptInput.activeFocus;
        if (hold === promptHeld) return;
        promptHeld = hold;
        if (hold) IslandState.holdOpen(); else IslandState.release();
    }
    onVisibleChanged: {
        syncPromptHold();
        if (visible) Codex.refresh();
    }
    Component.onCompleted: Codex.refresh()
    Component.onDestruction: if (promptHeld) IslandState.release()

    Label {
        id: privacyNote
        anchors.top: parent.top
        width: parent.width
        text: "Screen capture is sent to Codex. Desktop permission prompts may appear."
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.WordWrap
    }
    Rectangle {
        id: promptBox
        anchors.top: privacyNote.bottom
        anchors.topMargin: 8
        width: parent.width
        height: 68
        radius: 12
        color: Theme.surface
        border.width: 1
        border.color: promptInput.activeFocus ? Theme.accent : Theme.border

        TextEdit {
            id: promptInput
            objectName: "codexPromptInput"
            anchors.fill: parent
            anchors.margins: 10
            text: root.prompt
            textFormat: TextEdit.PlainText
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.island
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            clip: true
            Accessible.name: "Instructions for Codex"
            onTextChanged: if (text.length > 4000) text = text.slice(0, 4000)
            onActiveFocusChanged: root.syncPromptHold()
            TextEntryFocus {}
            Label {
                anchors.fill: parent
                visible: promptInput.text === ""
                text: "What should Codex do with this screen?"
                color: Theme.textTertiary
                font.pixelSize: Theme.fontSmall
            }
        }
    }
    Row {
        id: actions
        anchors.top: promptBox.bottom
        anchors.topMargin: 10
        spacing: 8

        IslandButton {
            objectName: "codexCaptureButton"
            icon: "camera"
            iconSize: 15
            text: "Capture & ask"
            fontSize: Theme.fontSmall
            primary: true
            enabled: Codex.canCapture && promptInput.text.trim() !== ""
            hint: Codex.captureReason || "Capture the screen and send it to Codex"
            onClicked: Codex.capture(promptInput.text.trim())
        }
        IslandButton {
            objectName: "codexTypeButton"
            icon: "keyboard"
            iconSize: 15
            text: "Type answer"
            fontSize: Theme.fontSmall
            subtle: true
            enabled: Settings.codexTypingEnabled && Codex.canType
            hint: Codex.typeReason || "Type into your focused editor after a 1 second countdown"
            onClicked: Codex.typeAnswer()
        }
        IslandButton {
            objectName: "codexCancelButton"
            icon: "close"
            iconSize: 12
            text: Codex.cancelRequested ? "Cancelling…" : "Cancel"
            fontSize: Theme.fontSmall
            visible: Codex.busy
            enabled: !Codex.cancelRequested
            color: Theme.orange
            onClicked: Codex.cancel()
        }
    }
    Row {
        id: statusRow
        anchors.top: actions.bottom
        anchors.topMargin: 10
        width: parent.width
        spacing: 8

        Spinner {
            size: 13
            visible: Codex.busy
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            width: statusRow.width - (Codex.busy ? 21 : 0)
            text: Codex.error !== "" ? Codex.error : (Codex.message !== "" ? Codex.message : root.statusTitle)
                + (root.availabilityMessage !== "" && root.availabilityMessage !== Codex.message ? "\n" + root.availabilityMessage : "")
            color: Codex.error !== "" ? Theme.orange : Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
    }
    Card {
        id: answerCard
        objectName: "codexAnswerCard"
        anchors.top: statusRow.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: typingNote.top
        anchors.bottomMargin: 8
        title: "Answer"

        Flickable {
            id: answerScroll
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: answerText.height
            boundsBehavior: Flickable.StopAtBounds
            QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

            TextEdit {
                id: answerText
                objectName: "codexAnswerPreview"
                width: Math.max(1, answerScroll.width - 12)
                height: Math.max(answerScroll.height, implicitHeight)
                text: Codex.answer
                textFormat: TextEdit.PlainText
                readOnly: true
                selectByMouse: true
                persistentSelection: true
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.island
                font.family: "monospace"
                font.pixelSize: Theme.fontSmall
                Accessible.name: "Codex answer preview"
                TextEntryFocus {}
            }
            Label {
                width: Math.max(1, parent.width - 16)
                visible: Codex.answer === ""
                text: "Capture a screen to get an answer here. Review the response before typing it."
                color: Theme.textTertiary
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap
            }
        }
    }
    Label {
        id: typingNote
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: "Use a multiline editor with a US keyboard layout. Enter and Tab are real keys. Keep your editor focused; Cancel stops typing."
        color: Theme.textTertiary
        font.pixelSize: Theme.fontCaption
        wrapMode: Text.WordWrap
    }
}
