import QtQuick
import QtQuick.Controls as QQC
import "../theme"
import "../services"

// A round quick-toggle with a label underneath. `checked` fills it with
// `tint`; without `checkable` it acts as a one-shot action button.
Item {
    id: root

    signal clicked()

    property string icon: ""
    property string label: ""
    property string hint: ""
    property bool checked: false
    property bool checkable: true
    property bool available: true
    property color tint: Theme.accent
    property bool keyboardPressed: false
    readonly property bool pressed: mouse.pressed || keyboardPressed
    function activate() { if (enabled && available) { feedback.play(); clicked(); } }

    enabled:available
    activeFocusOnTab:available
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
    readonly property bool lit: checkable && checked

    implicitWidth: 64
    implicitHeight: 56
    opacity: available ? 1 : 0.35

    Accessible.role: checkable ? Accessible.CheckBox : Accessible.Button
    Accessible.name: label
    Accessible.description: hint
    Accessible.checked: lit
    Accessible.onPressAction: root.activate()

    Rectangle {
        id: disc
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 38
        height: 38
        radius: 19
        color: root.lit ? root.tint : mouse.containsMouse ? Theme.surfaceRaised : Theme.surface
        border.color: root.activeFocus?Theme.accent:root.lit ? "transparent" : Theme.border
        border.width: 1
        scale: Theme.motionFactor === 0 ? 1 : root.pressed ? 0.92 : mouse.containsMouse ? 1.035 : 1

        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        Behavior on scale {
            NumberAnimation { duration: Theme.pressDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }

        AnimatedIcon {
            anchors.centerIn: parent
            name: root.icon
            size: 17
            color: root.lit ? Theme.island : Theme.text
        }
        TapFeedback { id:feedback;anchors.fill:parent;tint:root.lit?Theme.island:root.tint }
    }

    Rectangle {
        objectName: "ambientQuickLabelBacking"
        visible: ["aurora","prism","neon","candy","haunted","web","reactor","solar"].includes(Settings.ambientStyle)
        anchors.centerIn: caption
        width: Math.min(root.width + 4, caption.implicitWidth + 10)
        height: caption.height + 4
        radius: 5
        color: Qt.rgba(Theme.baseIsland.r,Theme.baseIsland.g,Theme.baseIsland.b,.78)
    }

    Label {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: disc.bottom
        anchors.topMargin: 4
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        color: root.lit ? Theme.text : ["aurora","prism","neon","candy","haunted","web","reactor","solar"].includes(Settings.ambientStyle) ? Qt.rgba(Theme.text.r,Theme.text.g,Theme.text.b,.82) : Theme.textSecondary
        font.pixelSize: Theme.fontCaption
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    QQC.ToolTip {
        id:tip
        parent:root
        visible:root.hint!==""&&mouse.containsMouse&&!mouse.pressed
        text:root.hint;delay:500;timeout:5000
        x:root.width-width;y:root.height+3
        padding:8
        contentItem:Label {width:230;text:tip.text;wrapMode:Text.WordWrap;color:Theme.text;font.pixelSize:Theme.fontSmall}
        background:Rectangle {radius:9;color:Theme.surfaceRaised;border.width:1;border.color:Theme.border}
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked:{root.forceActiveFocus();root.activate();}
    }
}
