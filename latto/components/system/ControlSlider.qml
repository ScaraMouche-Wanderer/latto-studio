import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
Item {
    id:root
    property string text:""
    property string icon:""
    property string disabledReason:""
    property string suffix:"%"
    property real from:0
    property real to:100
    property real value:0
    property real preview:-1
    property bool live:false
    property bool held:false
    property bool waiting:false
    property real stepSize:.01
    property color tint:Theme.accent
    readonly property real displayValue:preview>=0?preview:value
    signal moved(real fraction)
    signal committed(real fraction)
    width:parent?parent.width:300;height:!enabled&&disabledReason!==""?60:44
    opacity:enabled?1:.4
    activeFocusOnTab:true
    Accessible.role:Accessible.Slider
    Accessible.name:text
    Accessible.description:!enabled?disabledReason:Math.round(root.from+(root.to-root.from)*root.displayValue)+root.suffix
    onValueChanged:if(waiting&&!mouse.pressed&&Math.abs(value-preview)<.015){preview=-1;waiting=false;settle.stop();}
    Component.onDestruction:if(held){held=false;IslandState.release();}
    function commit(value){preview=Math.max(0,Math.min(1,value));waiting=true;committed(preview);settle.restart();}
    Keys.onLeftPressed:event=>commit(displayValue-((event.modifiers&Qt.ShiftModifier)?.05:stepSize))
    Keys.onRightPressed:event=>commit(displayValue+((event.modifiers&Qt.ShiftModifier)?.05:stepSize))
    Keys.onDownPressed:event=>commit(displayValue-((event.modifiers&Qt.ShiftModifier)?.05:stepSize))
    Keys.onUpPressed:event=>commit(displayValue+((event.modifiers&Qt.ShiftModifier)?.05:stepSize))
    Keys.onPressed:event=>{
        if(event.key===Qt.Key_Home){commit(0);event.accepted=true;}
        else if(event.key===Qt.Key_End){commit(1);event.accepted=true;}
        else event.accepted=false;
    }
    Timer { id:settle;interval:2500;onTriggered:if(!mouse.pressed){root.preview=-1;root.waiting=false;} }
    Icon { x:0;y:0;size:15;name:root.icon;color:root.tint }
    Label { x:root.icon!==""?23:0;y:0;width:parent.width-100;text:root.text;font.pixelSize:Theme.fontSmall;elide:Text.ElideRight }
    Label { anchors.right:parent.right;y:0;text:Math.round(root.from+(root.to-root.from)*root.displayValue)+root.suffix;font.pixelSize:Theme.fontSmall;color:root.tint }
    IslandBar { id:bar;x:1;y:29;width:parent.width-2;height:6;value:root.displayValue;fillColor:root.tint;animateValue:!mouse.pressed }
    Rectangle {
        objectName:"controlSliderThumb"
        x:Math.max(0,Math.min(parent.width-width,bar.x+bar.width*root.displayValue-width/2));y:25
        width:14;height:14;radius:7;color:root.tint
        opacity:mouse.containsMouse||mouse.pressed||root.activeFocus?1:0
        visible:opacity>.001
        scale:Theme.motionFactor===0?1:mouse.pressed?1.16:opacity>.01?1:.75
        Behavior on opacity {NumberAnimation {duration:Theme.pressDuration}}
        Behavior on scale {NumberAnimation {duration:Theme.pressDuration;easing.type:Easing.OutCubic}}
        Behavior on x {enabled:!mouse.pressed;NumberAnimation {duration:Theme.pageDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.smoothCurve}}
    }
    Label { y:44;width:parent.width;visible:!root.enabled&&root.disabledReason!=="";text:root.disabledReason;font.pixelSize:Theme.fontCaption;color:Theme.textTertiary;elide:Text.ElideRight }
    MouseArea {
        id:mouse;x:0;y:18;width:parent.width;height:26
        hoverEnabled:true;preventStealing:true;cursorShape:Qt.PointingHandCursor
        function pick(x){root.preview=Math.max(0,Math.min(1,x/Math.max(1,width)));if(root.live)root.moved(root.preview);}
        onPressed:mouse=>{root.forceActiveFocus();settle.stop();if(!root.held){root.held=true;IslandState.holdOpen();}pick(mouse.x);}
        onPositionChanged:mouse=>{if(pressed)pick(mouse.x);}
        onReleased:{root.commit(root.preview);if(root.held){root.held=false;IslandState.release();}}
        onCanceled:{root.commit(root.preview);if(root.held){root.held=false;IslandState.release();}}
    }
}
