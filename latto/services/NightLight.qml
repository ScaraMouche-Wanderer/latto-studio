pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// GNOME trial: use the existing GNOME Night Light setting, not hyprsunset.
QtObject {
    id: root
    property bool active: false
    function toggle() { setActive(!active); }
    function setActive(on) {
        setter.command = ["gsettings", "set", "org.gnome.settings-daemon.plugins.color", "night-light-enabled", on ? "true" : "false"];
        setter.running = true;
    }
    property Process setter: Process {
        onExited: root.probe.running = true
    }
    property Process probe: Process {
        command: ["gsettings", "get", "org.gnome.settings-daemon.plugins.color", "night-light-enabled"]
        stdout: StdioCollector { onStreamFinished: root.active = this.text.trim() === "true" }
    }
    property Timer poll: Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!root.probe.running) root.probe.running = true
    }
}
