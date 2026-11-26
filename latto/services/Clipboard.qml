pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard payloads stay local; only bounded previews reach the island.
QtObject {
    id: root
    readonly property bool enabled: Settings.clipboardEnabled
    readonly property int maxItems: Math.max(50,Math.min(100,Settings.clipboardHistoryLimit))
    property bool ready: false
    property bool locked: true
    property bool paused: false
    property int count: 0
    property int limit: maxItems
    property real totalBytes: 0
    property string error: ""
    property string busyId: ""
    property string copiedId: ""
    property string query: ""
    property string kind: "all"
    property var items: []
    property string itemSignature: ""
    signal restored(string id)
    function send(data) { if(ready && !locked && listener.running) { listener.write(JSON.stringify(data)+"\n"); } }
    function refresh() { send({action:"refresh"}); }
    function search(text, filter) { send({action:"search",query:text,kind:filter}); }
    function copy(id) { if(ready&&!locked&&!busyId) {busyId=id;copyTimeout.restart();send({action:"copy",id:id});} }
    function remove(id) { send({action:"delete",id:id}); }
    function clear() { send({action:"clear"}); }
    function togglePause() { send({action:"pause",paused:!paused}); }
    function accept(line) {
        try {
            const data=JSON.parse(line);
            ready=data.ready===true;locked=data.locked!==false;paused=data.paused===true;
            count=data.count||0;limit=data.limit||maxItems;totalBytes=data.totalBytes||0;
            error=data.error||"";query=data.query||"";kind=data.kind||"all";
            if(ready&&!locked&&limit!==maxItems)send({action:"limit",limit:maxItems});
            const rows=ready&&!locked&&Array.isArray(data.items)?data.items:[];
            const signature=JSON.stringify(rows);
            if(signature!==itemSignature){itemSignature=signature;items=rows;}
            if(data.copied){copiedId=data.copied;busyId="";copyTimeout.stop();copiedReset.restart();restored(data.copied);}
            if(error||locked){busyId="";copyTimeout.stop();}
        } catch(e) { ready=false;items=[];error="Could not read clipboard history"; }
    }
    function start() { if(enabled&&!listener.running)listener.running=true; }
    onEnabledChanged: {
        if(enabled)start();
        else {retry.stop();listener.running=false;ready=false;items=[];itemSignature="";busyId="";count=0;}
    }
    Component.onCompleted: start()
    property Connections config: Connections {
        target:Settings
        function onClipboardHistoryLimitChanged(){root.send({action:"limit",limit:root.maxItems});}
    }
    property Timer copiedReset:Timer {interval:1800;onTriggered:root.copiedId=""}
    property Timer copyTimeout:Timer {interval:4000;onTriggered:{root.busyId="";root.error="Clipboard restore timed out. Try again.";}}
    property Timer retry:Timer {interval:5000;onTriggered:root.start()}
    property Process listener:Process {
        command:["/usr/bin/python",Quickshell.env("HOME")+"/Apps/Latto/bin/clipboard-history.py","--limit",String(root.maxItems)]
        stdinEnabled:true
        stdout:SplitParser {onRead:line=>root.accept(line)}
        onExited:{root.ready=false;root.locked=true;root.items=[];root.itemSignature="";root.busyId="";if(root.enabled){root.error="Reconnecting to clipboard history…";root.retry.restart();}}
    }
}
