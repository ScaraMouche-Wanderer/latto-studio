import QtQuick
import "../services"
import "../theme"

Item {
    id: root

    required property var entries
    property bool hasMore: false
    signal tabRequested(string name)
    signal allTabsRequested()

    Flickable {
        anchors.top: parent.top
        width: parent.width
        height: 24
        contentWidth: Math.max(width, tabs.implicitWidth)
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        Row {
            id: tabs
            x: (parent.width - width) / 2
            spacing: 4

            Repeater {
                model: root.entries
                Row {
                    required property int index
                    required property var modelData
                    spacing: 4
                    Label {
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "·"
                        color: Theme.textTertiary
                    }
                    IslandButton {
                        objectName: "summaryTab"
                        text: modelData.label
                        height: 24
                        width: implicitWidth - 14
                        color: Theme.accent
                        fontSize: Theme.fontCaption
                        onClicked: root.tabRequested(modelData.name)
                    }
                }
            }
            IslandButton {
                visible: root.hasMore
                text: "…"
                height: 24
                width: 26
                color: Theme.accent
                hint: "Show all tabs"
                accessibleLabel: hint
                onClicked: root.allTabsRequested()
            }
        }
    }

    Row {
        anchors.top: parent.top
        anchors.topMargin: 28
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 6

        SummaryCard {
            objectName: "summaryCpu"
            title: "CPU"
            value: SystemStats.cpuHistory.length > 1 ? Math.round(SystemStats.cpu) + "%" : "—"
        }
        SummaryCard {
            objectName: "summaryMemory"
            title: "Memory"
            value: SystemStats.memoryTotalGiB > 0 ? SystemStats.memoryUsedGiB.toFixed(1) + " GB" : "—"
        }
        SummaryCard {
            objectName: "summaryBattery"
            title: "Battery"
            value: Battery.available ? Battery.percent + "%" : "Unavailable"
        }
    }

    component SummaryCard: Rectangle {
        id: card
        required property string title
        required property string value

        width: Math.max(0, (parent.width - 2 * parent.spacing) / 3)
        height: parent.height
        radius: 9
        color: Theme.surface
        Accessible.role: Accessible.StaticText
        Accessible.name: title + " " + value

        Label {
            x: 11
            y: 5
            width: Math.max(0, parent.width - 22)
            text: card.title
            font.pixelSize: Theme.fontCaption
            elide: Text.ElideRight
        }
        Label {
            x: 11
            y: 21
            width: Math.max(0, parent.width - 22)
            text: card.value
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            color: Theme.accent
            elide: Text.ElideRight
        }
    }
}
