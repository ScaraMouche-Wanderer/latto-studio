pragma Singleton

import QtQuick
import Quickshell.Bluetooth as Bluez

// Adapter-scoped devices plus bounded discovery while the device list is open.
QtObject {
    id: root
    property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var listedDevices: devices.slice().sort((a, b) =>
        Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired)
        || root.displayName(a).localeCompare(root.displayName(b)))
    readonly property bool available: !!adapter
    readonly property bool enabled: available && adapter.enabled
    readonly property bool scanning: enabled && adapter.discovering
    readonly property var connected: enabled ? listedDevices.filter(device => device.connected) : []
    readonly property var primaryDevice: connected.length > 0 ? connected[0] : null
    readonly property string statusLabel: !available ? "Unavailable" : !enabled ? "Off"
        : primaryDevice ? displayName(primaryDevice) : "Not connected"
    readonly property string statusDetail: connected.length > 1 ? connected.length + " devices"
        : primaryDevice && primaryDevice.batteryAvailable ? Math.round(primaryDevice.battery * 100) + "% battery"
        : "Bluetooth"
    property int watchers: 0
    property var ownedAdapter: null
    property string error: ""

    function displayName(device) { return device.name || device.deviceName || device.address || "Unnamed device"; }
    function watch() { watchers++; if (watchers === 1) scan(); }
    function unwatch() { watchers = Math.max(0, watchers - 1); if (watchers === 0) stopScan(); }
    function scan() {
        if (watchers === 0 || !enabled) return;
        error = "";
        // An existing external scan is not ours to stop.
        if (!adapter.discovering) {
            ownedAdapter = adapter;
            adapter.discovering = true;
        }
        if (ownedAdapter === adapter) scanTimeout.restart();
    }
    function stopScan() {
        if (scanTimeout) scanTimeout.stop();
        const previous = ownedAdapter;
        ownedAdapter = null;
        if (previous) {
            try { previous.discovering = false; } catch (e) { /* Adapter was removed. */ }
        }
    }
    function toggle() {
        if (!available) return;
        const on = !adapter.enabled;
        if (!on) stopScan();
        adapter.enabled = on;
        Activities.show("bluetoothPower", 70, { label: on ? "Bluetooth on" : "Bluetooth off", value: -1, off: !on }, 1800);
    }
    function toggleDevice(device) {
        if (!enabled || !device || !device.paired) return;
        if (device.connected) device.disconnect(); else device.connect();
    }
    onAdapterChanged: { stopScan(); if (watchers > 0) Qt.callLater(scan); }
    onEnabledChanged: { if (!enabled) stopScan(); else if (watchers > 0) scan(); }
    property Timer scanTimeout: Timer { interval: 30000; onTriggered: root.stopScan() }
    Component.onDestruction: stopScan()
}
