pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// GNOME owns desktop idle and automatic suspend; use its session inhibitor.
// Other desktops retain the systemd idle inhibitor.
QtObject {
    id: root

    readonly property bool active: inhibitor.running
    readonly property bool gnome: (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toUpperCase().split(":").includes("GNOME")

    function toggle() {
        inhibitor.running = !inhibitor.running;
    }

    property Process inhibitor: Process {
        command: root.gnome
            ? ["gnome-session-inhibit", "--app-id=latto", "--reason=Latto keep awake", "--inhibit=idle", "--inhibit=suspend", "--inhibit-only"]
            : ["systemd-inhibit", "--what=idle", "--who=latto", "--why=Caffeine mode", "sleep", "infinity"]
    }
}
