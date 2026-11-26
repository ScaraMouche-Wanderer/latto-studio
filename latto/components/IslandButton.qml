import QtQuick
import QtQuick.Controls as QQC
import "../theme"

// Round button showing an icon, a text label, or both. Hover tints it, press
// squeezes it. `primary` gives a solid light fill, used for the play button.
Item {
    id: root

    signal clicked()

    property string hint:""
    property string accessibleLabel:text!==""?text:icon
    property bool keyboardPressed:false
    readonly property bool pressed:mouse.pressed||keyboardPressed
    function activate() { if (enabled) { feedback.play(); clicked(); } }
    activeFocusOnTab:true
    QQC.ToolTip {
        id:hintPopup
        parent:root
        text:root.hint
        visible:text!==""&&mouse.containsMouse&&!mouse.pressed
        delay:500;timeout:2000
        x:(root.width-width)/2;y:root.height+6
        padding:7;topPadding:5;bottomPadding:5
        contentItem:Label {text:hintPopup.text;color:Theme.text;font.pixelSize:Theme.fontCaption}
        background:Rectangle {radius:8;color:Theme.surfaceRaised;border.width:1;border.color:Theme.border}
    }
    Accessible.role:Accessible.Button
    Accessible.name:accessibleLabel
    Accessible.description:hint
    Accessible.onPressAction:root.activate()
    Keys.onPressed:event=>{
        if(event.key===Qt.Key_Space||event.key===Qt.Key_Return||event.key===Qt.Key_Enter){
            if(!event.isAutoRepeat)keyboardPressed=true;
            event.accepted=true;
        }
    }
    Keys.onReleased:event=>{
        if(event.key===Qt.Key_Space||event.key===Qt.Key_Return||event.key===Qt.Key_Enter){
            if(!event.isAutoRepeat&&keyboardPressed){keyboardPressed=false;activate();}
            event.accepted=true;
        }
    }
    onActiveFocusChanged:if(!activeFocus)keyboardPressed=false
    onEnabledChanged:if(!enabled)keyboardPressed=false
    opacity:enabled?1:.4
    property string icon: ""
    property string text: ""
    property real iconSize: 18
    property int fontSize: Theme.fontBody
    property bool primary: false
    property bool subtle: false        // faint fill even when not hovered
    property color color: primary ? Theme.island : Theme.text

    implicitHeight: Math.max(iconSize, label.implicitHeight) + 14
    implicitWidth: text === "" ? implicitHeight : content.implicitWidth + 26

    scale: root.pressed && Theme.motionFactor > 0 ? 0.95 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.pressDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.text
        opacity: root.primary ? (mouse.containsMouse ? 0.88 : 1)
            : root.pressed ? 0.18
            : mouse.containsMouse ? 0.1
            : root.subtle ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
    }
    Rectangle {
        objectName:"islandButtonFocusRing"
        anchors.fill:parent;radius:height/2;color:"transparent"
        border.width:root.activeFocus?1.5:0;border.color:Theme.accent
    }
    TapFeedback { id:feedback;objectName:"buttonTapFeedback";anchors.fill:parent;tint:root.primary?Theme.island:Theme.accent }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        AnimatedIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: root.iconSize
            color: root.color
        }
        Label {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            color: root.color
            font.pixelSize: root.fontSize
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked:{root.forceActiveFocus();root.activate();}
    }
}
