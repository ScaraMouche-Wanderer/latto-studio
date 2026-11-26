import QtQuick
import QtQuick.Controls as QQC
import "../../services"
import "../../theme"
import ".."

// Countdown presets and Pomodoro share the left card. The stopwatch stays
// independent so a user can record laps during a countdown.
Row {
    id: root

    spacing: 10

    property bool editingDuration: false
    readonly property real cardWidth: Math.max(0, (width - spacing) / 2)
    readonly property color countdownTint: !Timers.pomodoro ? Theme.orange
        : Timers.phase === "focus" ? Theme.red : Theme.green
    readonly property real customDuration: Timers.customDuration(Number(minutes.editor.text), Number(seconds.editor.text))
    readonly property bool durationValid: customDuration > 0
        && (minutes.editor.text === "" || minutes.editor.acceptableInput)
        && (seconds.editor.text === "" || seconds.editor.acceptableInput)

    function editDuration() {
        minutes.editor.text = String(Math.floor(Timers.timerPreset / 60000));
        seconds.editor.text = String(Math.floor(Timers.timerPreset / 1000) % 60);
        editingDuration = true;
        Qt.callLater(function() {
            if (!root.editingDuration) return;
            IslandState.textEntryRequested(minutes.editor);
            minutes.editor.forceActiveFocus();
            minutes.editor.selectAll();
        });
    }

    function finishEditing() {
        editingDuration = false;
        customButton.forceActiveFocus();
    }

    function applyDuration() {
        if (!durationValid) return;
        Timers.setPreset(customDuration);
        finishEditing();
    }

    function resetNavigation() { editingDuration = false; }

    function goBack() {
        if (!editingDuration) return false;
        finishEditing();
        return true;
    }

    onEditingDurationChanged: {
        if (editingDuration) IslandState.holdOpen();
        else IslandState.release();
    }
    onEnabledChanged: if (!enabled) resetNavigation()
    onVisibleChanged: if (!visible) resetNavigation()
    Component.onDestruction: if (editingDuration) IslandState.release()

    component Readout: Label {
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: Theme.fontDisplay
        font.weight: Font.Medium
        font.features: ({ "tnum": 1 })
    }

    component DurationField: Rectangle {
        id: field
        required property string unit
        required property string fieldLabel
        required property int maximum
        property alias editor: input

        implicitWidth: 64
        implicitHeight: 34
        radius: 10
        color: Theme.surfaceRaised
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.border

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: suffix.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            anchors.rightMargin: 4
            clip: true
            activeFocusOnTab: true
            selectByMouse: true
            horizontalAlignment: TextInput.AlignHCenter
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: String(field.maximum).length
            validator: IntValidator { bottom: 0; top: field.maximum }
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.island
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.features: ({ "tnum": 1 })
            Accessible.name: field.fieldLabel
            Keys.onReturnPressed: root.applyDuration()
            Keys.onEnterPressed: root.applyDuration()
            TextEntryFocus {}
        }

        Label {
            id: suffix
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: field.unit
            color: Theme.textSecondary
            font.pixelSize: Theme.fontCaption
        }
    }

    component LapRow: Row {
        id: lapRow
        required property string lapLabel
        required property string splitLabel
        required property string totalLabel
        property color tint: Theme.textSecondary

        spacing: 4
        readonly property real durationWidth: (width - lapName.width - 2 * spacing) / 2

        Label {
            id: lapName
            width: 42
            text: lapRow.lapLabel
            color: lapRow.tint
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
        Label {
            width: lapRow.durationWidth
            text: lapRow.splitLabel
            color: lapRow.tint
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSmall
            font.features: ({ "tnum": 1 })
            elide: Text.ElideLeft
        }
        Label {
            width: lapRow.durationWidth
            text: lapRow.totalLabel
            color: lapRow.tint
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSmall
            font.features: ({ "tnum": 1 })
            elide: Text.ElideLeft
        }
    }

    Card {
        width: root.cardWidth
        height: root.height
        title: Timers.pomodoro ? "Pomodoro" : "Countdown"

        Readout {
            id: countdown
            anchors.top: parent.top
            text: Timers.countdownText
            color: Timers.timerRunning || (Timers.timerPreset > 0 && Timers.timerRemaining === 0)
                ? root.countdownTint : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }

        IslandBar {
            id: countdownBar
            anchors.top: countdown.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.78
            value: Timers.timerPreset > 0 ? Timers.timerRemaining / Timers.timerPreset : 0
            fillColor: root.countdownTint
        }

        Row {
            anchors.top: countdownBar.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: !Timers.pomodoro && !root.editingDuration

            Repeater {
                model: [5, 10, 25]

                IslandButton {
                    required property int modelData
                    text: modelData + "m"
                    fontSize: Theme.fontSmall
                    subtle: true
                    enabled: !Timers.timerRunning
                    accessibleLabel: "Set countdown to " + modelData + " minutes"
                    onClicked: Timers.setPreset(modelData * 60000)
                }
            }

            IslandButton {
                id: customButton
                objectName: "timerCustom"
                text: "Custom"
                fontSize: Theme.fontSmall
                subtle: true
                enabled: !Timers.timerRunning
                accessibleLabel: "Set a custom countdown duration"
                onClicked: root.editDuration()
            }
        }

        Row {
            objectName: "timerDurationEditor"
            anchors.top: countdownBar.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: root.editingDuration

            DurationField {
                id: minutes
                unit: "min"
                fieldLabel: "Countdown minutes"
                maximum: 999
                editor.objectName: "timerMinutes"
            }
            DurationField {
                id: seconds
                unit: "sec"
                fieldLabel: "Countdown seconds"
                maximum: 59
                editor.objectName: "timerSeconds"
            }
            IslandButton {
                objectName: "timerDurationApply"
                height: 34
                text: "Set"
                fontSize: Theme.fontSmall
                primary: true
                enabled: root.durationValid
                accessibleLabel: "Set countdown duration"
                onClicked: root.applyDuration()
            }
            IslandButton {
                height: 34
                width: 32
                icon: "close"
                iconSize: 13
                hint: "Cancel duration edit"
                accessibleLabel: "Cancel duration edit"
                onClicked: root.finishEditing()
            }
        }

        Column {
            anchors.top: countdownBar.bottom
            anchors.topMargin: 13
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 7
            visible: Timers.pomodoro

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Timers.phaseLabel
                color: root.countdownTint
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Repeater {
                    model: Timers.pomodoroRounds

                    Rectangle {
                        required property int index
                        readonly property bool done: index < Timers.focusDone
                        readonly property bool current: Timers.phase === "focus" && index === Timers.focusDone

                        width: 7
                        height: 7
                        radius: 3.5
                        color: done ? Theme.red : current ? "transparent" : Theme.surfaceRaised
                        border.color: current ? Theme.red : "transparent"
                        border.width: current ? 1.5 : 0
                    }
                }
            }
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            IslandButton {
                objectName: "timerStart"
                primary: true
                text: Timers.timerRunning ? "Pause"
                    : Timers.timerRemaining === 0 && Timers.timerPreset > 0 ? "Restart"
                    : Timers.timerRemaining < Timers.timerPreset ? "Resume" : "Start"
                icon: Timers.timerRunning ? "pause" : "play"
                iconSize: 14
                enabled: Timers.timerPreset > 0 && !root.editingDuration
                onClicked: Timers.timerRunning ? Timers.pauseTimer() : Timers.startTimer()
            }
            IslandButton {
                visible: Timers.pomodoro
                subtle: true
                icon: "skip"
                iconSize: 13
                accessibleLabel: "Skip Pomodoro phase"
                hint: "Skip this phase"
                onClicked: Timers.skipPhase()
            }
            IslandButton {
                subtle: true
                text: Timers.pomodoro ? "Stop" : "Reset"
                enabled: !root.editingDuration && (Timers.pomodoro
                    || Timers.timerRunning || Timers.timerRemaining !== Timers.timerPreset)
                onClicked: Timers.resetTimer()
            }
            IslandButton {
                objectName: "timerFocus"
                visible: !Timers.pomodoro
                enabled: !Timers.timerRunning && !root.editingDuration
                icon: "focus"
                iconSize: 12
                text: "Focus"
                subtle: true
                color: Theme.red
                accessibleLabel: "Start a Pomodoro focus session"
                onClicked: Timers.startPomodoro()
            }
        }
    }

    Card {
        width: root.cardWidth
        height: root.height
        title: "Stopwatch"

        Readout {
            id: stopwatch
            anchors.top: parent.top
            text: Timers.stopwatchText
            color: Timers.swRunning ? Theme.green : Theme.text
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }
        LapRow {
            id: lapHeading
            anchors.top: stopwatch.bottom
            anchors.topMargin: 6
            width: parent.width - 7
            visible: Timers.swLaps.length > 0
            lapLabel: "Lap"
            splitLabel: "Split"
            totalLabel: "Total"
        }
        ListView {
            id: laps
            objectName: "stopwatchLaps"
            anchors.top: lapHeading.bottom
            anchors.topMargin: 7
            anchors.bottom: stopwatchControls.top
            anchors.bottomMargin: 7
            width: parent.width
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: Timers.swLaps
            onCountChanged: positionViewAtBeginning()

            delegate: LapRow {
                required property var modelData
                width: laps.width - 7
                lapLabel: String(modelData.number).padStart(2, "0")
                splitLabel: Timers.formatTime(modelData.split, true)
                totalLabel: Timers.formatTime(modelData.total, true)
                tint: Theme.text
            }

            QQC.ScrollBar.vertical: QQC.ScrollBar {
                width: 4
                policy: QQC.ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: 1.5
                    color: Theme.textTertiary
                }
                background: Item {}
            }
        }
        Row {
            id: stopwatchControls
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            IslandButton {
                objectName: "stopwatchStart"
                primary: true
                text: Timers.swRunning ? "Pause" : Timers.swElapsed > 0 ? "Resume" : "Start"
                icon: Timers.swRunning ? "pause" : "play"
                iconSize: 14
                onClicked: Timers.toggleStopwatch()
            }
            IslandButton {
                objectName: "stopwatchLap"
                subtle: true
                text: "Lap"
                enabled: Timers.swRunning
                accessibleLabel: "Record stopwatch lap"
                onClicked: Timers.markLap()
            }
            IslandButton {
                objectName: "stopwatchReset"
                subtle: true
                text: "Reset"
                enabled: Timers.swRunning || Timers.swElapsed > 0
                onClicked: Timers.resetStopwatch()
            }
        }
    }
}
