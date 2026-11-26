pragma Singleton

import QtQuick
import Quickshell.Io

// Caps Lock state from the keyboard LEDs in sysfs. LEDs send no udev events,
// so each LED file is re-read in-process every 120 ms (no processes spawned).
// Caps Lock counts as on if any keyboard's LED is lit.
QtObject {
    id: root

    readonly property bool active: Settings.capsLockIndicator && Object.values(lit).some(value => value)
    property var ledPaths: []
    property var lit: ({})          // LED path -> bool

    function report(path, on) {
        const next = Object.assign({}, lit);
        next[path] = on;
        lit = next;

    }

    property Process finder: Process {
        running: false
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = this.text.trim().split("\n").filter(path => path !== "");
                if (JSON.stringify(paths) !== JSON.stringify(root.ledPaths)) root.ledPaths = paths;
                const next = {};
                for (const path of paths) if (root.lit[path]) next[path] = true;
                root.lit = next;
            }
        }
    }

    property Instantiator leds: Instantiator {
        model: root.ledPaths
        delegate: FileView {
            required property string modelData
            path: modelData + "/brightness"
            printErrors: false
            onLoadFailed: {
                root.report(modelData, false);
                if (!rescan.running) rescan.start();
            }
            onLoaded: root.report(modelData, text().trim() !== "0")
        }
    }

    // Discover keyboards on connection, disconnection and after resume.
    property Timer discovery: Timer {
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: Settings.capsLockIndicator
        onTriggered: if (!finder.running) finder.running = true
    }
    property Timer rescan: Timer {
        interval: 300
        onTriggered: if (Settings.capsLockIndicator && !finder.running) finder.running = true
    }

    property Timer timer: Timer {
        interval: 120
        repeat: true
        running: Settings.capsLockIndicator && root.leds.count > 0
        onTriggered: {
            for (let i = 0; i < root.leds.count; i++)
                root.leds.objectAt(i).reload();
        }
    }
}
