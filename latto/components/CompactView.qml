import QtQuick
import Quickshell
import "../services"
import "../theme"

// Content of the collapsed island. `mode` picks one layout, and layouts
// cross-fade with a small scale so the change reads as a morph:
//   idle  - date and status indicators on the left, clock on the right
//   media - album art, title and an equaliser
//   alert - the highest-priority entry from Activities
Item {
    id: root

    property string mode: "idle"
    readonly property var alert: Activities.current
    // Keep the outgoing compact layer intact while handing off to a
    // notification banner or expanded view, avoiding nested double-fades.
    property string compactMode: ["idle", "media", "alert", "claude"].includes(mode) ? mode : "idle"
    onModeChanged: {
        if (["idle", "media", "alert", "claude"].includes(mode))
            compactMode = mode;
    }

    // Animated by IslandWindow when the row hands over to the expanded view
    // or a notification banner. Retain the property for the existing state
    // transition API, keeping rendering directly on the main scene graph.
    property real blur: 0

    // Icon and tint for each alert kind.
    readonly property var alertStyles: ({
        volume: { icon: "volume", color: Theme.text },
        brightness: { icon: "brightness", color: Theme.yellow },
        charging: { icon: "bolt", color: Theme.green },
        lowBattery: { icon: "batteryAlert", color: Theme.red },
        bluetooth: { icon: "bluetooth", color: Theme.blue },
        capsLock: { icon: "capsLock", color: Theme.text },
        timerDone: { icon: "timer", color: Theme.orange },
        dnd: { icon: "moon", color: Theme.indigo }
    })
    // Microphone and camera alerts change look with on/off (data.off).
    readonly property var alertStyle: {
        if (!alert)
            return { icon: "", color: Theme.text };
        const off = alert.data.off === true;
        switch (alert.kind) {
        case "microphone":
            return off ? { icon: "micOff", color: Theme.red } : { icon: "mic", color: Theme.green };
        case "microphoneUse":
            return { icon: "mic", color: off ? Theme.textSecondary : Theme.orange };
        case "camera":
            return off ? { icon: "cameraOff", color: Theme.textSecondary } : { icon: "camera", color: Theme.green };
        case "wifi":
            return off ? { icon: "wifiOff", color: Theme.textSecondary } : { icon: "wifi", color: Theme.blue };
        case "bluetoothPower":
            return { icon: "bluetooth", color: off ? Theme.textSecondary : Theme.blue };
        case "nightLight":
            return { icon: "nightLight", color: off ? Theme.textSecondary : Theme.orange };
        case "pomodoro":
            return { icon: "focus", color: alert.data.phase === "focus" ? Theme.red : Theme.green };
        }
        return alertStyles[alert.kind] || { icon: "", color: Theme.text };
    }
    readonly property bool alertHasValue: alert ? alert.data.value >= 0 : false
    readonly property real alertValue: alertHasValue ? alert.data.value : 0

    readonly property bool microphoneShown: Settings.privacyIndicators && Privacy.microphone
    readonly property bool recordingShown: Settings.privacyIndicators && Privacy.recording
    readonly property bool cameraShown: Settings.privacyIndicators && Privacy.camera
    // Red while a Pomodoro focus runs, green during its breaks.
    readonly property color timerColor: !Timers.pomodoro ? Theme.orange
        : Timers.phase === "focus" ? Theme.red
        : Theme.green
    readonly property bool timerDone: Activities.find("timerDone") !== null
    readonly property bool hasIndicators: Media.playing || microphoneShown || cameraShown || recordingShown
        || Caffeine.active || Timers.timerRunning || timerDone || Downloads.count > 0 || Notifications.doNotDisturb

    // Shared scene-graph crossfade for each layout: the leaving layout fades
    // and shrinks while the arriving one scales in, without FBO layer switches.
    component Layer: Item {
        id: layout

        property bool shown: false
        property real blur: shown ? 0 : Theme.swapBlur

        anchors.fill: parent
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.9
        visible: opacity > 0

        Behavior on opacity {
            enabled: root.visible
            NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.smoothCurve }
        }
        Behavior on scale {
            enabled: root.visible
            NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }
    }

    SystemClock {
        id: clock
        precision: Settings.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Layer {
        shown: root.compactMode === "idle"

        Row {
            id: idleStatus
            objectName: "idleStatus"
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Settings.compactItems.includes("date")
                text: Qt.formatDateTime(clock.date, Settings.dateFormat)
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
            }
            // Music playing; appears beside the date. The note sways to a beat
            // and a small equaliser bounces beside it.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.playing
                spacing: 5

                Icon {
                    id: musicNote
                    anchors.verticalCenter: parent.verticalCenter
                    name: "music"
                    size: 14
                    color: Theme.accent
                    transformOrigin: Item.Bottom


                }
                Visualizer {
                    anchors.verticalCenter: parent.verticalCenter
                    bars: 3
                    height: 11
                    active: Media.playing
                }
            }
            // Do Not Disturb, with how many notifications are waiting.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.doNotDisturb
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "moon"
                    size: 13
                    color: Theme.indigo
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifications.count > 0
                    text: Notifications.count
                    color: Theme.indigo
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.microphoneShown
                name: "mic"
                size: 14
                color: Theme.orange
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.cameraShown
                name: "camera"
                size: 14
                color: Theme.green
            }
            Rectangle {
                id: recordingDot
                anchors.verticalCenter: parent.verticalCenter
                visible: root.recordingShown
                width: 8
                height: 8
                radius: 4
                color: Theme.red

                SequentialAnimation on opacity {
                    running: recordingDot.visible&&Theme.motionFactor>0
                    onRunningChanged:if(!running)recordingDot.opacity=1
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Caffeine.active
                name: "coffee"
                size: 14
                color: Theme.yellow
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Timers.timerRunning || root.timerDone
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.timerDone ? "check" : Timers.pomodoro ? "focus" : "timer"
                    size: 13
                    color: root.timerColor
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.timerDone ? "Done" : Timers.countdownText
                    color: root.timerColor
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Downloads.count > 0
                spacing: 3

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "download"
                    size: 13
                    color: Theme.cyan
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Downloads.count
                    color: Theme.cyan
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.DemiBold
                }
            }
        }

        // Sampled metrics, not decorative activity: updated by the existing stats service.
        // Busy privacy/timer rows take priority; optional metrics yield their space.
        Item {
            id: metricsSpace
            objectName: "metricsSpace"
            anchors.left: idleStatus.right
            anchors.leftMargin: 6
            anchors.right: idleClock.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            clip: true

            Row {
                id: idleMetrics
                objectName: "idleMetrics"
                anchors.centerIn: parent
                spacing: 5
                readonly property bool batteryRequested: Settings.compactItems.includes("battery") && Battery.available
                readonly property real batteryNeeded: 20 + (Battery.charging ? 14 : 0) + (Settings.batteryPercentage ? 3 + batteryText.implicitWidth : 0)
                readonly property real baseNeeded: (batteryRequested ? batteryNeeded : 0) + (Settings.compactItems.includes("activity") ? 5 : 0) + (batteryRequested && Settings.compactItems.includes("activity") ? 5 : 0)
                readonly property real fullNeeded: {
                    const widths = [];
                    if (Settings.compactItems.includes("cpu")) widths.push(cpuText.implicitWidth);
                    if (Settings.compactItems.includes("memory")) widths.push(memoryText.implicitWidth);
                    if (Settings.compactItems.includes("activity")) widths.push(5);
                    if (batteryRequested) widths.push(batteryNeeded);
                    return widths.reduce((sum, value) => sum + value, 0) + 5 * Math.max(0, widths.length - 1);
                }
                readonly property bool statsFit: fullNeeded <= Math.max(0, metricsSpace.width)

                Label {
                    id: cpuText
                    objectName: "idleCpu"
                    visible: Settings.compactItems.includes("cpu") && idleMetrics.statsFit
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU " + Math.round(SystemStats.cpu) + "%"
                    color: Theme.accent
                    font.pixelSize: Theme.fontSmall
                }
                Label {
                    id: memoryText
                    objectName: "idleMemory"
                    visible: Settings.compactItems.includes("memory") && idleMetrics.statsFit
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RAM " + SystemStats.memoryUsedGiB.toFixed(1) + "G"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                }
                Rectangle {
                    objectName: "idleActivity"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Settings.compactItems.includes("activity") && idleMetrics.baseNeeded <= metricsSpace.width
                    width: 5; height: 5; radius: 2.5
                    color: SystemStats.cpu > 85 ? Theme.orange : Theme.accent
                    opacity: 0.7
                }
                Row {
                    objectName: "idleBattery"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    visible: idleMetrics.batteryRequested && idleMetrics.batteryNeeded <= metricsSpace.width
                    BatteryGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        percent: Battery.percent
                        color: Battery.percent <= Settings.lowBatteryPercent ? Theme.red : Battery.charging ? Theme.green : Theme.textSecondary
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Battery.charging
                        name: "bolt"
                        size: 11
                        color: Theme.green
                    }
                    Label {
                        id: batteryText
                        visible: Settings.batteryPercentage
                        text: Battery.percent + "%"
                        color: Battery.percent <= Settings.lowBatteryPercent ? Theme.red : Theme.textSecondary
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                    }
                }
            }

        }

        Label {
            id: idleClock
            objectName: "idleClock"
            visible: Settings.compactItems.includes("clock")
            width: visible ? implicitWidth : 0
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, Settings.clockFormat === "12h" ? (Settings.showSeconds ? "h:mm:ss AP" : "h:mm AP") : (Settings.showSeconds ? "HH:mm:ss" : "HH:mm"))
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
        }
    }

    Layer {
        shown: root.compactMode === "media"

        RoundedImage {
            id: smallArt
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 8
            source: Media.art
        }
        Label {
            anchors.left: smallArt.right
            anchors.leftMargin: 10
            anchors.right: privacyDots.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Media.title
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        // Microphone (orange) and camera (green) in use, as small dots.
        Row {
            id: privacyDots
            anchors.right: visualizer.left
            anchors.rightMargin: visible ? 10 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.microphoneShown || root.cameraShown

            Rectangle {
                visible: root.microphoneShown
                width: 7
                height: 7
                radius: 3.5
                color: Theme.orange
            }
            Rectangle {
                visible: root.cameraShown
                width: 7
                height: 7
                radius: 3.5
                color: Theme.green
            }
        }
        Visualizer {
            id: visualizer
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            active: Media.playing
        }
    }

    // Claude Code live activity: what the session is doing, and for how long.
    Layer {
        id: claudeLayer

        shown: root.compactMode === "claude"

        readonly property var session: Claude.current
        readonly property bool waiting: session ? session.state === "input" : false
        property real now: Date.now()

        Timer {
            interval: 1000
            repeat: true
            running: claudeLayer.shown
            triggeredOnStart: true
            onTriggered: claudeLayer.now = Date.now()
        }

        Item {
            id: claudeMark
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16

            Spinner {
                anchors.fill: parent
                visible: !claudeLayer.waiting
                running: claudeLayer.shown
                size: 16
                color: Theme.claude
            }
            Rectangle {
                id: waitingDot
                anchors.centerIn: parent
                visible: claudeLayer.waiting
                width: 10
                height: 10
                radius: 5
                color: Theme.claude

                SequentialAnimation on scale {
                    running: waitingDot.visible&&Theme.motionFactor>0
                    onRunningChanged:if(!running)waitingDot.scale=1
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.35; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }
        }

        Label {
            id: claudeProject
            anchors.left: claudeMark.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.32)
            text: claudeLayer.session
                ? (claudeLayer.session.project || "Claude") + (Claude.count > 1 ? " +" + (Claude.count - 1) : "")
                : ""
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Label {
            anchors.left: claudeProject.right
            anchors.leftMargin: 7
            anchors.right: claudeStatus.left
            anchors.rightMargin: 10
            // Smaller text than the project: share its baseline, not its centre.
            anchors.baseline: claudeProject.baseline
            text: claudeLayer.session ? claudeLayer.session.detail : ""
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
        Label {
            id: claudeStatus
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.baseline: claudeProject.baseline
            // Matches Claude Code's own line: "2m 10s · ↓ 9.3k".
            text: claudeLayer.waiting ? "Needs input"
                : claudeLayer.session
                    ? [Claude.elapsedText(claudeLayer.now - claudeLayer.session.startedAt),
                       Claude.tokensText(claudeLayer.session.tokens)].filter(part => part !== "").join("  \u00B7  ")
                : ""
            color: claudeLayer.waiting ? Theme.claude : Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    Layer {
        shown: root.compactMode === "alert"

        Icon {
            id: alertIcon
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            name: root.alert && root.alert.kind === "volume" && root.alertValue === 0 ? "volumeOff" : root.alertStyle.icon
            size: 16
            color: root.alertStyle.color
        }
        Label {
            id: alertLabel
            anchors.left: alertIcon.right
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            // An explicit width, not a right anchor toggled on and off: once an
            // anchor has stretched an item, removing it leaves the stretched
            // width behind, which squeezed the bar away after a text-only alert.
            width: root.alertHasValue
                ? Math.min(implicitWidth, parent.width * 0.4)
                : parent.width - x - 15
            text: root.alert ? root.alert.data.label : ""
            font.pixelSize: Theme.fontSmall + 1
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        IslandBar {
            visible: root.alertHasValue
            anchors.left: alertLabel.right
            anchors.leftMargin: 12
            anchors.right: alertPercent.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            value: root.alertValue
            fillColor: root.alertStyle.color
        }
        Label {
            id: alertPercent
            visible: root.alertHasValue
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.baseline: alertLabel.baseline
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.alertValue * 100)
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
        }

        // The icon pops each time a new alert replaces the previous one.
        SequentialAnimation {
            id: alertPop
            NumberAnimation { target: alertIcon; property: "scale"; to: 0.6; duration: 0 }
            NumberAnimation { target: alertIcon; property: "scale"; to: 1; duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
        }
    }

    onAlertChanged: if (alert) alertPop.restart()
}
