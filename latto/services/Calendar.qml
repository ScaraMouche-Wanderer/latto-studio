pragma Singleton

import QtQuick
import Quickshell.Io

// khal emits a JSON array per day, including empty days. Keeping those
// boundaries preserves the dates of multi-day and recurring events.
QtObject {
    id: root

    property var days: []
    property string error: ""
    property date refreshDate: new Date()
    readonly property bool enabled: Settings.calendarEnabled
    readonly property bool loading: probe.running
    readonly property var agenda: {
        const rows = [];
        for (const day of days)
            rows.push({ day: true, title: day.label }, ...day.events);
        return rows;
    }

    function parseAgenda(text, date) {
        return text.trim().split("\n").filter(line => line.trim()).map((line, index) => {
            const day = new Date(date.getFullYear(), date.getMonth(), date.getDate() + index);
            const title = index === 0 ? "Today" : index === 1 ? "Tomorrow" : Qt.formatDate(day, "dddd");
            const events = JSON.parse(line).map(event => {
                const start = event["start-time"];
                const ongoing = event["start-style"] === "→" || event["start-style"] === "->";
                return {
                    day: false,
                    title: String(event.title || "Untitled event").replace(/\s+/g, " ").trim() || "Untitled event",
                    time: !start ? "All day" : ongoing ? "Ongoing" : start
                };
            });
            return { key: Qt.formatDate(day, "yyyy-MM-dd"), label: title + " · " + Qt.formatDate(day, "d MMM"), events };
        }).filter(day => day.events.length > 0);
    }

    function hasEvents(date) {
        const key = Qt.formatDate(date, "yyyy-MM-dd");
        return days.some(day => day.key === key);
    }

    function refresh() {
        if (!enabled || probe.running)
            return;
        refreshDate = new Date();
        error = "";
        probe.running = true;
    }

    onEnabledChanged: {
        if (!enabled) {
            probe.running = false;
            days = [];
            error = "";
        }
    }

    property Process probe: Process {
        command: ["/usr/bin/env", "khal", "--no-color", "list", "today", "3d",
            "--json", "title", "--json", "start-time", "--json", "start-style"]
        stdout: StdioCollector { id: agendaOutput }
        // Keep calendar details out of the Quickshell log on failure.
        stderr: StdioCollector {}
        onExited: code => {
            if (!root.enabled) return;
            if (code !== 0) {
                root.days = [];
                root.error = code === 127 ? "Install khal to show your agenda." : "Could not read your agenda. Check your khal setup.";
                return;
            }
            try {
                const updated = root.parseAgenda(agendaOutput.text, root.refreshDate);
                if (JSON.stringify(updated) !== JSON.stringify(root.days))
                    root.days = updated;
            } catch (error) {
                root.days = [];
                root.error = "Could not read your agenda. Check your khal setup.";
            }
        }
    }

    property Timer timer: Timer {
        interval: 300000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
