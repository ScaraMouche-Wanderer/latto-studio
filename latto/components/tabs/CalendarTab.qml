import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import "../../services"
import "../../theme"
import ".."

// Month grid (Monday first) beside a dated, scrollable khal agenda.
Item {
    id: root

    Component.onCompleted: Calendar.refresh()

    // Any date inside the month being shown.
    property date shownMonth: new Date()

    readonly property int year: shownMonth.getFullYear()
    readonly property int monthIndex: shownMonth.getMonth()
    readonly property int leadingBlanks: (new Date(year, monthIndex, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(year, monthIndex + 1, 0).getDate()
    readonly property var today: clock.date
    readonly property var weekdays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    onTodayChanged: {
        // SystemClock updates every minute. Refresh only when the date rolls over.
        if (Calendar.enabled && Calendar.refreshDate.toDateString() !== today.toDateString())
            Calendar.refresh();
    }

    function resetNavigation() { shownMonth = new Date(); }
    Shortcut {
        sequence: "Ctrl+Home"
        context: Qt.WindowShortcut
        enabled: root.visible
        onActivated: root.resetNavigation()
    }

    function shiftMonth(delta) {
        shownMonth = new Date(year, monthIndex + delta, 1);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        id: month
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0, Math.min(300, (root.width - 12) * 0.53))

        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            height: 26

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.right: monthControls.left
                anchors.rightMargin: 8
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.shownMonth, "MMMM yyyy")
                font.pixelSize: Theme.fontBody + 1
                font.weight: Font.DemiBold
            }
            Row {
                id: monthControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                IslandButton {
                    text: "Today"
                    fontSize: Theme.fontSmall
                    accessibleLabel: "Return to the current month"
                    hint: "Current month · Ctrl+Home"
                    onClicked: root.resetNavigation()
                }
                IslandButton {
                    accessibleLabel: "Previous month"
                    hint: "Previous month"
                    icon: "chevronLeft"
                    iconSize: 16
                    color: Theme.textSecondary
                    onClicked: root.shiftMonth(-1)
                }
                IslandButton {
                    accessibleLabel: "Next month"
                    hint: "Next month"
                    icon: "chevronRight"
                    iconSize: 16
                    color: Theme.textSecondary
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        Grid {
            id: grid
            anchors.top: header.bottom
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 7

            Repeater {
                model: root.weekdays
                Label {
                    required property string modelData
                    width: grid.width / 7
                    height: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textTertiary
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: 42

                Item {
                    id: cell

                    required property int index
                    readonly property int day: index - root.leadingBlanks + 1
                    readonly property bool inMonth: day >= 1 && day <= root.daysInMonth
                    readonly property bool isToday: inMonth
                        && day === root.today.getDate()
                        && root.monthIndex === root.today.getMonth()
                        && root.year === root.today.getFullYear()
                    readonly property bool hasEvents: inMonth && Calendar.enabled
                        && Calendar.hasEvents(new Date(root.year, root.monthIndex, day))

                    width: grid.width / 7
                    height: 24

                    Rectangle {
                        anchors.centerIn: parent
                        width: 23
                        height: 23
                        radius: width / 2
                        color: Theme.accent
                        visible: cell.isToday
                    }
                    Label {
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.day : ""
                        color: cell.isToday ? Theme.text : (cell.index % 7 >= 5 ? Theme.textSecondary : Theme.text)
                        font.pixelSize: Theme.fontSmall
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: 3
                        height: 3
                        radius: 1.5
                        visible: cell.hasEvents
                        color: cell.isToday ? Theme.island : Theme.accent
                    }
                }
            }
        }
    }

    Card {
        anchors.left: month.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        title: "Agenda · 3 days"

        Label {
            id: todayLabel
            anchors.left: parent.left
            anchors.right: refreshButton.left
            anchors.rightMargin: 6
            height: refreshButton.height
            verticalAlignment: Text.AlignVCenter
            text: Qt.formatDate(root.today, "ddd, d MMMM")
            font.pixelSize: Theme.fontTitle
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        IslandButton {
            id: refreshButton
            objectName: "refreshCalendarAgenda"
            anchors.right: parent.right
            icon: "refresh"
            iconSize: 14
            enabled: Calendar.enabled && !Calendar.loading
            accessibleLabel: "Refresh calendar agenda"
            hint: "Refresh agenda"
            onClicked: Calendar.refresh()
        }

        ListView {
            id: agenda
            objectName: "calendarAgenda"
            anchors.top: todayLabel.bottom
            anchors.topMargin: 7
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            activeFocusOnTab: count > 0
            Accessible.role: Accessible.List
            Accessible.name: "Upcoming events"
            model: Calendar.enabled ? Calendar.agenda : []
            onCountChanged: positionViewAtBeginning()

            highlight: Rectangle {
                visible: agenda.activeFocus
                radius: 5
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
            }

            delegate: Item {
                id: agendaRow
                required property var modelData
                required property int index
                width: agenda.width - 7
                height: modelData.day ? 19 : 22
                Accessible.role: modelData.day ? Accessible.Heading : Accessible.ListItem
                Accessible.name: modelData.day ? modelData.title : modelData.time + ", " + modelData.title

                Label {
                    id: eventTime
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(66, parent.width * 0.34)
                    visible: !agendaRow.modelData.day
                    text: agendaRow.modelData.time || ""
                    textFormat: Text.PlainText
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                    font.features: ({ "tnum": 1 })
                    elide: Text.ElideRight
                }
                Label {
                    id: eventTitle
                    anchors.left: agendaRow.modelData.day ? parent.left : eventTime.right
                    anchors.leftMargin: agendaRow.modelData.day ? 0 : 6
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: agendaRow.modelData.title
                    textFormat: Text.PlainText
                    color: agendaRow.modelData.day ? Theme.accent : Theme.text
                    font.pixelSize: Theme.fontSmall
                    font.weight: agendaRow.modelData.day ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                HoverHandler { id: eventHover; enabled: !agendaRow.modelData.day }
                QQC.ToolTip {
                    parent: agendaRow
                    text: agendaRow.modelData.title
                    visible: !agendaRow.modelData.day && eventTitle.truncated
                        && (eventHover.hovered || (agenda.activeFocus && agenda.currentIndex === agendaRow.index))
                    delay: 500
                    contentItem: Label {
                        width: Math.min(260, implicitWidth)
                        text: agendaRow.modelData.title
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.Wrap
                    }
                    background: Rectangle { radius: 8; color: Theme.surfaceRaised; border.color: Theme.border }
                }
            }
            QQC.ScrollBar.vertical: QQC.ScrollBar {
                width: 4
                policy: QQC.ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: 1.5
                    color: Theme.textTertiary
                }
                background: Item {}
            }
        }

        Label {
            anchors.fill: agenda
            anchors.topMargin: 8
            visible: agenda.count === 0
            text: !Calendar.enabled ? "Enable Calendar events in Studio’s Behaviour settings."
                : Calendar.loading ? "Loading agenda…"
                : Calendar.error || "No events in the next three days."
            color: Calendar.error ? Theme.orange : Theme.textSecondary
            font.pixelSize: Theme.fontSmall
            wrapMode: Text.Wrap
        }
    }
}
