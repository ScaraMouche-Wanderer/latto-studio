pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User configuration from ~/.config/latto/config.json. Any key that is missing
// keeps its default, so the file can be partial. Changes are picked up live.
FileView {
    id: file

    path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/latto/config.json"
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
        id: adapter

        // Empty means the system's default Qt font.
        property string fontFamily: ""
        property string accentColor: "#0a84ff"
        property string backgroundColor: "#000000"
        property string surfaceColor: "#141416"
        property string textColor: "#f5f5f7"
        property bool followWallpaper: false
        property real backgroundOpacity: 1.0
        property real borderOpacity: 0.08
        property int idleWidth: 260
        property int topOffset: 44
        property string cornerStyle: "pill"
        property string expandedLayout: "tabs"
        property string motionStyle: "smooth"
        property bool liquidMotion: false
        property string ambientStyle: "off"
        property real ambientIntensity: 0.55
        property real ambientSpeed: 1.0
        property string clockFormat: "24h"
        property bool showSeconds: false
        property string dateFormat: "ddd d"
        property bool batteryPercentage: true
        property var compactItems: ["date", "clock", "battery", "activity"]

        // Optional top-centre edge activation; legacy layouts stay unchanged.
        property bool edgeReveal: false
        property bool compactAlwaysVisible: false
        property int hoverExpandDelay: 600
        property int hoverCloseDelay: 420
        property bool hoverToExpand: true
        // Pointer controls can leave keyboard focus with the current app.
        // Typing in Latto is then a separate, explicit choice per opening.
        property bool preserveAppFocus: false
        // Hide the island over fullscreen windows; notifications still show.
        property bool hideInFullscreen: true
        // The song shows for nowPlayingDuration ms when playback starts or the
        // track changes. Set mediaAlwaysShown to keep it up while playing.
        property bool mediaAlwaysShown: false
        property int nowPlayingDuration: 4000
        // Claude Code live activity (fed by the hooks install.sh sets up).
        property bool claudeActivity: false
        // Pomodoro lengths in minutes; a long break follows every
        // pomodoroRounds focus sessions. Focus sessions turn on Do Not
        // Disturb when pomodoroDnd is set.
        property int pomodoroFocusMinutes: 25
        property int pomodoroBreakMinutes: 5
        property int pomodoroLongBreakMinutes: 15
        property int pomodoroRounds: 4
        property bool pomodoroDnd: true
        // Night light colour temperature in kelvin.
        property int nightLightTemperature: 4500
        // Expanded-view tabs, in display order. Valid names: media,
        // notifications, stats, timers, clipboard, calendar, overview, codex.
        property var tabs: ["media", "notifications", "stats", "timers", "clipboard", "calendar", "overview", "codex"]
        // Run latto's own notification daemon. Turn off to keep another one.
        property bool notificationsEnabled: false
        property int notificationDuration: 5000
        // Critical notifications still pop up during Do Not Disturb.
        property bool dndAllowCritical: true
        property int lowBatteryPercent: 15
        property int hudDuration: 1500
        property int statsInterval: 2000
        property bool showLyrics: false
        property bool clipboardEnabled: false
        property bool codexTypingEnabled: true
        property int clipboardHistoryLimit: 100
        property bool calendarEnabled: false
        property real weatherLatitude: 0
        property real weatherLongitude: 0
        property bool privacyIndicators: true
        property bool capsLockIndicator: true
        property bool bluetoothAlerts: true
        property bool timerSound: true
        property string timerSoundFile: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    }

    readonly property alias fontFamily: adapter.fontFamily
    readonly property alias accentColor: adapter.accentColor
    readonly property alias backgroundColor: adapter.backgroundColor
    readonly property alias surfaceColor: adapter.surfaceColor
    readonly property alias textColor: adapter.textColor
    readonly property alias followWallpaper: adapter.followWallpaper
    readonly property alias backgroundOpacity: adapter.backgroundOpacity
    readonly property alias borderOpacity: adapter.borderOpacity
    readonly property alias idleWidth: adapter.idleWidth
    readonly property alias topOffset: adapter.topOffset
    readonly property alias cornerStyle: adapter.cornerStyle
    readonly property alias expandedLayout: adapter.expandedLayout
    readonly property alias motionStyle: adapter.motionStyle
    readonly property alias liquidMotion: adapter.liquidMotion
    readonly property alias ambientStyle: adapter.ambientStyle
    readonly property alias ambientIntensity: adapter.ambientIntensity
    readonly property alias ambientSpeed: adapter.ambientSpeed
    readonly property alias clockFormat: adapter.clockFormat
    readonly property alias showSeconds: adapter.showSeconds
    readonly property alias dateFormat: adapter.dateFormat
    readonly property alias batteryPercentage: adapter.batteryPercentage
    readonly property alias compactItems: adapter.compactItems

    readonly property alias compactAlwaysVisible: adapter.compactAlwaysVisible
    readonly property alias hoverExpandDelay: adapter.hoverExpandDelay
    readonly property alias hoverCloseDelay: adapter.hoverCloseDelay
    readonly property alias edgeReveal: adapter.edgeReveal
    readonly property alias hoverToExpand: adapter.hoverToExpand
    readonly property alias preserveAppFocus: adapter.preserveAppFocus
    readonly property alias hideInFullscreen: adapter.hideInFullscreen
    readonly property alias mediaAlwaysShown: adapter.mediaAlwaysShown
    readonly property alias nowPlayingDuration: adapter.nowPlayingDuration
    readonly property alias claudeActivity: adapter.claudeActivity
    readonly property alias pomodoroFocusMinutes: adapter.pomodoroFocusMinutes
    readonly property alias pomodoroBreakMinutes: adapter.pomodoroBreakMinutes
    readonly property alias pomodoroLongBreakMinutes: adapter.pomodoroLongBreakMinutes
    readonly property alias pomodoroRounds: adapter.pomodoroRounds
    readonly property alias pomodoroDnd: adapter.pomodoroDnd
    readonly property alias nightLightTemperature: adapter.nightLightTemperature
    readonly property alias tabs: adapter.tabs
    readonly property alias notificationsEnabled: adapter.notificationsEnabled
    readonly property alias notificationDuration: adapter.notificationDuration
    readonly property alias dndAllowCritical: adapter.dndAllowCritical
    readonly property alias lowBatteryPercent: adapter.lowBatteryPercent
    readonly property alias hudDuration: adapter.hudDuration
    readonly property alias statsInterval: adapter.statsInterval
    readonly property alias showLyrics: adapter.showLyrics
    readonly property alias clipboardHistoryLimit: adapter.clipboardHistoryLimit
    readonly property alias clipboardEnabled: adapter.clipboardEnabled
    readonly property alias codexTypingEnabled: adapter.codexTypingEnabled
    readonly property alias calendarEnabled: adapter.calendarEnabled
    readonly property alias weatherLatitude: adapter.weatherLatitude
    readonly property alias weatherLongitude: adapter.weatherLongitude
    readonly property alias privacyIndicators: adapter.privacyIndicators
    readonly property alias capsLockIndicator: adapter.capsLockIndicator
    readonly property alias bluetoothAlerts: adapter.bluetoothAlerts
    readonly property alias timerSound: adapter.timerSound
    readonly property alias timerSoundFile: adapter.timerSoundFile
}
