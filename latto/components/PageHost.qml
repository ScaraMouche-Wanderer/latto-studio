import QtQuick
import "../theme"

// Load the destination before moving the current page. Two bounded slots keep
// rapid navigation interruptible without snapshots or extra render layers.
Item {
    id: root
    property bool active: true
    property url source: ""
    property Component sourceComponent: null
    property int direction: 1
    property bool animateChanges: true
    property int current: -1
    property int pending: -1
    property bool failed: false
    property url displayedSource: ""
    property Component displayedComponent: null
    readonly property Item item: current === 0 ? first.item : current === 1 ? second.item : null
    readonly property int status: !active ? Loader.Null : failed ? Loader.Error
        : pending >= 0 ? slot(pending).status : current >= 0 ? Loader.Ready : Loader.Null
    readonly property bool transitioning: first.opacityAnimation.running || second.opacityAnimation.running
    signal loaded()
    signal loadFailed()
    clip: true

    function slot(index) { return index === 0 ? first : second; }
    function clearSlot(index) {
        const view = slot(index);
        view.motionEnabled = false;
        view.opacity = 0;
        view.offset = 0;
        view.active = false;
        view.source = "";
        view.sourceComponent = null;
    }
    function clear() {
        retire.stop(); current = -1; pending = -1; failed = false;
        displayedSource = ""; displayedComponent = null;
        clearSlot(0); clearSlot(1);
    }
    function request() {
        if (!active || (source.toString() === "" && sourceComponent === null)) { clear(); return; }
        if (current >= 0 && displayedSource === source && displayedComponent === sourceComponent && !failed) {
            if (pending >= 0) { const abandoned = pending; pending = -1; clearSlot(abandoned); }
            return;
        }
        retire.stop(); failed = false;
        const next = current === 0 ? 1 : 0;
        pending = -1; clearSlot(next); pending = next;
        const view = slot(next);
        view.requestedSource = source;
        view.requestedComponent = sourceComponent;
        view.active = true;
        if (sourceComponent !== null) view.sourceComponent = sourceComponent;
        else view.source = source;
    }
    function commit(index) {
        if (index !== pending || !active) return;
        const previous = current;
        const view = slot(index);
        if (view.requestedSource !== source || view.requestedComponent !== sourceComponent) {
            Qt.callLater(request);
            return;
        }
        const animate = previous >= 0 && animateChanges && visible && Theme.motionFactor > 0;
        const travel = direction < 0 ? -Theme.pageTravel : Theme.pageTravel;
        view.motionEnabled = false;
        view.opacity = animate ? 0 : 1;
        view.offset = animate ? travel : 0;
        current = index; pending = -1; failed = false;
        displayedSource = source; displayedComponent = sourceComponent;
        view.motionEnabled = animate;
        view.opacity = 1;
        view.offset = 0;
        if (previous >= 0) {
            const old = slot(previous);
            old.motionEnabled = animate;
            old.opacity = 0;
            old.offset = animate ? -travel : 0;
        }
        loaded();
        if (animate) retire.restart();
        else if (previous >= 0) clearSlot(previous);
    }
    function reject(index) {
        if (index !== pending) return;
        pending = -1; failed = true;
        if (current >= 0) { slot(current).opacity = 1; slot(current).offset = 0; }
        loadFailed();
    }
    onSourceChanged: Qt.callLater(request)
    onSourceComponentChanged: Qt.callLater(request)
    onActiveChanged: { if (!active) clear(); else Qt.callLater(request); }
    Component.onCompleted: Qt.callLater(request)

    component PageSlot: Loader {
        id: view
        property bool motionEnabled: false
        property url requestedSource: ""
        property Component requestedComponent: null
        property real offset: 0
        property alias opacityAnimation: fade
        anchors.fill: parent
        active: false
        asynchronous: true
        opacity: 0
        transform: Translate { x: view.offset }
        Behavior on opacity {
            enabled: view.motionEnabled && Theme.motionFactor > 0
            NumberAnimation { id: fade; duration: Theme.pageDuration; easing.type: Easing.OutCubic }
        }
        Behavior on offset {
            enabled: view.motionEnabled && Theme.motionFactor > 0
            NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
    }
    PageSlot {
        id: first
        objectName: "pageHostFirstSlot"
        z: root.current === 0 ? 1 : 0
        enabled: root.current === 0
        onLoaded: root.commit(0)
        onStatusChanged: if (status === Loader.Error) root.reject(0)
    }
    PageSlot {
        id: second
        objectName: "pageHostSecondSlot"
        z: root.current === 1 ? 1 : 0
        enabled: root.current === 1
        onLoaded: root.commit(1)
        onStatusChanged: if (status === Loader.Error) root.reject(1)
    }
    Timer {
        id: retire
        interval: Theme.pageDuration + 20
        onTriggered: if (root.current >= 0 && root.pending < 0) root.clearSlot(root.current === 0 ? 1 : 0)
    }
}
