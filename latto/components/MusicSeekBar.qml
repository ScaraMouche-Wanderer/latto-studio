import QtQuick
import "../services"
import "../theme"

Item {
    id:root
    objectName:"musicSeekControl"
    height:28
    readonly property bool available:!!Media.player&&Media.player.canSeek&&Media.length>0
    property real preview:-1
    property bool held:false
    property var dragPlayer:null
    property string dragTitle:""
    readonly property real shown:preview>=0?preview:Media.position
    readonly property real fraction:Media.length>0?Math.max(0,Math.min(1,shown/Media.length)):0
    function releaseHold(){if(held){held=false;IslandState.release();}}
    function cancel(){preview=-1;dragPlayer=null;releaseHold();settle.stop();}
    function commit(seconds){if(available)Media.seek(Math.max(0,Math.min(Media.length,seconds))/Media.length);}
    onAvailableChanged:if(!available)cancel()
    Connections {target:Media;function onPlayerChanged(){root.cancel();}function onTitleChanged(){root.cancel();}function onPositionChanged(){if(!mouse.pressed&&root.preview>=0&&Math.abs(Media.position-root.preview)<1)root.preview=-1;}}
    Component.onDestruction:releaseHold()
    Timer {id:settle;interval:1000;onTriggered:root.preview=-1}
    Label {x:0;width:38;anchors.verticalCenter:parent.verticalCenter;text:Timers.formatTime(root.shown*1000,false);font.pixelSize:Theme.fontCaption;color:root.preview>=0?Theme.accent:Theme.textTertiary}
    Label {anchors.right:parent.right;width:39;anchors.verticalCenter:parent.verticalCenter;horizontalAlignment:Text.AlignRight;text:Media.length>0?Timers.formatTime(Media.length*1000,false):"—";font.pixelSize:Theme.fontCaption;color:Theme.textTertiary}
    Item {
        id:track;objectName:"musicSeekTrack";x:43;width:Math.max(1,parent.width-88);height:parent.height
        activeFocusOnTab:root.available
        Accessible.role:Accessible.Slider;Accessible.name:"Track position";Accessible.description:Math.round(root.shown)+" seconds"
        Keys.onLeftPressed:root.commit(Media.position-5)
        Keys.onRightPressed:root.commit(Media.position+5)
        Keys.onPressed:event=>{if(event.key===Qt.Key_Home){root.commit(0);event.accepted=true;}else if(event.key===Qt.Key_End){root.commit(Media.length);event.accepted=true;}else event.accepted=false;}
        Rectangle {anchors.verticalCenter:parent.verticalCenter;width:parent.width;height:mouse.containsMouse||track.activeFocus?6:4;radius:3;color:Theme.surfaceRaised}
        Rectangle {anchors.verticalCenter:parent.verticalCenter;width:parent.width*root.fraction;height:mouse.containsMouse||track.activeFocus?6:4;radius:3;color:root.available?Theme.accent:Theme.textTertiary}
        Rectangle {x:Math.max(0,Math.min(parent.width-width,parent.width*root.fraction-width/2));anchors.verticalCenter:parent.verticalCenter;width:10;height:10;radius:5;color:Theme.accent;visible:root.available&&(mouse.containsMouse||mouse.pressed||track.activeFocus)}
        MouseArea {
            id:mouse;objectName:"musicSeekMouse";anchors.fill:parent;enabled:root.available;hoverEnabled:true;preventStealing:true;cursorShape:Qt.PointingHandCursor
            function pick(x){root.preview=Math.max(0,Math.min(1,x/Math.max(1,width)))*Media.length;}
            onPressed:event=>{track.forceActiveFocus();root.dragPlayer=Media.player;root.dragTitle=Media.title;settle.stop();if(!root.held){root.held=true;IslandState.holdOpen();}pick(event.x);}
            onPositionChanged:event=>{if(pressed&&root.dragPlayer===Media.player&&root.dragTitle===Media.title)pick(event.x);}
            onReleased:{if(root.dragPlayer===Media.player&&root.dragTitle===Media.title)root.commit(root.preview);root.releaseHold();root.dragPlayer=null;settle.restart();}
            onCanceled:root.cancel()
        }
    }
}
