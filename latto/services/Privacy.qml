pragma Singleton

import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

QtObject {
    id: root

    readonly property var mediaLinks: Settings.privacyIndicators
        ? Pipewire.links.values.filter(link => link.source && link.target
            && (isMicrophoneLink(link) || link.source.type === PwNodeType.VideoSource))
        : []
    readonly property var captureLinks: mediaLinks.filter(link => link.state === PwLinkState.Active)
    readonly property var microphoneLinks: captureLinks.filter(isMicrophoneLink)
    readonly property var cameraLinks: captureLinks.filter(link => {
        if (link.source.type !== PwNodeType.VideoSource) return false;
        const props = link.source.properties;
        return props["device.api"] === "v4l2" || props["device.api"] === "libcamera" || props["media.role"] === "Camera";
    })

    readonly property bool microphone: microphoneLinks.length > 0
    readonly property bool microphoneMuted: microphone && microphoneLinks.every(link =>
        link.source.audio?.muted === true || link.target.audio?.muted === true)
    readonly property bool camera: cameraLinks.length > 0 || directCameraApps.length > 0
    readonly property var microphoneApps: appNames(microphoneLinks)
    readonly property var cameraApps: [...new Set(appNames(cameraLinks).concat(directCameraApps))].sort()
    readonly property string microphoneStatus: !microphone ? "No app using the microphone"
        : (microphoneMuted ? "Mic in use · muted" : "Mic in use") + appSuffix(microphoneApps)
    readonly property string cameraStatus: !camera ? "No app using the camera"
        : (cameraLinks.length > 0 ? "Camera in use" : "Camera device open") + appSuffix(cameraApps)
    readonly property bool recording: Settings.privacyIndicators && recorderSeen
    readonly property bool active: microphone || camera || recording

    property var directCameraApps: []
    property bool recorderSeen: false

    function isMicrophoneLink(link) {
        return (link.source.type === PwNodeType.AudioSource || link.source.type === PwNodeType.AudioDuplex)
            && link.target.type === PwNodeType.AudioInStream && !link.source.name.endsWith(".monitor");
    }

    function appNames(links) {
        return [...new Set(links.map(link => {
            const props = link.target.properties;
            return props["application.name"] || props["application.process.binary"] || "";
        }).filter(name => name !== ""))].sort();
    }

    function appSuffix(names) {
        return names.length > 0 ? " · " + names.join(", ") : "";
    }

    // Follow capture state and app names without polling the PipeWire server.
    property PwObjectTracker tracker: PwObjectTracker {
        objects: {
            const tracked = new Set();
            for (const link of root.mediaLinks) {
                tracked.add(link);
                tracked.add(link.source);
                tracked.add(link.target);
            }
            return [...tracked];
        }
    }

    // Native V4L2 clients can open a camera outside PipeWire. Check their
    // handles without opening the camera or capturing a frame ourselves.
    readonly property string script: [
        "if ps -eo comm= | grep -Eq '^(wf-recorder|wl-screenrec|gpu-screen-reco|obs)$'; then echo 1; else echo 0; fi",
        "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video[0-9]*' -printf '%h\\n' 2>/dev/null | sort -u | while IFS= read -r fd; do",
        "  IFS= read -r name 2>/dev/null < \"${fd%/fd}/comm\" || continue",
        "  case \"$name\" in pipewire|wireplumber) ;; *) printf '%s\\n' \"$name\" ;; esac",
        "done"
    ].join("\n")

    property Process probe: Process {
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!Settings.privacyIndicators) return;
                const lines = this.text.trim().split("\n");
                root.recorderSeen = lines[0] === "1";
                root.directCameraApps = [...new Set(lines.slice(1))].sort();
            }
        }
    }

    property Timer timer: Timer {
        interval: 2500
        running: Settings.privacyIndicators
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.probe.running) root.probe.running = true
    }

    property Connections preferenceWatch: Connections {
        target: Settings
        function onPrivacyIndicatorsChanged() {
            if (Settings.privacyIndicators) return;
            root.directCameraApps = [];
            root.recorderSeen = false;
        }
    }
}
