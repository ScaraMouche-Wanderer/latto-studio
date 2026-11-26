import QtQuick
import "../theme"

// A local drill-in view, kept alive until its directional fade has finished.
// Movement stays on the scene graph, without a blur texture or scale change.
Item {
    id: root

    property bool shown: true
    property real travel: Theme.pageTravel
    property real offset: shown ? 0 : travel

    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    enabled: shown
    transform: Translate { x: root.offset }

    Behavior on opacity {
        NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
    }
    Behavior on offset {
        NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
    }
}
