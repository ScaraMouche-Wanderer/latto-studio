pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    readonly property bool enabled: !Settings.notificationsEnabled
    property bool ready: false
    property bool locked: true
    property bool banners: true
    property bool writable: false
    property string error: ""
    property var history: []
    readonly property int count: history.length
    readonly property int unread: history.filter(item => item.unread).length
    readonly property bool doNotDisturb: ready && !banners
    readonly property bool canSetDnd: ready && !locked && writable
    property bool focusQuietRequested: false
    property int viewers: 0
    onFocusQuietRequestedChanged: syncFocusQuiet()

    function send(data) { if (ready && !locked && listener.running) listener.write(JSON.stringify(data)+"\n"); }
    function dismiss(item) { send({action:"dismiss",key:item.key,token:item.token}); }
    function clearAll() { send({action:"clear"}); }
    function markRead() { if (unread > 0) send({action:"read"}); }
    function watchView() { viewers++; markRead(); }
    function unwatchView() { viewers = Math.max(0,viewers-1); }
    function setDnd(on) {
        if (canSetDnd) send({ action: "dnd", on: on });
    }
    function syncFocusQuiet() {
        // A timer may advance while the desktop is locked. This command has
        // no access to notification contents and the helper owns restoration.
        if (ready && listener.running)
            listener.write(JSON.stringify({ action: "focus-dnd", on: focusQuietRequested }) + "\n");
    }
    function appFor(item) {
        const id = String(item.desktopEntry || "").replace(/\.desktop$/, "");
        if (!id) return null;
        return Applications.entries.find(entry => String(entry.id).replace(/\.desktop$/, "") === id) || null;
    }
    function openApp(item) { const app=appFor(item); if(app) Applications.launch(app); }
    function accept(data) {
        try {
            const reply=JSON.parse(data);
            const wasReady = ready;
            ready=reply.ready===true; locked=reply.locked!==false;
            banners=reply.banners!==false; writable=reply.writable===true;
            error=reply.error||"";
            history=ready&&!locked&&Array.isArray(reply.history)?reply.history:[];
            if (!wasReady && ready && focusQuietRequested) syncFocusQuiet();
            if(viewers>0)markRead();
        } catch(e) { ready=false;history=[];error="Could not read desktop notifications"; }
    }
    function start() { if(enabled&&!listener.running)listener.running=true; }
    onEnabledChanged: { if(enabled)start();else { retry.stop();listener.running=false;history=[];ready=false; } }
    Component.onCompleted:start()
    property Timer retry:Timer {interval:5000;onTriggered:root.start()}
    property Process listener:Process {
        command: ["/usr/bin/python", Quickshell.shellDir + "/bin/notification-inbox.py"]
        stdinEnabled:true
        stdout:SplitParser {onRead:data=>root.accept(data)}
        onExited: {
            root.ready=false;root.history=[];
            if(root.enabled){root.error="Reconnecting to desktop notifications…";root.retry.restart();}
        }
    }
}
