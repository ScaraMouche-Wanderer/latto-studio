import QtQuick
import "../theme"

// Crossfade state changes such as play/pause and mute/unmute at icon size.
// Both vectors stay on the scene graph; static icons have no running timer.
Item {
    id: root
    property string name: ""
    property color color: Theme.text
    property real size: 16
    property string currentName: ""
    property string previousName: ""
    property real progress: 1
    property bool initialized: false
    readonly property bool transitioning: change.running
    implicitWidth: size
    implicitHeight: size
    function update() {
        if (currentName === name) return;
        change.stop();
        previousName = initialized && visible && Theme.motionFactor > 0 ? currentName : "";
        currentName = name;
        if (previousName !== "") change.restart();
        else progress = 1;
    }
    onNameChanged: update()
    Component.onCompleted: { update(); initialized = true; }
    Icon {
        anchors.centerIn: parent; size: root.size
        name: root.previousName; color: root.color
        opacity: 1 - root.progress
        scale: 1 - 0.12 * root.progress
        visible: name !== "" && opacity > 0
    }
    Icon {
        anchors.centerIn: parent; size: root.size
        name: root.currentName; color: root.color
        opacity: root.progress
        scale: 0.84 + 0.16 * root.progress
        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
    }
    NumberAnimation {
        id: change
        target: root; property: "progress"
        from: 0; to: 1
        duration: Theme.controlDuration
        easing.type: Easing.OutCubic
        onFinished: root.previousName = ""
    }
}
