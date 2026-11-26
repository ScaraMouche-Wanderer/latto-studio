pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// GIO handles desktop field codes, terminal apps and DBus activation.
// Only an installed ID is passed to the helper, never the search text.
QtObject {
    id: root
    readonly property var entries: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay && entry.name && entry.command.length > 0)
        .slice().sort((a, b) => a.name.localeCompare(b.name))
    property string feedback: ""
    property bool failed: false
    property string pendingId: ""
    property string pendingName: ""
    property bool busy: false
    property bool receivedReply: false
    property bool timedOut: false
    property Timer launchTimeout: Timer {
        interval: 10000
        onTriggered: { root.timedOut = true; root.launcher.signal(9); }
    }
    property Process launcher: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse(text);
                    root.receivedReply = true;
                    root.failed = !reply.ok;
                    root.feedback = reply.ok ? "Launch requested · " + root.pendingName : (reply.error || "Could not launch application");
                } catch (error) {
                    root.failed = true;
                    root.feedback = "Invalid reply from application launcher";
                }
            }
        }
        onExited: {
            root.launchTimeout.stop();
            root.busy = false;
            if (root.timedOut || !root.receivedReply) { root.failed = true; root.feedback = "Application launcher did not respond"; }
            root.clearFeedback.restart();
        }
    }
    property Timer clearFeedback: Timer {
        interval: 2200
        onTriggered: { root.feedback = ""; root.pendingId = ""; }
    }
    function matching(query) {
        const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
        return entries.filter(entry => {
            const text = [entry.name, entry.genericName, ...(entry.keywords || [])].join(" ").toLowerCase();
            return terms.every(term => text.includes(term));
        });
    }
    function launch(entry) {
        // Resolve the ID again: model delegates can wrap entry values, and an
        // application may have been uninstalled since its row was created.
        const installed = entry ? entries.find(candidate => candidate.id === entry.id) : null;
        if (!installed || busy || pendingId === installed.id) return;
        failed = false;
        clearFeedback.stop();
        pendingId = installed.id;
        pendingName = installed.name;
        busy = true;
        receivedReply = false;
        timedOut = false;
        feedback = "Requesting launch · " + installed.name;
        launcher.command = ["/usr/bin/python", Quickshell.env("HOME") + "/Apps/Latto/bin/app-launch.py", installed.id];
        launcher.running = true;
        launchTimeout.restart();
    }
}
