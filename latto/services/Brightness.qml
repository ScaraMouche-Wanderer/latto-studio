pragma Singleton

import QtQuick
import Quickshell.Io

// Backlight level via brightnessctl. The level is re-read the moment udev
// reports a backlight change, so key presses reach the island without delay.
QtObject {
    id: root

    property int current: 0
    property int maximum: 0
    readonly property bool available: maximum > 0
    readonly property real level: maximum > 0 ? current / maximum : 0

    // A change arrived while a read was in flight; read again when it ends.
    property bool refreshPending: false

    property int pendingPercent: -1
    function set(fraction) {
        if (!Number.isFinite(fraction)) return;
        const percent = Math.round(Math.max(0.01, Math.min(1, fraction)) * 100);
        if (setProc.running) { pendingPercent = percent; return; }
        setProc.command = ["brightnessctl", "set", percent + "%"];
        setProc.running = true;
    }

    function refresh() {
        if (reader.running)
            refreshPending = true;
        else
            reader.running = true;
    }

    property Process setProc: Process {
        onExited: {
            root.refresh();
            if (root.pendingPercent >= 0) {
                const next = root.pendingPercent;
                root.pendingPercent = -1;
                root.set(next / 100);
            }
        }
    }

    property Process reader: Process {
        running: true
        command: ["sh", "-c", "brightnessctl g && brightnessctl m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("\n");
                if (parts.length === 2) {
                    root.current = parseInt(parts[0]) || 0;
                    root.maximum = parseInt(parts[1]) || 0;
                } else {
                    root.maximum = 0;
                }
            }
        }
        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    property UdevMonitor monitor: UdevMonitor {
        subsystem: "backlight"
        onDeviceChanged: root.refresh()
    }
}
