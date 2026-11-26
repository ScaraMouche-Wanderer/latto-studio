import QtQuick
import "../theme"

// Horizontal fill bar for a value in 0..1.
Rectangle {
    id: root

    property real value: 0
    property bool animateValue: true
    property color fillColor: Theme.text

    implicitHeight: 5
    radius: height / 2
    color: Theme.surfaceRaised

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
    }

    Rectangle {
        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
        height: parent.height
        radius: height / 2
        color: root.fillColor
        visible: root.value > 0

        Behavior on width {
            enabled: root.animateValue
            NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
    }
}
