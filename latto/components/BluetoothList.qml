import QtQuick
import Quickshell.Bluetooth as Bluez
import "../services"
import "../theme"

Item {
    id: root
    signal back()
    Component.onCompleted: Bluetooth.watch()
    Component.onDestruction: Bluetooth.unwatch()

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 30
        IslandButton {
            id: backButton
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevronLeft"
            iconSize: 16
            color: Theme.textSecondary
            onClicked: root.back()
        }
        Label {
            anchors.left: backButton.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: Bluetooth.scanning ? "Bluetooth · scanning…" : "Bluetooth"
            font.weight: Font.DemiBold
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            IslandButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                fontSize: Theme.fontSmall
                onClicked: SystemControls.run("settings", "bluetooth")
            }
            IslandButton {
                visible: Bluetooth.enabled
                anchors.verticalCenter: parent.verticalCenter
                text: Bluetooth.scanning ? "Stop" : "Scan"
                enabled: !Bluetooth.scanning || Bluetooth.ownedAdapter !== null
                opacity: enabled ? 1 : 0.45
                fontSize: Theme.fontSmall
                onClicked: Bluetooth.scanning ? Bluetooth.stopScan() : Bluetooth.scan()
            }
            IslandButton {
                anchors.verticalCenter: parent.verticalCenter
                enabled: Bluetooth.available
                icon: "bluetooth"
                text: Bluetooth.enabled ? "On" : "Off"
                color: Bluetooth.enabled ? Theme.blue : Theme.textSecondary
                fontSize: Theme.fontSmall
                onClicked: Bluetooth.toggle()
            }
        }
    }
    Label {
        id: hint
        anchors.top: header.bottom
        anchors.topMargin: 3
        width: parent.width
        visible: Bluetooth.enabled
        text: Bluetooth.statusLabel + " · Put your device in pairing mode to find it."
        color: Theme.textTertiary
        font.pixelSize: Theme.fontCaption
        elide: Text.ElideRight
    }
    Label {
        anchors.centerIn: list
        width: parent.width - 40
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: !Bluetooth.enabled || Bluetooth.listedDevices.length === 0
        text: !Bluetooth.available ? "No Bluetooth adapter available"
            : !Bluetooth.enabled ? "Bluetooth is off — turn it on above"
            : Bluetooth.scanning ? "Looking for discoverable devices…"
            : "No devices found. Enable pairing mode and press Scan."
        color: Theme.textTertiary
        font.pixelSize: Theme.fontSmall
    }
    ListView {
        id: list
        anchors.top: hint.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: Bluetooth.enabled
        clip: true
        spacing: 3
        boundsBehavior: Flickable.StopAtBounds
        model: Bluetooth.listedDevices
        delegate: Item {
            id: row
            required property var modelData
            readonly property bool busy: modelData.pairing || modelData.state === Bluez.BluetoothDeviceState.Connecting || modelData.state === Bluez.BluetoothDeviceState.Disconnecting
            width: ListView.view.width
            height: 44
            Rectangle {
                anchors.fill: parent
                color: rowHover.hovered ? Theme.surfaceRaised : Theme.surface
                radius: 10
            }
            HoverHandler { id: rowHover }
            Icon {
                id: deviceIcon
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                name: "bluetooth"
                size: 16
                color: row.modelData.connected ? Theme.blue : Theme.textSecondary
            }
            Label {
                id: name
                anchors.left: deviceIcon.right
                anchors.leftMargin: 9
                anchors.right: action.left
                anchors.rightMargin: 8
                y: 6
                text: Bluetooth.displayName(row.modelData)
                font.pixelSize: Theme.fontSmall + 1
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Label {
                anchors.left: name.left
                anchors.right: name.right
                y: 24
                text: row.busy ? "Working…" : row.modelData.connected ? "Connected" + (row.modelData.batteryAvailable ? " · " + Math.round(row.modelData.battery * 100) + "% battery" : "") : row.modelData.paired ? "Paired · not connected" : "Available to pair"
                color: row.modelData.connected ? Theme.blue : Theme.textTertiary
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }
            IslandButton {
                id: action
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                text: row.busy ? "Wait…" : row.modelData.connected ? "Disconnect" : row.modelData.paired ? "Connect" : "Pair…"
                fontSize: Theme.fontSmall
                enabled: !row.busy
                onClicked: {
                    if (row.modelData.paired) Bluetooth.toggleDevice(row.modelData);
                    else SystemControls.run("settings", "bluetooth");
                }
            }
        }
    }
}
