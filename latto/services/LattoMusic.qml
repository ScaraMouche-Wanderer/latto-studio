pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id:root
    property var state: ({ready:false,results:[],searching:false,hasMore:false,query:"",phase:"idle",error:""})
    property string connectionError: ""
    readonly property bool ready: peer.connected && state.ready === true
    property bool submitting:false
    property string requestedQuery:""
    // View preferences live for this island session, without writing history.
    property bool cleanOnly:false
    property string resultSort:"match"
    readonly property bool searching: submitting || state.searching === true
    property var catalog: []
    property string catalogSignature: ""
    readonly property var results: catalog
    signal catalogAboutToChange(bool append)
    readonly property string query: state.query || ""
    readonly property string error: connectionError || state.error || ""
    readonly property string phase: state.phase || "idle"
    property var pendingSearch:null
    function send(data) { if(ready) {peer.write(JSON.stringify(data)+"\n");peer.flush();} }
    function search(text,limit) {
        const query=text.trim();if(!query||submitting)return;
        submitting=true;requestedQuery=query;
        const request={action:"search",query:query,limit:limit||20};
        if(!ready){pendingSearch=request;connectionError="Starting the music player…";if(!starter.running)starter.running=true;return;}
        connectionError="";send(request);
    }
    function more() { if(!searching&&state.hasMore)search(query,Math.min(100,(state.limit||20)+20)); }
    function play(id) {
        send({action:"play",id:id});
        const player=Media.players.find(item=>item.dbusName==="org.mpris.MediaPlayer2.Latto");
        if(player)Media.selectPlayer(player);
    }
    function nativePlayer() { return Media.players.find(item=>item.dbusName==="org.mpris.MediaPlayer2.Latto") || null; }
    function activate(id) {
        const same=state.track&&state.track.id===id;
        if(same&&phase==="loading")return;
        const player=nativePlayer();
        if(same&&(phase==="playing"||phase==="paused")&&player&&player.canTogglePlaying){Media.selectPlayer(player);player.togglePlaying();return;}
        play(id);
    }
    function retry() {
        const target=query||requestedQuery||(pendingSearch?pendingSearch.query:"");
        if(target)search(target,state.limit||20);
        else if(!ready&&!starter.running)starter.running=true;
    }
    function stop() { send({action:"stop"}); }
    function accept(data) {
        try {
            const reply=JSON.parse(data);
            if(!Array.isArray(reply.results))return;
            const signature=JSON.stringify(reply.results);
            if(signature!==catalogSignature){
                const append=reply.results.length>catalog.length&&catalog.length>0&&catalog.every((entry,index)=>entry.id===reply.results[index].id);
                catalogAboutToChange(append);
                catalogSignature=signature;catalog=reply.results;
            }
            state=reply;connectionError="";
            if(reply.query===requestedQuery)submitting=false;
            if(pendingSearch){const request=pendingSearch;pendingSearch=null;send(request);}
        } catch(e) {connectionError="Could not read music player state";}
    }
    property Process starter:Process {
        command:["systemctl","--user","start","latto-player.service"]
        running:true
        onExited:exitCode=>{if(exitCode===0)peer.connected=true;else {root.connectionError="Could not start the music player";root.submitting=false;}}
    }
    property Socket peer:Socket {
        path:Quickshell.env("XDG_RUNTIME_DIR")+"/latto-player/control.sock"
        parser:SplitParser {onRead:data=>root.accept(data)}
        onConnectionStateChanged:if(!connected){root.submitting=false;root.state=Object.assign({},root.state,{ready:false});}
        onError:root.connectionError="Connecting to the music player…"
    }
    property Timer reconnect:Timer {interval:1500;running:!peer.connected;repeat:true;onTriggered:peer.connected=true}
}
