import QtQuick

// Shared geometry with Studio's battery preview: 20 × 11 logical pixels.
Item {
    id: root
    property real percent: 0
    property color color: "white"
    implicitWidth: 20
    implicitHeight: 11
    Rectangle {
        x: 0; y: 0.5; width: 17; height: 10
        radius: 2
        color: "transparent"
        border.width: 1
        border.color: root.color
    }
    Rectangle {
        x: 2; y: 2.5
        width: 13 * Math.max(0, Math.min(100, root.percent)) / 100
        height: 6
        radius: 0.8
        color: root.color
    }
    Rectangle {
        x: 18; y: 3.5; width: 2; height: 4; radius: 0.8
        color: root.color
    }
}
