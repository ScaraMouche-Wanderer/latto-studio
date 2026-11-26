import QtQuick
import "../../services"
import "../../theme"
import ".."

// Quick toggles along the top, then at-a-glance tiles: battery (with
// keep-awake), network, Bluetooth, weather, and adjustable volume and
// brightness. The Wi-Fi toggle and the network tile open a list of nearby
// networks to connect to.
Item {
    id: root

    property var cameraSettings: DesktopSettings
    Component.onCompleted: {SystemControls.watch();cameraSettings.watch();}
    Component.onDestruction: {
        SystemControls.unwatch();
        cameraSettings.unwatch();
        if (keyboardDragging) { keyboardDragging = false; IslandState.release(); }
    }
    property var keyboardBackend: SystemControls
    property int requestedKeyboardLevel: -1
    property int sentKeyboardLevel: -1
    property bool keyboardDragging: false
    function clearKeyboardRequest() {
        requestedKeyboardLevel = -1;
        sentKeyboardLevel = -1;
        keyboardUpdate.stop();
        keyboardAck.stop();
        keyboardReconcile.stop();
    }
    function setKeyboardLevel(level) {
        const keyboard = keyboardBackend.data.keyboard;
        if (!keyboard.available || !Number.isFinite(level)) return;
        const next = Math.max(0, Math.min(keyboard.maximum, Math.round(level)));
        if (requestedKeyboardLevel === next) return;
        requestedKeyboardLevel = next;
        if (!keyboardDragging) keyboardUpdate.restart();
    }
    function beginKeyboardDrag() {
        keyboardUpdate.stop();
        keyboardAck.stop();
        keyboardReconcile.stop();
        if (!keyboardDragging) { keyboardDragging = true; IslandState.holdOpen(); }
    }
    function endKeyboardDrag() {
        if (keyboardDragging) { keyboardDragging = false; IslandState.release(); }
        reconcileKeyboard();
        if (requestedKeyboardLevel >= 0) {
            if (sentKeyboardLevel === requestedKeyboardLevel) keyboardAck.restart();
            else keyboardUpdate.restart();
        }
    }
    function reconcileKeyboard() {
        if (!keyboardDragging && !keyboardBackend.busy && requestedKeyboardLevel >= 0
                && sentKeyboardLevel === requestedKeyboardLevel
                && keyboardBackend.data.keyboard.current === requestedKeyboardLevel)
            clearKeyboardRequest();
    }
    Connections {
        target: root.keyboardBackend
        function onDataChanged() { root.reconcileKeyboard(); }
        function onBusyChanged() {
            if (!root.keyboardBackend.busy && !root.keyboardDragging && root.requestedKeyboardLevel >= 0) {
                if (root.sentKeyboardLevel !== root.requestedKeyboardLevel) keyboardUpdate.restart();
                else root.reconcileKeyboard();
            }
        }
        function onErrorChanged() {
            if (root.keyboardBackend.error !== "" && !root.keyboardDragging) root.clearKeyboardRequest();
        }
    }
    Timer {
        id: keyboardUpdate
        interval: 80
        onTriggered: {
            if (root.keyboardDragging || root.requestedKeyboardLevel < 0) return;
            if (root.keyboardBackend.busy) { restart(); return; }
            if (root.sentKeyboardLevel !== root.requestedKeyboardLevel) {
                root.sentKeyboardLevel = root.requestedKeyboardLevel;
                root.keyboardBackend.run("keyboard", root.sentKeyboardLevel);
                // Keep the optimistic level until a fresh snapshot confirms it.
                keyboardAck.restart();
            }
        }
    }
    Timer {
        id: keyboardAck
        interval: 2000
        onTriggered: {
            if (root.keyboardDragging || root.requestedKeyboardLevel < 0) return;
            if (root.keyboardBackend.busy) { restart(); return; }
            root.keyboardBackend.refresh();
            keyboardReconcile.restart();
        }
    }
    Timer {
        id: keyboardReconcile
        interval: 500
        onTriggered: {
            if (!root.keyboardDragging && !root.keyboardBackend.busy
                    && root.sentKeyboardLevel === root.requestedKeyboardLevel) root.clearKeyboardRequest();
        }
    }
    function goBack(){
        if(showWifi){if(wifiPicker.item&&wifiPicker.item.askingFor!=="")wifiPicker.item.closePassword();else showWifi=false;return true;}
        if(showBluetooth){showBluetooth=false;return true;}
        return false;
    }
    Shortcut {sequence:"Alt+Left";context:Qt.WindowShortcut;enabled:root.visible&&(root.showWifi||root.showBluetooth);onActivated:root.goBack()}
    property bool showWifi: false
    property bool showBluetooth: false
    function resetNavigation() {
        if (wifiPicker.item) wifiPicker.item.closePassword();
        showWifi = false;
        showBluetooth = false;
    }
    onVisibleChanged: if (!visible) resetNavigation()

    readonly property int quickCount: 7
    readonly property real quickWidth: Math.max(38,Math.min(64,(width-(quickCount-1)*8)/quickCount))
    component OverviewQuickToggle: QuickToggle {width:root.quickWidth}
    readonly property real spacing: 8
    readonly property real cellWidth: (width - 2 * spacing) / 3
    readonly property real cellHeight: (tiles.height - spacing) / 2

    Swappable {
        anchors.fill: parent
        travel: -Theme.pageTravel
        shown: !root.showWifi && !root.showBluetooth

        Row {
            id: toggles
            objectName: "overviewQuickToggles"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            OverviewQuickToggle {
                icon: Network.wifiEnabled ? "wifi" : "wifiOff"
                label: "Wi-Fi"
                checked: Network.wifiEnabled
                tint: Theme.blue
                onClicked: root.showWifi = true
            }
            OverviewQuickToggle {
                icon: "bluetooth"
                label: "Bluetooth"
                hint: Bluetooth.statusLabel
                available: Bluetooth.available
                checked: Bluetooth.enabled
                tint: Theme.blue
                onClicked: root.showBluetooth = true
            }
            OverviewQuickToggle {
                icon: "moon"
                label: "Quiet"
                available: Notifications.canSetDoNotDisturb
                hint: Notifications.doNotDisturb ? "Turn off Do Not Disturb" : "Turn on Do Not Disturb"
                checked: Notifications.doNotDisturb
                tint: Theme.indigo
                onClicked: Notifications.toggleDoNotDisturb()
            }
            OverviewQuickToggle {
                icon: "nightLight"
                label: "Night light"
                checked: NightLight.active
                tint: Theme.orange
                onClicked: NightLight.toggle()
            }
            OverviewQuickToggle {
                icon: "grid"
                label: "Customize"
                checkable: false
                tint: Theme.accent
                onClicked: SystemControls.run("studio")
            }
            OverviewQuickToggle {
                objectName: "microphoneMuteToggle"
                icon: Audio.microphoneMuted ? "micOff" : "mic"
                label: Audio.microphoneMuted ? "Mic muted" : "Mic"
                available: Audio.hasMicrophone
                checked: Audio.hasMicrophone && !Audio.microphoneMuted
                tint: Theme.green
                hint: Audio.deviceName(Audio.source) + " · " + (Audio.microphoneMuted ? "Click to unmute." : "Click to mute.")
                    + (Settings.privacyIndicators ? " " + Privacy.microphoneStatus : "")
                onClicked: Audio.toggleMicrophone()
            }
            OverviewQuickToggle {
                objectName: "cameraAccessToggle"
                readonly property bool blocked: root.cameraSettings.get("cameraDisabled", false)
                icon: blocked ? "cameraOff" : "camera"
                label: blocked ? "Cam blocked" : "Camera"
                available: root.cameraSettings.canSet("cameraDisabled")
                checked: root.cameraSettings.has("cameraDisabled") && !blocked
                tint: Theme.green
                hint: root.cameraSettings.error && root.cameraSettings.pendingName === "cameraDisabled" ? root.cameraSettings.error
                    : !root.cameraSettings.has("cameraDisabled") ? "Camera access is unavailable in this session"
                    : (blocked ? "GNOME camera access blocked. Click to allow." : "GNOME camera access allowed. Click to block.")
                        + (Settings.privacyIndicators ? " " + Privacy.cameraStatus : "")
                        + " Direct camera access is separate."
                Accessible.name: blocked ? "Allow camera access" : "Block camera access"
                onClicked: root.cameraSettings.set("cameraDisabled", !blocked)
            }
        }

        // Badge on the left; a value with a detail line, or with an adjustable bar.
        component Tile: Card {
            id: tile

            property string icon: ""
            property color tint: Theme.text
            property string value: ""
            property string detail: ""
            property real level: -1            // shows a draggable bar when >= 0
            property bool clickable: false
            property bool steppedLevel: false
            signal levelDragStarted()
            signal levelDragFinished()
            signal levelPicked(real fraction)
            signal clicked()

            activeFocusOnTab:clickable
            Accessible.role:clickable?Accessible.Button:Accessible.StaticText
            Accessible.name:value
            Accessible.description:detail
            Keys.onSpacePressed:if(clickable)clicked()
            Keys.onReturnPressed:if(clickable)clicked()
            border.color:activeFocus?Theme.accent:Theme.border
            width: root.cellWidth
            height: root.cellHeight
            color: clickable && tileHover.hovered ? Theme.surfaceRaised : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
            scale: tile.clickable && tileMouse.pressed && Theme.motionFactor > 0 ? 0.985 : 1
            Behavior on scale { NumberAnimation {duration:Theme.pressDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.springCurve} }
            TapFeedback { id:tileFeedback;parent:tile;anchors.fill:parent;radius:tile.radius;tint:tile.tint }

            HoverHandler {
                id: tileHover
            }
            MouseArea {
                id: tileMouse
                anchors.fill: parent
                anchors.margins: -12
                enabled: tile.clickable
                cursorShape: Qt.PointingHandCursor
                onClicked: { tileFeedback.play(); tile.clicked(); }
            }

            Rectangle {
                id: badge
                anchors.left: parent.left
                anchors.leftMargin: -2
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                color: Qt.rgba(tile.tint.r, tile.tint.g, tile.tint.b, 0.16)

                Icon {
                    anchors.centerIn: parent
                    name: tile.icon
                    size: 15
                    color: tile.tint
                }
            }
            Label {
                id: valueLabel
                anchors.left: badge.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -2
                text: tile.value
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                anchors.left: valueLabel.left
                anchors.right: parent.right
                anchors.top: valueLabel.bottom
                anchors.topMargin: 1
                visible: tile.level < 0
                text: tile.detail
                color: Theme.textSecondary
                font.pixelSize: Theme.fontCaption + 1
                elide: Text.ElideRight
            }
            IslandBar {
                anchors.left: valueLabel.left
                anchors.right: parent.right
                anchors.top: valueLabel.bottom
                anchors.topMargin: 6
                visible: tile.level >= 0
                implicitHeight: tile.steppedLevel ? 6 : barMouse.containsMouse ? 8 : 6
                animateValue: !tile.steppedLevel || !barMouse.pressed
                value: tile.level
                fillColor: tile.tint

                MouseArea {
                    id: barMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    function fractionAt(x) { return Math.max(0, Math.min(1, (x - 8) / Math.max(1, width - 16))); }
                    onPressed: mouse => {
                        tile.levelDragStarted();
                        tile.levelPicked(fractionAt(mouse.x));
                    }
                    onReleased: tile.levelDragFinished()
                    onCanceled: tile.levelDragFinished()
                    onPositionChanged: mouse => {
                        if (pressed)
                            tile.levelPicked(fractionAt(mouse.x));
                    }
                }
            }
        }

        Grid {
            id: tiles
            anchors.top: toggles.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            columns: 3
            spacing: root.spacing

            Tile {
                icon: Battery.charging ? "bolt" : "battery"
                tint: !Battery.available ? Theme.textSecondary
                    : Battery.charging ? Theme.green
                    : Battery.percent <= Settings.lowBatteryPercent ? Theme.red
                    : Theme.green
                value: Battery.available ? Battery.percent + "%" : "No battery"
                detail: Battery.available ? Battery.status : ""

                // Keep-awake toggle lives with power.
                IslandButton {
                    anchors.right: parent.right
                    anchors.rightMargin: -8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "coffee"
                    iconSize: 14
                    accessibleLabel: Caffeine.active ? "Turn keep awake off" : "Turn keep awake on"
                    hint: Caffeine.active ? "Keep awake: on" : "Keep awake: off"
                    subtle: Caffeine.active
                    color: Caffeine.active ? Theme.yellow : Theme.textTertiary
                    onClicked: Caffeine.toggle()
                }
            }

            Tile {
                icon: Network.wifiEnabled ? "wifi" : "wifiOff"
                tint: Network.connections.length > 0 ? Theme.blue : Theme.textSecondary
                value: Network.connections.length > 0 ? Network.connections[0].name : "Offline"
                clickable: true
                onClicked: root.showWifi = true
                detail: Network.connections.length > 1 ? "+" + (Network.connections.length - 1) + " more" : "Network"
            }

            Tile {
                icon: "bluetooth"
                clickable: true
                onClicked: root.showBluetooth = true
                tint: Bluetooth.primaryDevice ? Theme.blue : Theme.textSecondary
                value: Bluetooth.statusLabel
                detail: Bluetooth.statusDetail
            }

            Tile {
                objectName: "keyboardBacklightTile"
                readonly property var keyboard: root.keyboardBackend.data.keyboard
                readonly property int currentLevel: root.requestedKeyboardLevel >= 0 ? root.requestedKeyboardLevel : keyboard.current
                icon: "brightness"
                tint: Theme.cyan
                value: keyboard.available ? "Keys " + currentLevel + "/" + keyboard.maximum : "Keyboard light"
                detail: "Not supported"
                level: keyboard.available ? currentLevel / Math.max(1, keyboard.maximum) : -1
                clickable: keyboard.available
                onClicked: root.setKeyboardLevel((currentLevel + 1) % (keyboard.maximum + 1))
                steppedLevel: true
                onLevelDragStarted: root.beginKeyboardDrag()
                onLevelDragFinished: root.endKeyboardDrag()
                onLevelPicked: fraction => root.setKeyboardLevel(fraction * keyboard.maximum)
            }

            Tile {
                objectName: "volumeTile"
                clickable: !!(Audio.sink && Audio.sink.audio)
                onClicked: Audio.toggleMute()
                icon: Audio.muted ? "volumeOff" : "volume"
                tint: Theme.text
                value: Audio.muted ? "Muted" : "Volume " + Math.round(Audio.volume * 100) + "%"
                level: Audio.muted ? 0 : Audio.volume
                onLevelPicked: fraction => Audio.setVolume(fraction)
            }

            Tile {
                icon: "brightness"
                tint: Theme.yellow
                value: Brightness.available ? "Brightness " + Math.round(Brightness.level * 100) + "%" : "Brightness"
                level: Brightness.available ? Brightness.level : -1
                detail: Brightness.available ? "" : "Unavailable"
                onLevelPicked: fraction => Brightness.set(fraction)
            }
        }
    }

    Swappable {
        id: bluetoothLayer
        anchors.fill: parent
        shown: root.showBluetooth
        Loader {
            anchors.fill: parent
            active: root.showBluetooth || bluetoothLayer.opacity > 0.01
            sourceComponent: BluetoothList { onBack: root.showBluetooth = false }
        }
    }

    // Kept alive while it fades out, then destroyed so scanning stops.
    Swappable {
        id: wifiLayer
        anchors.fill: parent
        shown: root.showWifi

        Loader {
            id:wifiPicker
            anchors.fill: parent
            active: root.showWifi || wifiLayer.opacity > 0.01
            sourceComponent: WifiList {
                onBack: root.showWifi = false
            }
        }
    }
}
