pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var data: ({keyboard:{available:false,current:0,maximum:0},battery:{available:false,status:"",watts:0,hours:null},profiles:{active:"",available:[]}})
    property int watchers: 0
    property string error: ""
    readonly property bool busy: action.running
    readonly property string helper: Quickshell.env("HOME") + "/Apps/Latto/bin/system-controls.py"
    function watch() { watchers++; refresh(); }
    function unwatch() { watchers = Math.max(0, watchers - 1); }
    function refresh() { if (!reader.running) reader.running = true; }
    function run(name, value) {
        if (action.running) return;
        error = "";
        action.command = ["/usr/bin/python", helper, name, value === undefined ? "" : String(value)];
        action.running = true;
    }
    property Process reader: Process {
        command: ["/usr/bin/python", root.helper, "snapshot"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(this.text);
                    if (next.keyboard && next.battery && next.profiles) root.data = next;
                } catch (e) { root.error = "Could not read system controls"; }
            }
        }
    }
    property Process action: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try { const reply = JSON.parse(this.text); if (!reply.ok) root.error = reply.error || "Action unavailable"; }
                catch (e) { root.error = "Action did not return a result"; }
            }
        }
        onExited: root.refresh()
    }
    property Timer poll: Timer {
        interval: 10000; repeat: true; running: root.watchers > 0
        onTriggered: root.refresh()
    }
}
