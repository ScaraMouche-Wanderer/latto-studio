pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id:root
    property var names:[]
    property var reviewed:({})
    property string error:""
    property bool requested:false
    property int revision:0
    property int readerRevision:0
    property bool refreshQueued:false
    readonly property bool busy:requested||reader.running
    function refresh(){if(busy){refreshQueued=true;return;}if(!busy){requested=true;readerRevision=++revision;error="";reader.command=["/usr/bin/python",DesktopSettings.helper,"profiles"];reader.running=true;}}
    function review(name){if(!busy){requested=true;readerRevision=++revision;reviewed=({});error="";reader.command=["/usr/bin/python",DesktopSettings.helper,"profile-review",name];reader.running=true;}}
    function apply(){if(reviewed.ok===true)DesktopSettings.applyProfile(reviewed.name,reviewed.digest);}
    function clear(){revision++;reviewed=({});error="";}
    function describe(value){
        if(typeof value==="boolean")return value?"On":"Off";
        if(Array.isArray(value))return value.join(", ");
        return String(value);
    }
    readonly property var changes:Object.keys(reviewed.settings||{}).filter(key=>JSON.stringify(reviewed.settings[key])!==JSON.stringify(Settings[key])).map(key=>({label:key.replace(/([A-Z])/g," $1").replace(/^./,s=>s.toUpperCase()),value:describe(reviewed.settings[key])}))
    property Process reader:Process {
        onExited:{root.requested=false;if(root.refreshQueued){root.refreshQueued=false;Qt.callLater(root.refresh);}}
        stdout:StdioCollector {onStreamFinished:{try{
            if(root.readerRevision!==root.revision)return;
            const reply=JSON.parse(this.text);
            if(!reply.ok)root.error=reply.error||"Could not read profiles";
            else if(reply.names)root.names=reply.names;
            else root.reviewed=reply;
        }catch(e){root.error="Could not read profiles";}}}
    }
}
