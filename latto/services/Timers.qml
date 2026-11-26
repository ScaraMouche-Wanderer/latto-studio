pragma Singleton

import QtQuick
import Quickshell.Io

// Countdown timer, Pomodoro cycle and stopwatch. A plain countdown emits
// finished() when it reaches zero; a Pomodoro phase emits phaseEnded() and
// moves straight on to the next phase.
QtObject {
    id: root

    signal finished()
    // ended and next are "focus", "break" or "longBreak".
    signal phaseEnded(string ended, string next)

    // Countdown (milliseconds). timerRemaining is only live while running.
    property real timerPreset: 0
    property real timerRemaining: 0
    property real timerEndsAt: 0
    property bool timerRunning: false

    // Stopwatch (milliseconds).
    property bool swRunning: false
    property real swBase: 0
    property real swStartedAt: 0
    property real swElapsed: 0
    property var swLaps: []
    readonly property int maxLaps: 50

    // Pomodoro. phase is "" when no cycle is running.
    property string phase: ""
    // Focus sessions finished in the current cycle (resets after a long break).
    property int focusDone: 0
    readonly property bool pomodoro: phase !== ""
    readonly property bool focusQuiet: Settings.pomodoroDnd && phase === "focus"
    readonly property int pomodoroRounds: Math.max(1, Math.min(12, Settings.pomodoroRounds))
    onFocusQuietChanged: Notifications.focusQuietRequested = focusQuiet

    readonly property string phaseLabel: phase === "focus" ? "Focus"
        : phase === "break" ? "Short break"
        : phase === "longBreak" ? "Long break"
        : ""

    readonly property string countdownText: formatTime(Math.ceil(timerRemaining / 1000) * 1000, false)
    readonly property string stopwatchText: formatTime(swElapsed, true)

    function formatTime(ms, tenths) {
        const safeMs = Number.isFinite(ms) ? Math.max(0, ms) : 0;
        const totalTenths = Math.floor(safeMs / 100);
        const minutes = Math.floor(totalTenths / 600);
        const seconds = Math.floor(totalTenths / 10) % 60;
        const text = String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
        return tenths ? text + "." + (totalTenths % 10) : text;
    }

    function setPreset(ms) {
        const safeMs = Number.isFinite(ms) ? Math.max(0, ms) : 0;
        timerPreset = safeMs;
        timerRemaining = safeMs;
        timerRunning = false;
        Activities.dismiss("timerDone");
    }

    function customDuration(minutes, seconds) {
        if (!Number.isInteger(minutes) || minutes < 0 || minutes > 999
                || !Number.isInteger(seconds) || seconds < 0 || seconds > 59)
            return 0;
        return (minutes * 60 + seconds) * 1000;
    }

    function startTimer() {
        if (timerRunning || timerPreset <= 0)
            return;
        if (timerRemaining <= 0)
            timerRemaining = timerPreset;
        Activities.dismiss("timerDone");
        timerEndsAt = Date.now() + timerRemaining;
        timerRunning = true;
    }

    function pauseTimer() {
        if (!timerRunning)
            return;
        updateCountdown(Date.now());
        timerRunning = false;
    }

    function resetTimer() {
        if (pomodoro) {
            stopPomodoro();
            return;
        }
        timerRunning = false;
        timerRemaining = timerPreset;
        Activities.dismiss("timerDone");
    }

    function phaseMinutes(name) {
        if (name === "focus") return Math.max(1, Math.min(180, Settings.pomodoroFocusMinutes));
        if (name === "break") return Math.max(1, Math.min(60, Settings.pomodoroBreakMinutes));
        return Math.max(1, Math.min(120, Settings.pomodoroLongBreakMinutes));
    }

    function startPomodoro() {
        focusDone = 0;
        beginPhase("focus");
    }

    function beginPhase(name) {
        phase = name;
        setPreset(phaseMinutes(name) * 60000);
        startTimer();
    }

    // Ends the current phase early and starts the next one.
    function skipPhase() {
        if (pomodoro)
            advance();
    }

    function stopPomodoro() {
        phase = "";
        focusDone = 0;
        timerRunning = false;
        timerPreset = 0;
        timerRemaining = 0;
    }

    function advance() {
        const ended = phase;
        let next = "focus";
        if (ended === "focus") {
            focusDone++;
            next = focusDone % pomodoroRounds === 0 ? "longBreak" : "break";
        } else if (ended === "longBreak") {
            focusDone = 0;
        }
        phaseEnded(ended, next);
        beginPhase(next);
    }

    function playSound() {
        if (Settings.timerSound) {
            sound.command = ["paplay", Settings.timerSoundFile];
            sound.running = true;
        }
    }

    function toggleStopwatch() {
        if (swRunning) {
            swElapsed = stopwatchAt(Date.now());
            swBase = swElapsed;
            swRunning = false;
        } else {
            swStartedAt = Date.now();
            swRunning = true;
        }
    }

    function resetStopwatch() {
        swRunning = false;
        swBase = 0;
        swElapsed = 0;
        swLaps = [];
    }

    function stopwatchAt(now) {
        return Math.max(swElapsed, swBase + Math.max(0, now - swStartedAt));
    }

    function markLap() {
        if (!swRunning)
            return;
        const total = stopwatchAt(Date.now());
        const previous = swLaps[0];
        const lap = {
            number: previous ? previous.number + 1 : 1,
            split: total - (previous ? previous.total : 0),
            total: total
        };
        swLaps = [lap, ...swLaps.slice(0, maxLaps - 1)];
    }

    function updateCountdown(now) {
        timerRemaining = Math.max(0, timerEndsAt - now);
        if (timerRemaining > 0)
            return;
        timerRunning = false;
        if (pomodoro)
            advance();
        else
            finished();
    }

    onFinished: playSound()
    onPhaseEnded: playSound()

    property Process sound: Process {}

    property Timer tick: Timer {
        interval: root.swRunning ? 100 : 200
        repeat: true
        running: root.timerRunning || root.swRunning
        onTriggered: {
            const now = Date.now();
            if (root.timerRunning)
                root.updateCountdown(now);
            if (root.swRunning)
                root.swElapsed = root.stopwatchAt(now);
        }
    }
}
