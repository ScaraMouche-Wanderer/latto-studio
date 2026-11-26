import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "services"
import "components"
import "theme"

// One island per monitor, anchored top-centre. The window spans the full width
// so the pill can grow, while the input mask limits the pointer to the pill.
PanelWindow {
    id: window

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    // Keep the transparent native surface stable. Resizing an X11 surface
    // during the pill animation makes the compositor replace its backing
    // pixmap and can flash the entire island. The Region below still limits
    // input to the visible shape; this extra space does not intercept clicks.
    implicitHeight: Math.min(window.screen?window.screen.height:800,
        Theme.topMargin+640+48)
    // Overlay applications without reducing their usable screen area. Only
    // the visible island takes pointer input; the rest passes through.
    exclusiveZone: 0
    aboveWindows: true
    // Passive mode leaves actual keyboard focus with the current app.
    // It does not alter browser APIs or intercept another app's keystrokes.
    focusable: window.expanded && (!Settings.preserveAppFocus || window.keyboardInput)
    color: "transparent"
    // At rest only the tiny edge target takes input. Keep the pill in the
    // shape during its exit animation so the compositor does not cut it off.
    // XCB applies this as a visual bounding shape as well as an input shape.
    // Item geometry alone defaults to square corners and cuts the shadow into
    // a dark rectangle around the pill. Keep its shape in sync while morphing.
    mask: Region {
        objectName:"islandWindowMask"
        item: !Settings.edgeReveal && window.shapeVisible ? pill : null
        radius: Math.max(0,Math.round(pill.radius))
        NotchMask {
            surface: notchSurface; body: notchBody
            active: Settings.edgeReveal && window.shapeVisible
        }
        Region { item: window.edgeActivation ? edgeTarget : null; intersection: Intersection.Combine }
        // Extend the native mask while the center of the outline stretches.
        Region {
            intersection: Intersection.Combine
            x: Math.floor(pill.x + pill.width / 2 - notchSurface.dipHalfWidth * pill.scale)
            y: Math.floor(pill.y + pill.height * pill.scale) - 1
            width: notchSurface.dip > 0 ? Math.ceil(2 * notchSurface.dipHalfWidth * pill.scale) + 2 : 0
            height: notchSurface.dip > 0 ? Math.ceil(notchSurface.dip * pill.scale) + 3 : 0
        }
        Region {
            intersection: Intersection.Combine
            x: Math.floor(waterDrop.x) - 1
            y: Math.floor(waterDrop.y) - 1
            width: waterDrop.visible ? Math.ceil(waterDrop.width) + 3 : 0
            height: waterDrop.visible ? Math.ceil(waterDrop.height) + 3 : 0
        }
    }

    // `open` follows the pointer with a short delay each way: brushing past
    // does not open the island, and leaving it always closes it.
    property bool open: false
    property bool keyboardInput: false
    property bool keyboardPending: false
    property bool keyboardFailed: false
    readonly property bool keyboardActive: expandedView.Window.active
    Component.onCompleted: Qt.callLater(function() {
        if (expandedView.Window.window) expandedView.Window.window.title = "Latto Island";
    })
    property bool edgeRevealed: false
    readonly property bool shapeVisible: mode !== "hidden" || pill.opacity > 0.001
    readonly property bool edgeActivation: Settings.edgeReveal && !Settings.compactAlwaysVisible
    readonly property bool pointerInside: hover.hovered || (edgeActivation && edgeHover.hovered)
    onOpenChanged: {
        waterDrop.play(open);
        if (open) { edgeRevealed = true; openTimer.stop(); releaseFocusTimer.stop(); }
        else { keyboardCommit.stop();if(activateFocus.running)activateFocus.signal(15);keyboardInput=false;keyboardPending=false;keyboardFailed=false; expandedView.rememberClosedTab(); releaseFocusTimer.restart(); }
    }

    // Apply the next section before expanding, without swapping the outgoing
    // page or changing its geometry during the close animation.
    function openIsland(tab) {
        if (!window.open) expandedView.prepareOpen(tab || "");
        else if (tab) expandedView.selectTab(tab);
        else if (expandedView.summaryEnabled) expandedView.showSummary();
        openTimer.stop(); edgeTimer.stop(); closeTimer.stop();
        window.open = true;
    }

    // Hover stays passive. Clicks and keyboard requests explicitly focus the
    // island; closing hands focus back after its motion has finished.
    function focusForKeyboard() {
        Qt.callLater(function() {
            // Focusability is a binding. Let a just-opened panel or an
            // explicit keyboard opt-in commit before requesting activation.
            if (!window.focusable) return;
            expandedView.focusKeyboardTarget();
            if (Quickshell.env("QT_QPA_PLATFORM") === "xcb") keyboardCommit.restart();
            else window.keyboardPending=false;
        });
    }
    function setKeyboardInput(value) {
        if (!window.open || !Settings.preserveAppFocus) return;
        window.keyboardInput = value;
        window.keyboardPending = value;
        window.keyboardFailed = false;
        if (value) window.focusForKeyboard();
        else releaseFocusTimer.restart();
    }
    onKeyboardActiveChanged: {
        if (!keyboardActive && keyboardInput && !keyboardPending && Settings.preserveAppFocus)
            setKeyboardInput(false);
    }
    Timer {
        id:keyboardCommit
        interval:32
        onTriggered:if(window.focusable)activateFocus.running=true
    }
    Process {
        id: activateFocus
        command: ["/usr/bin/python", Quickshell.shellDir + "/bin/island-focus.py", "activate", String(Quickshell.processId)]
        stdout: StdioCollector { onStreamFinished: {
            if (!window.open || !window.keyboardInput) return;
            window.keyboardPending=false;
            try { window.keyboardFailed=!JSON.parse(text).ok; }
            catch(error) { window.keyboardFailed=true; }
            if (!window.keyboardFailed) Qt.callLater(expandedView.focusKeyboardTarget);
        }}
        onExited: if (window.keyboardPending) {window.keyboardPending=false;window.keyboardFailed=true;}
    }
    Process {
        id: releaseFocus
        command: ["/usr/bin/python", Quickshell.shellDir + "/bin/island-focus.py", "release", String(Quickshell.processId)]
    }
    Timer {
        id: releaseFocusTimer
        interval: window.open ? 0
            : (window.liquidMotion && window.mode !== "hidden" ? window.liquidCloseDuration : Theme.collapseDuration) + 32
        onTriggered: if (!window.focusable && Quickshell.env("QT_QPA_PLATFORM") === "xcb") releaseFocus.running = true
    }

    function dismissIsland() {
        openTimer.stop(); edgeTimer.stop(); closeTimer.stop();
        expandedView.pinned = false;
        open = false; edgeRevealed = false;
    }

    Connections {
        target: Settings
        function onEdgeRevealChanged() { window.dismissIsland(); }
        function onCompactAlwaysVisibleChanged() { window.dismissIsland(); }
        function onPreserveAppFocusChanged() {
            window.keyboardInput=false;
            if (!window.focusable) releaseFocusTimer.restart();
        }
    }

    // Only this 144 x 2 px strip receives input at rest; the revealed notch
    // connects directly to the screen edge.
    Item {
        id: edgeTarget
        objectName: "islandEdgeTarget"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0; width: Math.min(144, window.width)
        height: window.edgeActivation ? 2 : 0
        enabled: window.edgeActivation
        HoverHandler {
            id: edgeHover
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop();
                    if (!window.edgeRevealed) edgeTimer.restart();
                } else {
                    edgeTimer.stop();
                    closeTimer.restart();
                }
            }
        }
        TapHandler { onTapped: { window.openIsland(""); window.focusForKeyboard(); } }
    }
    Timer {
        id: edgeTimer
        interval: 220
        onTriggered: if (edgeHover.hovered && Settings.edgeReveal) window.edgeRevealed = true
    }

    // A fullscreen window on this monitor hides the island; only notifications
    // bring it back, growing out of a dot and shrinking back into one.
    readonly property var hyprMonitor: null
    readonly property bool fullscreen: Settings.hideInFullscreen === true
        && !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)

    readonly property bool pinned:expandedView.pinned
    onPinnedChanged:if(!pinned&&!pointerInside&&!IslandState.heldOpen)closeTimer.restart()
    readonly property bool expanded: open
    readonly property bool liquidMotion: Settings.liquidMotion && Theme.motionFactor > 0
    readonly property int liquidOpenDuration: Math.round(425 * Theme.motionFactor)
    readonly property int liquidCloseDuration: Math.round(340 * Theme.motionFactor)

    // Give the main island a small vertical settle as the droplet detaches.
    readonly property var liquidOpenHeight: [
        0.15, 0.52, 0.35, 1.024, 0.53, 1.024,
        0.65, 1.024, 0.78, 0.994, 0.86, 0.994,
        0.92, 0.994, 0.96, 1, 1, 1
    ]

    function liquidCloseHeight(fromHeight, toHeight) {
        const lift = 1 + Math.min(0.015, 4 / Math.max(1, fromHeight - toHeight));
        return [
            0.15, 0.22, 0.42, lift, 0.62, lift,
            0.76, lift, 0.87, 1, 1, 1
        ];
    }
    readonly property string mode: {
        if (expanded)
            return "expanded";
        // The status island stays visible, including during transient activity.
        // Its idle row already carries playback/privacy/timer indicators.
        if (Settings.compactAlwaysVisible) return "idle";
        if (Settings.edgeReveal && !edgeRevealed) return "hidden";
        // In fullscreen only notifications come through.
        if (fullscreen)
            return Activities.find("notification") ? "notification" : "hidden";
        if (Activities.current)
            return modeFor(Activities.current.kind);
        return Settings.mediaAlwaysShown === true && Media.playing ? "media" : "idle";
    }

    // The notification banner takes the pointer: hovering it pauses it
    // instead of opening the island, so it can be clicked.
    readonly property bool bannerMode: mode === "notification"

    function modeFor(kind) {
        if (kind === "notification") return "notification";
        if (kind === "nowPlaying") return "media";
        if (kind === "claude") return "claude";
        return "alert";
    }



    Timer {
        id: openTimer
        interval: Settings.compactAlwaysVisible ? Theme.hoverOpenDelay : Settings.edgeReveal ? 180 : Theme.hoverOpenDelay
        onTriggered: if (hover.hovered && Settings.hoverToExpand && !window.bannerMode) window.openIsland("")
    }

    // When a view lets go, close if the pointer has already left. Opening on
    // request (keybind, script) stays open until the pointer passes over the
    // island and leaves, or a close request arrives.
    Connections {
        target: IslandState
        function onHeldOpenChanged() {
            if (!IslandState.heldOpen && !window.pointerInside)
                closeTimer.restart();
        }
        function onOpenRequested(tab) {
            window.openIsland(tab);
            window.focusForKeyboard();
        }
        function onCloseRequested() {
            window.dismissIsland();
        }
        function onToggleRequested() {
            if(window.open)window.dismissIsland();
            else {window.openIsland("");window.focusForKeyboard();}
        }
        function onKeyboardFocusRequested(enabled) { window.setKeyboardInput(enabled); }
        function onTextEntryRequested(target) {
            // Each monitor owns a window. Activate only the field's window.
            if (!expandedView.selectKeyboardTarget(target)) return;
            if (!window.keyboardPending && (!window.keyboardInput || !window.keyboardActive || window.keyboardFailed))
                window.setKeyboardInput(true);
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.hoverCloseDelay
        // A view typing into a field keeps the island open; see IslandState.
        onTriggered: if (!IslandState.heldOpen && !window.pinned && !window.pointerInside) {
            window.open = false;
            window.edgeRevealed = false;
        }
    }

    RectangularShadow {
        visible: !Settings.edgeReveal
        anchors.fill: pill
        radius: pill.radius
        blur: window.expanded ? 36 : 14
        offset.y: window.expanded ? 12 : 3
        color: Qt.rgba(0, 0, 0, window.expanded ? 0.55 : 0.35)
        opacity: pill.opacity
        scale: pill.scale
        transformOrigin: Item.Top

        Behavior on blur { NumberAnimation { duration: Theme.expandDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve } }
    }

    WaterDrop {
        id: waterDrop
        enabled: window.liquidMotion
        edgeY: pill.y + pill.height * pill.scale
    }

    // Draw the full silhouette once, outside the content's rectangular clip.
    NotchSurface {
        id: notchSurface
        objectName: "attachedNotchSurface"
        anchors.fill: pill
        visible: Settings.edgeReveal || window.liquidMotion
        attached: Settings.edgeReveal
        inset: pill.shoulder
        cornerRadius: pill.radius
        opacity: pill.opacity
        scale: pill.scale
        transformOrigin: Item.Top
        dip: window.shapeVisible ? waterDrop.extension : 0
        fill: Theme.island
        outline: "transparent"
    }

    Rectangle {
        id: pill
        objectName:"islandPill"

        anchors.top: parent.top
        anchors.topMargin: Theme.topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        transformOrigin: Item.Top

        // Geometry is deliberately outside State PropertyChanges: Qt delays
        // unhandled state actions until its content transition has completed.
        // Direct bindings let the one Behavior retarget without a second jump.
        readonly property real shoulder: Settings.edgeReveal ? 14 : 0
        width: (window.mode === "expanded" ? expandedView.targetWidth
            : window.mode === "hidden" ? Theme.dotSize
            : window.mode === "notification" ? Theme.notificationWidth
            : ["media", "alert", "claude"].includes(window.mode) ? Theme.activityWidth : Theme.idleWidth) + shoulder*2
        height: window.mode === "expanded" ? expandedView.targetHeight
            : window.mode === "hidden" ? Theme.dotSize
            : window.mode === "notification" ? Theme.notificationHeight : Theme.compactHeight
        radius: window.mode === "expanded" ? Theme.expandedRadius
            : window.mode === "hidden" ? Theme.dotSize / 2
            : window.mode === "notification" ? Theme.notificationRadius : Theme.compactRadius
        color: notchSurface.visible ? "transparent" : Theme.island
        border.width: 0
        clip: true

        Item {
            id: notchBody
            x: notchSurface.sideInset; y: 0
            width: pill.width-notchSurface.sideInset*2; height: pill.height
        }

        AmbientPattern {
            objectName: "islandAmbientPattern"
            anchors.fill: parent
            notched: notchSurface.visible
            inset: pill.shoulder
            motif: Settings.ambientStyle
            accent: Theme.accent
            followAccent: Theme.wallpaperColorsActive
            intensity: Math.max(0, Math.min(.8, Settings.ambientIntensity))
            speed: Settings.ambientSpeed
            cornerRadius: pill.radius
            attached: Settings.edgeReveal
            animate: Settings.motionStyle !== "reduced"
            active: window.shapeVisible && pill.opacity > .02 && window.visible
            frameInterval: Settings.ambientStyle === "aurora" ? 50 : window.expanded ? 50 : 85
        }

        // One animator owns each dimension during opening, closing and page
        // resizing. A State Transition snapshots its destination, so a page
        // loaded during opening used to finish at the old size, then resize a
        // second time. Behaviors retarget directly from the current geometry.
        Behavior on width {
            NumberAnimation {
                duration: window.expanded ? Theme.expandDuration : Theme.collapseDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.morphCurve
            }
        }
        Behavior on height {
            property bool wasExpanded: false
            onTargetValueChanged: {
                const opening = window.expanded;
                const settle = window.liquidMotion && opening !== wasExpanded && window.mode !== "hidden";
                wasExpanded = opening;
                heightAnimation.duration = settle
                    ? (opening ? window.liquidOpenDuration : window.liquidCloseDuration)
                    : (opening ? Theme.expandDuration : Theme.collapseDuration);
                heightAnimation.easing.bezierCurve = !settle ? Theme.morphCurve : opening
                    ? window.liquidOpenHeight : window.liquidCloseHeight(pill.height, targetValue);
            }
            NumberAnimation { id: heightAnimation; easing.type: Easing.BezierSpline }
        }
        Behavior on radius { NumberAnimation { duration:window.expanded?Theme.expandDuration:Theme.collapseDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.morphCurve } }

        // 1 while shown; 0 shrinks the dot to nothing as the island hides.
        property real reveal: 1
        // A quick squeeze when the collapsed pill is pressed.
        property real pressScale: tap.pressed && !window.expanded && Theme.motionFactor > 0 ? 0.95 : 1
        Behavior on pressScale {
            NumberAnimation { duration: Theme.pressDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }

        opacity: reveal
        scale: Settings.edgeReveal ? 1 : pressScale * (0.3 + 0.7 * reveal)

        state: window.mode
        states: [
            State {
                name: "hidden"
                PropertyChanges { target: pill; reveal: 0 }
                PropertyChanges { target: compact; opacity: 0; scale: 0.92; blur: Theme.hiddenBlur }
            },
            State { name: "idle" },
            State { name: "media" },
            State { name: "alert" },
            State { name: "claude" },

            State {
                name: "notification"
                PropertyChanges { target: compact; opacity: 0; scale: 0.92; blur: Theme.hiddenBlur }
                PropertyChanges { target: popup; opacity: 1; scale: 1; blur: 0 }
            },
            State {
                name: "expanded"
                PropertyChanges { target: compact; opacity: 0; scale: 1.08; blur: Theme.hiddenBlur }
                PropertyChanges { target: expandedView; opacity: 1; scale: 1; blur: 0 }
            }
        ]

        transitions: [
            // Geometry draws into a dot while content leaves; fade the dot last.
            Transition {
                to: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        targets: [compact, popup, expandedView]
                        properties: "opacity,scale,blur"
                        duration: Theme.fadeDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exitCurve
                    }
                    NumberAnimation {
                        target: pill
                        property: "reveal"
                        duration: Theme.pageDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exitCurve
                    }
                }
            },
            // Reveal the growing pill before fading its content back in.
            Transition {
                from: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        target: pill
                        property: "reveal"
                        duration: Theme.pageDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.springCurve
                    }
                    PauseAnimation { duration: Math.round(80*Theme.motionFactor) }
                    NumberAnimation {
                        targets: [compact, popup, expandedView]
                        properties: "opacity,scale,blur"
                        duration: Theme.pageDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.smoothCurve
                    }
                }
            },
            // Geometry stays with the Behaviors above; only content fades here.
            Transition {
                from: "idle,media,alert,notification,claude"
                to: "expanded"
                ParallelAnimation {
                    NumberAnimation {
                        targets: [compact, popup]
                        properties: "opacity,scale,blur"
                        duration: Theme.fadeDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exitCurve
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: Theme.contentDelay }
                        NumberAnimation {
                            target: expandedView
                            properties: "opacity,scale,blur"
                            duration: Theme.pageDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.smoothCurve
                        }
                    }
                }
            },
            // Close: content leaves quickly, then the pill settles back.
            Transition {
                from: "expanded"
                to: "idle,media,alert,notification,claude"
                ParallelAnimation {
                    NumberAnimation {
                        target: expandedView
                        properties: "opacity,scale,blur"
                        duration: Theme.contentExitDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.exitCurve
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: Math.round(60*Theme.motionFactor) }
                        NumberAnimation {
                            targets: [compact, popup]
                            properties: "opacity,scale,blur"
                            duration: Theme.fadeDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.smoothCurve
                        }
                    }
                }
            },
            // Compact content cross-fades independently of the shape morph.
            Transition {
                NumberAnimation {
                    targets: [compact, popup, expandedView]
                    properties: "opacity,scale,blur"
                    duration: Theme.pageDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.smoothCurve
                }
            }
        ]

        HoverHandler {
            id: hover
            enabled: Settings.compactAlwaysVisible || !Settings.edgeReveal || window.edgeRevealed
            onHoveredChanged: {
                // Over a notification banner the pointer pauses it instead of
                // opening the island, so the banner can be clicked.
                if (window.bannerMode) {
                    Activities.hold("notification", hovered);
                    if (hovered)
                        return;
                }
                if (hovered) {
                    closeTimer.stop();
                    if (Settings.edgeReveal) window.edgeRevealed = true;
                    if (Settings.hoverToExpand && !window.expanded)
                        openTimer.restart();
                } else {
                    openTimer.stop();
                    closeTimer.restart();
                }
            }
        }

        // Clicking opens the island (needed when hoverToExpand is off). It does
        // not pin it: leaving with the pointer still closes it.
        TapHandler {
            id: tap
            enabled: !window.expanded && (Settings.compactAlwaysVisible || !Settings.edgeReveal || window.edgeRevealed)
            onTapped: {
                window.openIsland("");
                window.focusForKeyboard();
            }
        }

        CompactView {
            id: compact
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: pill.shoulder
            anchors.rightMargin: pill.shoulder
            anchors.top: parent.top
            height: Theme.compactHeight
            transformOrigin: Item.Top
            mode: window.mode
            visible: opacity > 0
            enabled: !window.expanded
        }


        NotificationPopup {
            id: popup
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.notificationWidth
            height: Theme.notificationHeight
            transformOrigin: Item.Top
            opacity: 0
            scale: 0.92
            blur: Theme.hiddenBlur
            visible: opacity > 0
            enabled: window.mode === "notification"
            onOpenRequested: {
                Activities.dismiss("notification");
                window.openIsland("notifications");
            }
        }

        // Lay out at the requested page size while the pill morphs around it.
        ExpandedView {
            id: expandedView
            objectName:"expandedIslandView"
            presented: window.expanded
            keyboardInput: window.keyboardInput
            onCloseRequested: window.dismissIsland()
            anchors.top: parent.top
            anchors.topMargin: contentPadding
            anchors.horizontalCenter: parent.horizontalCenter
            availableWidth: Math.max(1,window.width-24-pill.shoulder*2)
            availableHeight: Math.max(1,(window.screen?window.screen.height:800)-Theme.topMargin-48)
            width: targetWidth - 2 * contentPadding
            height: targetHeight - 2 * contentPadding
            transformOrigin: Item.Top
            opacity: 0
            scale: 1
            blur: 0
            visible: opacity > 0
            enabled: window.expanded
        }
    }
}
