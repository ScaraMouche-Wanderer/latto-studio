import QtQuick
import QtQuick.Controls as QQC
import "../theme"

// One icon segment of the expanded view's tab bar. The sliding highlight
// behind the selected segment is drawn by ExpandedView.
Item {
    id: root

    signal activated()

    property string icon: ""
    // The tab's name, for screen readers.
    property string text: ""
    property string shortcutHint: ""
    property bool selected: false
    property int badge: 0
    property bool keyboardPressed: false
    readonly property bool pressed: mouse.pressed || keyboardPressed
    function activate() { if (enabled) { feedback.play(); activated(); } }

    implicitWidth: 44
    implicitHeight: 26

    activeFocusOnTab:true
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
    QQC.ToolTip {
        id:hintPopup
        parent:root
        text:root.text+(root.shortcutHint!==""?" · "+root.shortcutHint:"")
        visible:text!==""&&mouse.containsMouse&&!mouse.pressed
        delay:500;timeout:2000
        x:(root.width-width)/2;y:root.height+6
        padding:7;topPadding:5;bottomPadding:5
        contentItem:Label {text:hintPopup.text;color:Theme.text;font.pixelSize:Theme.fontCaption}
        background:Rectangle {radius:8;color:Theme.surfaceRaised;border.width:1;border.color:Theme.border}
    }
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.description: shortcutHint + (badge > 0 ? " · " + badge + " unread" : "")
    Accessible.selected: selected
    Accessible.selectable: true
    Accessible.onPressAction: root.activate()

    Rectangle {
        anchors.fill:parent;anchors.margins:2;radius:10
        color:Theme.text;opacity:root.pressed?.1:mouse.containsMouse&&!root.selected?.055:0
        Behavior on opacity { NumberAnimation { duration:Theme.pressDuration } }
    }
    Rectangle { anchors.fill:parent;radius:10;color:"transparent";border.width:root.activeFocus?1:0;border.color:Theme.accent }
    TapFeedback { id:feedback;anchors.fill:parent;radius:10 }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: 15
        color: root.selected ? Theme.accent : mouse.containsMouse ? Theme.text : Theme.textTertiary
        scale: Theme.motionFactor === 0 ? 1 : root.pressed ? 0.9 : root.selected ? 1.08 : 1

        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        Behavior on scale {
            NumberAnimation { duration: Theme.pressDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }
    }

    Rectangle {
        x:27;y:0;width:root.badge>9?19:14;height:14;radius:7
        color:Theme.accent;visible:root.badge>0
        Label {anchors.centerIn:parent;text:root.badge>9?"9+":root.badge;font.pixelSize:9;font.weight:Font.DemiBold;color:Theme.island}
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked:{root.forceActiveFocus();root.activate();}
    }
}
