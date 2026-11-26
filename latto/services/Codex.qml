pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User-requested screen analysis and insertion. The helper owns desktop access.
QtObject {
    id: root

    readonly property string helper: Quickshell.shellDir + "/bin/latto-codex.py"
    property bool ready: false
    property string phase: "idle"
    property string answer: ""
    property string error: ""
    property string message: "Checking Codex…"
    property string captureBackend: ""
    property string typeBackend: ""
    property string captureReason: ""
    property string typeReason: ""
    property bool captureAvailable: false
    property bool typeAvailable: false
    property bool snapshotBusy: false
    property bool submitting: false
    property bool cancelRequested: false
    property bool receivedFinal: false
    property bool statusReceived: false
    property string requestId: ""
    property int pendingGeneration: 0
    // The UI always previews first; Smart indentation is applied only after
    // the user explicitly presses Type answer.
    readonly property string typingMode: "smart"
    readonly property bool busy: submitting || worker.running || snapshotBusy || cancellation.running
    readonly property bool canCapture: ready && captureAvailable && !busy && !status.running
    readonly property bool canType: ready && typeAvailable && answer !== "" && !busy && !status.running

    function apply(data) {
        if (!data || typeof data !== "object" || typeof data.phase !== "string")
            throw new Error("Invalid Codex response");
        ready = true;
        phase = data.phase;
        if (typeof data.answer === "string") answer = data.answer;
        error = typeof data.error === "string" ? data.error : "";
        message = typeof data.message === "string" ? data.message : "";
        captureAvailable = data.canCapture === true;
        typeAvailable = data.canType === true;
        snapshotBusy = data.busy === true;
        captureBackend = typeof data.captureBackend === "string" ? data.captureBackend : "";
        typeBackend = typeof data.typeBackend === "string" ? data.typeBackend : "";
        captureReason = typeof data.captureReason === "string" ? data.captureReason : "";
        typeReason = typeof data.typeReason === "string" ? data.typeReason : "";
        if (!snapshotBusy && !worker.running && !cancellation.running) cancelRequested = false;
    }
    function fail(text) {
        phase = "error";
        error = text;
        message = "";
        snapshotBusy = false;
    }
    function refresh() {
        if (worker.running || submitting || cancellation.running || status.running) return;
        statusReceived = false;
        status.running = true;
    }
    function requestBlocked() {
        // QML bindings update after the current JavaScript turn. Check mutable
        // state directly so two immediate calls cannot both launch a helper.
        return submitting || worker.running || snapshotBusy || cancellation.running || status.running;
    }
    function begin(args) {
        submitting = true;
        receivedFinal = false;
        cancelRequested = false;
        snapshotBusy = false;
        error = "";
        requestId = String(Date.now()) + "_" + Math.random().toString(16).slice(2);
        worker.command = ["/usr/bin/python", helper].concat(args, ["--request-id", requestId]);
        worker.running = true;
    }
    function capture(prompt) {
        if (requestBlocked() || !ready || !captureAvailable) return;
        const args = ["capture", "--prompt", prompt, "--typing-mode", typingMode];
        const generation = ++pendingGeneration;
        submitting = true;
        requestId = "";
        error = "";
        phase = "capturing";
        message = "Requesting a screen capture…";
        IslandState.keyboardFocusRequested(false);
        Qt.callLater(function() {
            if (root.submitting && root.pendingGeneration === generation) root.begin(args);
        });
    }
    function typeAnswer() {
        if (requestBlocked() || !ready || !typeAvailable || answer === "") return;
        const args = ["type", "--typing-mode", typingMode];
        submitting = true;
        requestId = "";
        const generation = ++pendingGeneration;
        error = "";
        phase = "typing";
        message = "Typing starts in 1 second. Keep your editor focused.";
        IslandState.keyboardFocusRequested(false);
        Qt.callLater(function() {
            if (root.submitting && root.pendingGeneration === generation) root.begin(args);
        });
    }
    function cancel() {
        if (!(submitting || worker.running || snapshotBusy) || cancellation.running || cancelRequested) return;
        if (submitting && !worker.running && requestId === "") {
            pendingGeneration++;
            submitting = false;
            phase = answer !== "" ? "ready" : "idle";
            message = "Cancelled.";
            return;
        }
        submitting = false;
        cancelRequested = true;
        message = "Cancelling…";
        cancellation.running = true;
    }
    function acceptWorker(line) {
        try {
            const data = JSON.parse(line);
            apply(data);
            submitting = false;
            if (data.busy !== true && ["idle", "ready", "error"].includes(data.phase)) receivedFinal = true;
        } catch (e) {
            fail("Could not read the Codex response.");
        }
    }
    Component.onCompleted: refresh()

    property Process worker: Process {
        stdout: SplitParser { onRead: line => root.acceptWorker(line) }
        onExited: exitCode => {
            root.submitting = false;
            root.snapshotBusy = false;
            if (!root.receivedFinal && !root.cancelRequested)
                root.fail(exitCode === 0 ? "Codex ended without a result. Try again." : "Codex stopped before finishing. Try again.");
            if (!root.cancellation.running) root.requestId = "";
            if (root.cancelRequested) Qt.callLater(root.refresh);
        }
    }
    property Process status: Process {
        command: ["/usr/bin/python", root.helper, "status"]
        stdout: SplitParser {
            onRead: line => {
                if (root.worker.running || root.submitting) return;
                try { root.apply(JSON.parse(line)); root.statusReceived = true; }
                catch (e) { root.fail("Could not check Codex availability."); }
            }
        }
        onExited: exitCode => {
            if (!root.statusReceived && !root.worker.running && !root.submitting)
                root.fail("Could not start the Codex helper.");
        }
    }
    property Process cancellation: Process {
        command: ["/usr/bin/python", root.helper, "cancel"].concat(root.requestId !== "" ? ["--request-id", root.requestId] : [])
        stdout: SplitParser {
            onRead: line => {
                // The running action supplies its final snapshot after stopping.
                if (root.worker.running || root.status.running) return;
                try { root.apply(JSON.parse(line)); }
                catch (e) { root.fail("Could not read the cancellation result."); }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.cancelRequested = false;
                root.error = "Could not cancel Codex. Try again.";
            }
            if (!root.worker.running) {
                root.requestId = "";
                Qt.callLater(root.refresh);
            }
        }
    }
    property Timer externalStatus: Timer {
        interval: 1500
        running: root.snapshotBusy && !root.worker.running && !root.submitting
        repeat: true
        onTriggered: root.refresh()
    }
}
