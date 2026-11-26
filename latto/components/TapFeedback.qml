import QtQuick
import "../theme"

// Input acknowledgement, independent of whether a backend accepts a change.
// Event driven: no render layer and no animation while idle.
Item {
    id: root
    property color tint: Theme.accent
    property real radius: height / 2
    property real progress: 1
    readonly property bool running: pulse.running
    enabled: false
    visible: Theme.motionFactor > 0 && progress < 1
    function play() { if (Theme.motionFactor > 0) pulse.restart(); }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.07)
        border.width: 1
        border.color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.4)
        opacity: 1 - root.progress
        scale: 0.94 + 0.06 * root.progress
    }
    NumberAnimation {
        id: pulse
        target: root; property: "progress"
        from: 0; to: 1
        duration: Theme.feedbackDuration
        easing.type: Easing.OutCubic
    }
}
