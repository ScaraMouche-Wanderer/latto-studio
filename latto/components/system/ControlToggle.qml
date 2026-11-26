import QtQuick
import "."
import "../../theme"
import ".."
Rectangle {
    id:root
    property string text:""
    property string detail:""
    property string disabledReason:""
    readonly property string supportingText:!enabled&&disabledReason!==""?disabledReason:detail
    property string icon:""
    property bool checked:false
    property color tint:Theme.accent
    property bool keyboardPressed:false
    readonly property bool pressed:mouse.pressed||keyboardPressed
    function activate(){if(enabled){feedback.play();toggled(!checked);}}
    signal toggled(bool value)
    width:parent?parent.width:300
    height:supportingText!==""?46:36
    radius:11;color:mouse.containsMouse?Theme.surfaceRaised:Theme.surface
    opacity:enabled?1:.45
    activeFocusOnTab:true
    Accessible.role:Accessible.CheckBox
    Accessible.name:text
    Accessible.description:supportingText
    border.width:activeFocus?1:0;border.color:Theme.accent
    Behavior on color { ColorAnimation {duration:Theme.pressDuration} }
    Accessible.checked:checked
    Keys.onPressed:event=>{
        if([Qt.Key_Space,Qt.Key_Return,Qt.Key_Enter].includes(event.key)){
            if(!event.isAutoRepeat)keyboardPressed=true;
            event.accepted=true;
        }
    }
    Keys.onReleased:event=>{
        if([Qt.Key_Space,Qt.Key_Return,Qt.Key_Enter].includes(event.key)){
            if(!event.isAutoRepeat&&keyboardPressed){keyboardPressed=false;activate();}
            event.accepted=true;
        }
    }
    onActiveFocusChanged:if(!activeFocus)keyboardPressed=false
    onEnabledChanged:if(!enabled)keyboardPressed=false
    TapFeedback {id:feedback;anchors.fill:parent;radius:root.radius;tint:root.tint}
    Icon { x:11;anchors.verticalCenter:parent.verticalCenter;size:16;name:root.icon;color:root.checked?root.tint:Theme.textSecondary;Behavior on color {ColorAnimation {duration:Theme.controlDuration}} }
    Label { x:36;y:root.supportingText!==""?7:0;width:parent.width-90;height:root.supportingText!==""?16:parent.height;text:root.text;font.pixelSize:Theme.fontSmall;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight }
    Label { x:36;y:25;width:parent.width-90;visible:root.supportingText!=="";text:root.supportingText;color:Theme.textTertiary;font.pixelSize:Theme.fontCaption;elide:Text.ElideRight }
    Rectangle {
        id:track
        x:parent.width-45;anchors.verticalCenter:parent.verticalCenter;width:32;height:18;radius:9
        color:root.checked?root.tint:Theme.surfaceRaised;border.width:1;border.color:Theme.border
        Behavior on color {ColorAnimation {duration:Theme.controlDuration}}
        Rectangle {
            objectName:"controlToggleThumb"
            x:root.checked?track.width-width-3:3;y:3
            width:root.pressed&&Theme.motionFactor>0?14:12;height:12;radius:6
            color:root.checked?Theme.island:Theme.textSecondary
            Behavior on x {NumberAnimation {duration:Theme.controlDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.springCurve}}
            Behavior on width {NumberAnimation {duration:Theme.pressDuration;easing.type:Easing.OutCubic}}
            Behavior on color {ColorAnimation {duration:Theme.controlDuration}}
        }
    }
    MouseArea { id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{root.forceActiveFocus();root.activate();} }
}
