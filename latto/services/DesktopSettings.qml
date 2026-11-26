pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property var values: ({})
    property var writable: ({})
    property string error: ""
    property int watchers: 0
    property int revision:0
    property int readerRevision:0
    property string phase:"idle"
    property string pendingName:""
    property string pendingAction:""
    property var pendingValue:null
    property bool receivedReply:false
    function unavailable(name){return busy?"":!has(name)?"Unavailable in this desktop session":"Managed by desktop policy";}
    function applyProfile(name,digest){write("profile",name,{digest:digest});}
    readonly property bool busy: phase==="applying"||writer.running
    readonly property string helper: Quickshell.env("HOME") + "/Apps/Latto/bin/desktop-settings.py"
    function has(name) { return Object.prototype.hasOwnProperty.call(values, name); }
    function get(name, fallback) { return has(name) ? values[name] : fallback; }
    function canSet(name) { return has(name) && writable[name] === true && !busy; }
    function watch() { watchers++; refresh(); }
    function unwatch() { watchers = Math.max(0, watchers - 1); }
    function refresh() { if (!reader.running){readerRevision=revision;reader.running = true;} }
    function set(name, value) { write("set", name, value); }
    function setLatto(name, value) { write("latto", name, value); }
    function write(action, name, value) {
        if (busy) return;
        error = "";phase="applying";feedbackTimer.stop();revision++;receivedReply=false;
        pendingName=name;pendingValue=value;pendingAction=action;
        writer.command = ["/usr/bin/python", helper, action, name, JSON.stringify(value)];
        writer.running = true;
    }
    property Process reader: Process {
        onExited:if(root.readerRevision!==root.revision)Qt.callLater(root.refresh)
        command: ["/usr/bin/python", root.helper, "snapshot"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse(this.text);
                    if(root.readerRevision!==root.revision)return;
                    if (reply.values && reply.writable) { root.values = reply.values; root.writable = reply.writable; }
                    else root.error = reply.error || "Desktop preferences are unavailable";
                } catch(e) { root.error = "Could not read desktop preferences"; }
            }
        }
    }
    property Timer feedbackTimer:Timer {interval:2200;onTriggered:if(!root.busy&&root.phase==="applied")root.phase="idle"}
    property Process writer: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply=JSON.parse(this.text);root.receivedReply=true;
                    if(!reply.ok){root.error=reply.error||"Preference could not be applied";root.phase="error";}
                    else{
                        if(root.pendingAction==="set")root.values=Object.assign({},root.values,{[root.pendingName]:root.pendingValue});
                        root.phase="applied";root.feedbackTimer.restart();
                    }
                }
                catch(e) { root.receivedReply=true;root.error = "Preference could not be confirmed";root.phase="error"; }
            }
        }
        onExited:code=>{
            if(code!==0||!root.receivedReply){root.error="Preference could not be confirmed";root.phase="error";}
            root.refresh();
        }
    }
    property Timer poll: Timer { interval:3000;repeat:true;running:root.watchers>0;onTriggered:root.refresh() }
    property Process cameraEvents: Process {
        running: root.watchers > 0 && root.has("cameraDisabled")
        command: ["gsettings", "monitor", "org.gnome.desktop.privacy", "disable-camera"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("disable-camera:")) return;
                root.revision++;
                root.refresh();
            }
        }
    }
}
