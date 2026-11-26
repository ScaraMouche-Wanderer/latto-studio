import QtQuick
import "../theme"

Rectangle {
    id: drop

    property real edgeY: 0
    property real releaseEdgeY: 0
    property real progress: 1
    readonly property real release: 0.31
    readonly property real impact: 0.54
    readonly property real secondImpact: 0.83
    readonly property real originY: progress < release ? edgeY : releaseEdgeY
    readonly property real impactY: Math.min(parent.height - 3, originY + 35)
    readonly property real travel: Math.max(0, impactY - originY)
    readonly property real releaseTravel: Math.min(22, travel)
    readonly property real extension: progress < release
        ? releaseTravel * smooth(progress / release) : 0
    readonly property real size: 1 - Math.pow(Math.max(0, (progress - release) / (1 - release)), 2)
    readonly property real lift: {
        if (progress < release)
            return travel - releaseTravel;
        if (progress <= impact) {
            const fall = (progress - release) / (impact - release);
            return (travel - releaseTravel) * (1 - fall * fall);
        }
        const firstHop = progress <= secondImpact;
        const start = firstHop ? impact : secondImpact;
        const end = firstHop ? secondImpact : 1;
        const time = (progress - start) / (end - start);
        return Math.min(firstHop ? 13 : 6, travel / 3) * 4 * time * (1 - time);
    }

    function smooth(value) {
        const t = Math.max(0, Math.min(1, value));
        return t * t * (3 - 2 * t);
    }

    function play(opening) {
        if (!enabled || delay.running || flight.running)
            return;
        delay.interval = Math.round((opening ? 65 : 45) * Theme.motionFactor);
        delay.start();
    }

    onEnabledChanged: if (!enabled) {
        delay.stop();
        flight.stop();
        progress = 1;
    }
    onProgressChanged: {
        // Follow the live edge during the stretch, then freeze the launch point.
        if (progress < release)
            releaseEdgeY = edgeY;
    }

    objectName: "islandWaterDrop"
    visible: enabled && progress >= release && progress < 1 && height > 0.5
    anchors.horizontalCenter: parent.horizontalCenter
    y: impactY - lift - height
    width: height
    height: Math.max(0, releaseTravel - 3) * size
    radius: height / 2
    color: Theme.island
    border.width: 0
    antialiasing: true

    Timer { id: delay; onTriggered: flight.start() }

    NumberAnimation {
        id: flight
        target: drop
        property: "progress"
        from: 0
        to: 1
        duration: Math.round(720 * Theme.motionFactor)
    }
}
