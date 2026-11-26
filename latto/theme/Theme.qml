pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Visual constants: font, palette, geometry and motion.
QtObject {
    // The `fontFamily` config key if set, otherwise the system's default Qt
    // font (chosen by qt6ct, KDE or the platform theme).
    readonly property string fontFamily: Settings.fontFamily !== "" ? Settings.fontFamily : Qt.application.font.family

    readonly property int fontCaption: 10
    readonly property int fontSmall: 11
    readonly property int fontBody: 13
    readonly property int fontTitle: 16
    readonly property int fontDisplay: 34

    // Palette
    readonly property FileView wallpaperPalette: FileView {
        path: Settings.followWallpaper ? Quickshell.env("HOME") + "/.local/share/backgrounds/local-rotation/palette.json" : ""
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: wallpaper
            property string backgroundColor: ""
            property string surfaceColor: ""
            property string accentColor: ""
        }
    }
    readonly property bool wallpaperColorsActive: Settings.followWallpaper
        && [wallpaper.backgroundColor, wallpaper.surfaceColor, wallpaper.accentColor].every(c => /^#[0-9a-f]{6}$/i.test(c))
    readonly property color baseIsland: wallpaperColorsActive ? wallpaper.backgroundColor : Settings.backgroundColor
    readonly property color island: Qt.rgba(baseIsland.r, baseIsland.g, baseIsland.b, Math.max(0.35, Math.min(1, Settings.backgroundOpacity)))
    readonly property color surface: wallpaperColorsActive ? wallpaper.surfaceColor : Settings.surfaceColor
    readonly property color surfaceRaised: Qt.lighter(surface, 1.25)
    readonly property color border: Qt.rgba(text.r, text.g, text.b, Math.max(0, Math.min(0.4, Settings.borderOpacity)))
    readonly property color text: wallpaperColorsActive ? "#f5f5f7" : Settings.textColor
    readonly property color textSecondary: Qt.rgba(text.r, text.g, text.b, 0.76)
    readonly property color textTertiary: Qt.rgba(text.r, text.g, text.b, 0.68)
    readonly property color accent: wallpaperColorsActive ? wallpaper.accentColor : Settings.accentColor
    readonly property bool lightBackground: baseIsland.hslLightness > 0.65
    readonly property color red: lightBackground ? "#ab261e" : "#ff453a"
    readonly property color orange: "#ff9f0a"
    readonly property color yellow: "#ffd60a"
    readonly property color green: lightBackground ? "#186138" : "#30d158"
    readonly property color cyan: "#64d2ff"
    readonly property color blue: "#0a84ff"
    readonly property color indigo: "#5e5ce6"
    // Claude's coral, for the Claude Code live activity.
    readonly property color claude: "#d97757"

    // Island geometry
    readonly property int topMargin: Settings.edgeReveal ? 0 : Math.max(32, Math.min(160, Settings.topOffset))
    readonly property int compactHeight: 36
    readonly property int idleWidth: {
        const items = Settings.compactItems;
        let minimum = items.includes("cpu") && items.includes("memory") ? 320 : items.includes("cpu") || items.includes("memory") ? 280 : 180;
        if (items.includes("date") && Settings.dateFormat === "ddd, MMM d") minimum += 30;
        if (items.includes("clock")) minimum += (Settings.clockFormat === "12h" ? 20 : 0) + (Settings.showSeconds ? 18 : 0);
        return Math.max(minimum, Math.min(480, Settings.idleWidth));
    }
    readonly property int compactRadius: Settings.cornerStyle === "rounded" ? 11 : compactHeight / 2
    readonly property real motionFactor: Settings.motionStyle === "reduced" ? 0 : Settings.motionStyle === "snappy" ? 0.65 : 1.0
    readonly property int activityWidth: 340
    readonly property int expandedWidth: 600
    readonly property int expandedHeight: 276
    readonly property int expandedRadius: 34
    readonly property int notificationWidth: 420
    readonly property int notificationHeight: 76
    readonly property int notificationRadius: 28
    // What the island shrinks to before disappearing in fullscreen.
    readonly property int dotSize: 12
    readonly property int padding: 18
    readonly property int cardRadius: 18

    // Motion. Curves are cubic beziers in the [x1, y1, x2, y2, 1, 1] form that
    // Easing.BezierSpline expects.
    readonly property var springCurve: [0.16, 1, 0.3, 1, 1, 1]
    readonly property var settleCurve: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var smoothCurve: [0.2, 0.8, 0.2, 1, 1, 1]
    readonly property var morphCurve: [0.22, 0.8, 0.2, 1, 1, 1]
    readonly property var exitCurve: [0.4, 0, 0.7, 0.2, 1, 1]

    readonly property int expandDuration: Math.round(360 * motionFactor)
    readonly property int collapseDuration: Math.round(280 * motionFactor)
    readonly property int morphDuration: Math.round(300 * motionFactor)
    readonly property int fadeDuration: Math.round(140 * motionFactor)

    readonly property int pressDuration: Math.round(110 * motionFactor)
    readonly property int controlDuration: Math.round(180 * motionFactor)
    readonly property int pageDuration: Math.round(230 * motionFactor)
    readonly property int contentDelay: Math.round(35 * motionFactor)
    readonly property int contentEnterDuration: Math.round(220 * motionFactor)
    readonly property int contentExitDuration: Math.round(110 * motionFactor)
    readonly property int feedbackDuration: Math.round(300 * motionFactor)
    readonly property real pageTravel: motionFactor === 0 ? 0 : 14

    // Blur transitions: hidden content sits blurred and sharpens as it
    // appears. Swaps between views (blur-replace) use a lighter blur.
    readonly property real hiddenBlur: motionFactor===0?0:1.0
    readonly property real swapBlur: motionFactor===0?0:0.55
    readonly property int swapDuration: Math.round(180 * motionFactor)

    // Hover debounce: brushing past does not open, leaving always closes.
    readonly property int hoverOpenDelay: Settings.compactAlwaysVisible ? Math.max(140, Math.min(1000, Settings.hoverExpandDelay)) : 70
    readonly property int hoverCloseDelay: Math.max(180, Math.min(1000, Settings.hoverCloseDelay))
}
