import QtQuick
import "."
import "../../theme"
import ".."
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property color tint: Theme.accent
    property bool selected: false
    property bool keyboardPressed: false
    readonly property bool pressed: mouse.pressed || keyboardPressed
    function activate() { if (enabled) { feedback.play(); clicked(); } }
    scale:pressed&&Theme.motionFactor>0?.97:1
    Behavior on scale { NumberAnimation {duration:Theme.pressDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.springCurve} }
    Behavior on color { ColorAnimation {duration:Theme.controlDuration} }
    Behavior on border.color { ColorAnimation {duration:Theme.controlDuration} }
    signal clicked()
    implicitHeight: 30
    implicitWidth: Math.max(64, label.implicitWidth + (icon !== "" ? 42 : 22))
    radius: 9
    color: selected ? Qt.rgba(tint.r,tint.g,tint.b,.18) : mouse.containsMouse ? Theme.surfaceRaised : Theme.surface
    border.width: 1
    border.color: activeFocus ? tint : selected ? Qt.rgba(tint.r,tint.g,tint.b,.4) : Theme.border
    opacity: enabled ? 1 : .4
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text!==""?text:icon==="chevronLeft"?"Back":icon
    Keys.onPressed: event => {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key)) {
            if (!event.isAutoRepeat) keyboardPressed = true;
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key)) {
            if (!event.isAutoRepeat && keyboardPressed) { keyboardPressed = false; activate(); }
            event.accepted = true;
        }
    }
    onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
    onEnabledChanged: if (!enabled) keyboardPressed = false
    TapFeedback { id:feedback;anchors.fill:parent;radius:root.radius;tint:root.tint }
    Icon { x:10;anchors.verticalCenter:parent.verticalCenter;visible:root.icon!=="";name:root.icon;size:14;color:root.tint }
    Label {
        id:label
        anchors.fill:parent
        anchors.leftMargin:root.icon!==""?31:8
        anchors.rightMargin:8
        horizontalAlignment:root.icon!==""?Text.AlignLeft:Text.AlignHCenter
        verticalAlignment:Text.AlignVCenter
        text:root.text;color:root.selected?root.tint:Theme.text
        font.pixelSize:Theme.fontSmall;elide:Text.ElideRight
    }
    MouseArea { id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{root.forceActiveFocus();root.activate();} }
}
