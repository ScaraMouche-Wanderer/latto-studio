pragma Singleton

import QtQuick
import Quickshell.Services.Mpris

// The most relevant MPRIS player (a playing one first, otherwise any) and its controls.
QtObject {
    id: root

    readonly property var players: Mpris.players.values
    property string selectedPlayerName: ""
    readonly property bool automatic: selectedPlayerName === ""
    function selectPlayer(candidate) {
        if (players.includes(candidate)) selectedPlayerName = candidate.dbusName;
    }
    function useAutomatic() { selectedPlayerName = ""; }
    onPlayersChanged: {
        if (selectedPlayerName && !players.some(candidate => candidate.dbusName === selectedPlayerName))
            selectedPlayerName = "";
    }
    readonly property var player: {
        if (selectedPlayerName) {
            const selected = players.find(candidate => candidate.dbusName === selectedPlayerName);
            if (selected) return selected;
        }
        // The island's own active music survives a UI/config reload. An
        // explicit player choice above still takes precedence.
        const native = players.find(candidate => candidate.dbusName === "org.mpris.MediaPlayer2.Latto" && candidate.isPlaying);
        if (native) return native;
        let fallback = null;
        for (const candidate of players) {
            if (candidate.isPlaying)
                return candidate;
            if (!fallback)
                fallback = candidate;
        }
        return fallback;
    }

    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title: player ? (player.trackTitle || "Unknown title") : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string album: player ? player.trackAlbum : ""
    // Keep artwork local: do not fetch HTTP URLs containing listening metadata.
    readonly property string art: {
        const url = player ? String(player.trackArtUrl || "") : "";
        return url.startsWith("file:") || url.startsWith("data:") || url.startsWith("image:") ? url : "";
    }
    readonly property string source: player ? player.identity : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property bool shuffle: player ? player.shuffle : false
    readonly property bool shuffleSupported: player ? player.shuffleSupported : false

    // Seconds. MPRIS does not push position updates, so refreshPosition() polls.
    property real position: 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    onTitleChanged: refreshPosition()
    onPlayerChanged: { position = 0; refreshPosition(); }

    function refreshPosition() {
        if (!player)
            return;
        player.positionChanged();
        position = player.position;
    }

    property Timer positionTimer: Timer {
        interval: 500
        repeat: true
        running: root.playing
        triggeredOnStart: true
        onTriggered: root.refreshPosition()
    }

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player && player.canGoNext)
            player.next();
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }

    // fraction is 0..1 along the track.
    function seek(fraction) {
        if (player && player.canSeek && length > 0) {
            player.position = Math.max(0, Math.min(1, fraction)) * length;
            refreshPosition();
        }
    }

    function toggleShuffle() {
        if (player && player.shuffleSupported)
            player.shuffle = !player.shuffle;
    }
}
