import QtQuick
import "../services"
import "../theme"

Item {
    id:root
    objectName:"musicPlayerVolume"
    width:116;height:28
    readonly property var player:Media.player
    readonly property bool available:!!player&&player.volumeSupported
    readonly property real value:available?Math.max(0,Math.min(1,player.volume)):0
    property real lastVolume:.65
    property real preview:-1
    property bool held:false
    property var dragPlayer:null
    readonly property real shown:preview>=0?preview:value
    onValueChanged:{if(value>0)lastVolume=value;if(!mouse.pressed&&preview>=0&&Math.abs(value-preview)<.01)preview=-1;}
    onPlayerChanged:{cancel();lastVolume=value>0?value:.65;}
    function cancel(){preview=-1;dragPlayer=null;if(held){held=false;IslandState.release();}}
    function setVolume(value){if(available)player.volume=Math.max(0,Math.min(1,value));}
    function toggleMute(){if(available)setVolume(value>0?0:Math.max(.05,lastVolume));}
    Component.onDestruction:if(held)IslandState.release()
    Timer {id:settle;interval:800;onTriggered:root.preview=-1}
    Label {objectName:"musicVolumeUnavailable";anchors.fill:parent;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;text:"App volume unavailable";font.pixelSize:9;color:Theme.textTertiary;visible:!root.available}
    IslandButton {objectName:"musicMuteButton";width:26;height:28;visible:root.available;icon:root.value<.005?"volumeOff":"volume";iconSize:14;enabled:root.available;color:Theme.textSecondary;accessibleLabel:root.value>0?"Mute this player":"Unmute this player";hint:"Player volume · "+Math.round(root.shown*100)+"%";onClicked:root.toggleMute()}
    Item {
        id:slider;objectName:"musicVolumeTrack";x:34;width:parent.width-34;height:parent.height;visible:root.available
        activeFocusOnTab:root.available
        Accessible.role:Accessible.Slider;Accessible.name:"Player volume";Accessible.description:Math.round(root.shown*100)+" percent"
        Keys.onLeftPressed:root.setVolume(root.value-.05)
        Keys.onRightPressed:root.setVolume(root.value+.05)
        Keys.onPressed:event=>{if(event.key===Qt.Key_Home){root.setVolume(0);event.accepted=true;}else if(event.key===Qt.Key_End){root.setVolume(1);event.accepted=true;}else event.accepted=false;}
        Rectangle {anchors.verticalCenter:parent.verticalCenter;width:parent.width;height:4;radius:2;color:Theme.surfaceRaised}
        Rectangle {anchors.verticalCenter:parent.verticalCenter;width:parent.width*root.shown;height:4;radius:2;color:Theme.accent}
        Rectangle {x:Math.max(0,Math.min(parent.width-width,parent.width*root.shown-width/2));anchors.verticalCenter:parent.verticalCenter;width:8;height:8;radius:4;color:Theme.accent;visible:root.available&&(mouse.containsMouse||mouse.pressed||slider.activeFocus)}
        Label {anchors.right:parent.right;y:-6;text:Math.round(root.shown*100)+"%";font.pixelSize:9;color:Theme.accent;visible:root.available&&(mouse.containsMouse||mouse.pressed||slider.activeFocus)}
        MouseArea {
            id:mouse;anchors.fill:parent;enabled:root.available;hoverEnabled:true;preventStealing:true;cursorShape:Qt.PointingHandCursor
            function pick(x){if(root.dragPlayer!==root.player)return;root.preview=Math.max(0,Math.min(1,x/Math.max(1,width)));root.setVolume(root.preview);}
            onPressed:event=>{slider.forceActiveFocus();root.dragPlayer=root.player;if(!root.held){root.held=true;IslandState.holdOpen();}pick(event.x);}
            onPositionChanged:event=>{if(pressed)pick(event.x);}
            onReleased:{if(root.held){root.held=false;IslandState.release();}root.dragPlayer=null;settle.restart();}
            onCanceled:root.cancel()
        }
    }
}
