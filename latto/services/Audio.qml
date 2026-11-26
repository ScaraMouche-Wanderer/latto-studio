pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire

// Default output volume and mute state, and the default microphone's mute
// state, via PipeWire.
QtObject {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasMicrophone: !!(source && source.ready && source.audio)
    readonly property bool microphoneMuted: hasMicrophone ? source.audio.muted : false

    function setVolume(value) {
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicrophone() {
        setMicrophoneMuted(!microphoneMuted);
    }

    function setMicrophoneMuted(muted) {
        if (hasMicrophone)
            source.audio.muted = muted;
    }

    readonly property bool hasOutput: !!(sink && sink.audio)
    readonly property real microphoneVolume: hasMicrophone ? source.audio.volume : 0
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(node => node.audio && !node.isSink && !node.isStream)
    function deviceName(node) { return node ? node.nickname || node.description || node.name || "Audio device" : "No device"; }
    function selectOutput(node) { if (outputs.includes(node)) Pipewire.preferredDefaultAudioSink = node; }
    function selectInput(node) { if (inputs.includes(node)) Pipewire.preferredDefaultAudioSource = node; }
    function setMicrophoneVolume(value) { if (hasMicrophone) source.audio.volume = Math.max(0, Math.min(1, value)); }

    // App streams are tracked only while the mixer is open.
    property int streamWatchers: 0
    readonly property var streams: streamWatchers > 0
        ? Pipewire.nodes.values.filter(node => node.isStream && node.audio) : []
    function watchStreams() { streamWatchers++; }
    function unwatchStreams() { streamWatchers = Math.max(0, streamWatchers - 1); }
    function streamName(node) {
        const props = node ? node.properties : ({});
        return props["application.name"] || deviceName(node);
    }
    function setStreamVolume(node, value) {
        if (streams.includes(node) && node.ready && node.audio && Number.isFinite(value))
            node.audio.volume = Math.max(0, Math.min(1, value));
    }
    function toggleStreamMute(node) {
        if (streams.includes(node) && node.ready && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    // Binding the nodes is required before their audio properties are valid.
    property PwObjectTracker tracker: PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => !node.isStream || root.streamWatchers > 0)
    }
}
