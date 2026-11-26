import QtQuick
import "../services"
import "../theme"

// Expanded island: staged reveal, segmented tabs and directional page changes.
Item {
    id: root

    // Size preferences flow from the selected page to its own island window.
    // Keep layout at its final size while the surrounding pill animates.
    property bool searchPending:false
    property bool pinned:false
    property bool keyboardInput:false
    property Item keyboardTarget:null
    function selectKeyboardTarget(target) {
        for (let item = target; item; item = item.parent) {
            if (item === root) { keyboardTarget = target; return true; }
        }
        return false;
    }
    function focusKeyboardTarget() {
        function editable(item) {
            if (!item || !item.visible || !item.enabled) return null;
            if (item instanceof TextInput || item instanceof TextEdit) return item;
            for (const child of item.children || []) { const found=editable(child); if(found)return found; }
            return null;
        }
        let target=null;
        for (let item = keyboardTarget; item; item = item.parent) {
            if (item === page.item && keyboardTarget.visible && keyboardTarget.enabled) {
                target=keyboardTarget;
                break;
            }
        }
        if (!target) target=editable(page.item);
        if(target)target.forceActiveFocus(Qt.ShortcutFocusReason);
        else if(page.item)page.item.forceActiveFocus(Qt.ShortcutFocusReason);
        else root.forceActiveFocus(Qt.ShortcutFocusReason);
    }
    signal closeRequested()
    property bool presented: true
    property int navigationDirection: 1
    property int previousIndex: -1
    property real entryProgress: presented ? 1 : 0
    Behavior on entryProgress {
        SequentialAnimation {
            PauseAnimation { duration: root.presented ? Theme.contentDelay : 0 }
            NumberAnimation {
                duration: root.presented ? Theme.contentEnterDuration : Theme.contentExitDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.smoothCurve
            }
        }
    }
    property real availableWidth:640
    property real availableHeight:640
    readonly property bool summaryEnabled: Settings.expandedLayout === "summary"
    readonly property bool summaryActive: summaryEnabled && requestedTab === ""
    readonly property int contentPadding: summaryActive ? 14 : Theme.padding
    readonly property bool systemPageReady:activeTab==="system"&&page.status===Loader.Ready&&page.loadedTab===activeTab&&page.item!==null
    readonly property real preferredWidth:summaryActive ? 420 : Math.max(tabBar.width+2*Theme.padding,
        systemPageReady?page.item.preferredIslandWidth:Theme.expandedWidth)
    readonly property real preferredHeight: {
        if (summaryActive) return 102;
        if (systemPageReady) return Math.max(Theme.expandedHeight, page.item.preferredPageHeight + 46 + 2 * Theme.padding);
        const pageHeights = { calendar: 320, clipboard: 500, codex: 500, media: 520, notifications: 440, timers: 320 };
        return pageHeights[activeTab] || Theme.expandedHeight;
    }
    property real targetWidth:Theme.expandedWidth
    property real targetHeight:Theme.expandedHeight
    // A Loader replaces its item in several synchronous steps. Commit one
    // complete geometry after those steps, never an intermediate page size.
    function updateTargetGeometry(){
        const w=Math.min(Math.max(1,availableWidth),preferredWidth);
        const h=Math.min(Math.max(1,availableHeight),640,preferredHeight);
        if(Number.isFinite(w)&&Number.isFinite(h)){targetWidth=w;targetHeight=h;}
    }
    onPreferredWidthChanged:Qt.callLater(updateTargetGeometry)
    onPreferredHeightChanged:Qt.callLater(updateTargetGeometry)
    onAvailableWidthChanged:Qt.callLater(updateTargetGeometry)
    onAvailableHeightChanged:Qt.callLater(updateTargetGeometry)
    Component.onCompleted:Qt.callLater(updateTargetGeometry)

    // Keep the whole expanded view on the main scene graph. A blurred layer
    // allocates a large offscreen texture and switches rendering paths during
    // open/close, exactly while the rounded native window shape is changing.
    // Retain the property for the existing state animation API, with no layer.
    property real blur: 0

    // Tab definitions: icon, name (for screen readers) and the page file in
    // components/tabs.
    readonly property var tabs: ({
        media: { icon: "music", label: "Media", file: "MediaTab.qml" },
        notifications: { icon: "bell", label: "Notifications", file: "NotificationsTab.qml" },
        stats: { icon: "barChart", label: "Stats", summaryLabel: "Statistics", file: "StatsTab.qml" },
        timers: { icon: "timer", label: "Timers", file: "TimersTab.qml" },
        clipboard: { icon: "clipboard", label: "Clipboard", file: "ClipboardTab.qml" },
        calendar: { icon: "calendar", label: "Calendar", file: "CalendarTab.qml" },
        overview: { icon: "grid", label: "Overview", file: "OverviewTab.qml" },
        codex: { icon: "keyboard", label: "Codex", file: "CodexTab.qml" },
        system: { icon: "bolt", label: "System", file: "SystemTab.qml" }
    })

    readonly property var enabledTabs: Settings.tabs.filter(name => tabs[name] !== undefined)

    readonly property var rememberedTabs: ["overview", "stats", "system", "notifications"]
    readonly property string defaultTab: enabledTabs.includes("overview") ? "overview" : (enabledTabs[0] || "")
    property string reopenTab: "overview"
    property string requestedTab: ""
    readonly property string activeTab: summaryActive ? "" : enabledTabs.includes(requestedTab) ? requestedTab : defaultTab
    readonly property int activeIndex: enabledTabs.indexOf(activeTab)
    onActiveIndexChanged: {
        if (activeIndex >= 0 && previousIndex >= 0) navigationDirection = activeIndex < previousIndex ? -1 : 1;
        previousIndex = activeIndex;
    }

    function rememberClosedTab() {
        // Utility tabs remain available, but reopening returns to the default.
        reopenTab = rememberedTabs.includes(activeTab) ? activeTab : defaultTab;
        searchPending = false;
        searchFocus.stop();
    }
    function prepareOpen(name) {
        requestedTab = enabledTabs.includes(name) ? name : summaryEnabled ? ""
            : enabledTabs.includes(reopenTab) ? reopenTab : defaultTab;
        // Retained pages reopen at their main section. Reset here so the
        // outgoing subsection stays intact throughout the close animation.
        if (page.item && typeof page.item.resetNavigation === "function") page.item.resetNavigation();
        updateTargetGeometry();
    }
    function selectTab(name) {
        if (enabledTabs.includes(name)) requestedTab = name;
    }
    function showSummary() {
        searchPending = false;
        searchFocus.stop();
        requestedTab = "";
    }
    function stepTab(offset) {
        if (enabledTabs.length === 0 || (!summaryActive && enabledTabs.length < 2)) return;
        const index = summaryActive && offset > 0 ? -1 : Math.max(0, activeIndex);
        selectTab(enabledTabs[(index + offset + enabledTabs.length) % enabledTabs.length]);
    }

    Item {
        id: tabBar
        objectName:"islandTabBar"
        visible: !root.summaryActive
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: tabRow.width + 74
        height: 32
        opacity: 0.65 + 0.35 * root.entryProgress
        transform: Translate { y: Theme.motionFactor > 0 ? -4 * (1 - root.entryProgress) : 0 }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }

        Rectangle {
            id: highlight

            readonly property Item target: tabRepeater.count > root.activeIndex && root.activeIndex >= 0
                ? tabRepeater.itemAt(root.activeIndex) : null

            x: target ? tabRow.x + target.x : 4
            y: 4
            width: target ? target.width : 0
            height: parent.height - 8
            radius: height / 2
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)

            Behavior on x {
                NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
            }
            Behavior on width {
                NumberAnimation { duration: Theme.pageDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve }
            }
        }

        IslandButton {
            id:pinButton
            objectName:"islandPinButton"
            anchors.right:closeButton.left;anchors.rightMargin:2;anchors.verticalCenter:parent.verticalCenter
            width:28;height:26;icon:"pin";iconSize:14
            color:root.pinned?Theme.accent:Theme.textTertiary
            subtle:root.pinned
            accessibleLabel:root.pinned?"Unpin island":"Keep island open"
            hint:(root.pinned?"Unpin":"Keep open")+" · Ctrl+Shift+P"
            onClicked:root.pinned=!root.pinned
        }
        IslandButton {
            id:closeButton
            objectName:"islandCloseButton"
            anchors.right:parent.right;anchors.rightMargin:4;anchors.verticalCenter:parent.verticalCenter
            width:28;height:26;icon:"close";iconSize:13
            accessibleLabel:"Close island"
            hint:"Close · Esc"
            onClicked:root.closeRequested()
        }
        Row {
            id: tabRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                id: tabRepeater
                model: root.enabledTabs

                IslandTab {
                    required property string modelData
                    required property int index
                    icon: root.tabs[modelData].icon
                    text: root.tabs[modelData].label
                    shortcutHint:"Alt+"+(index+1)
                    badge: modelData === "notifications" ? (Settings.notificationsEnabled ? Notifications.count : NotificationInbox.unread) : 0
                    selected: modelData === root.activeTab
                    onActivated: root.requestedTab = modelData
                    Shortcut { sequence:"Alt+"+(index+1);context:Qt.WindowShortcut;enabled:root.visible&&index<9;onActivated:root.selectTab(modelData) }
                }
            }
        }
    }
    ExpandedSummary {
        objectName: "expandedSummary"
        anchors.fill: parent
        visible: root.summaryActive
        opacity: root.entryProgress
        entries: root.enabledTabs.slice(0, 5).map(name => ({ name: name, label: root.tabs[name].summaryLabel || root.tabs[name].label }))
        hasMore: root.enabledTabs.length > entries.length
        onTabRequested: name => root.selectTab(name)
        onAllTabsRequested: root.selectTab(root.defaultTab)
    }
    Spinner { anchors.centerIn:page;visible:page.status===Loader.Loading&&page.item===null;size:20;color:Theme.accent }

    PageHost {
        id:page
        objectName:"expandedPageLoader"
        anchors.top:tabBar.bottom;anchors.topMargin:14
        anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
        direction: root.navigationDirection
        animateChanges: root.presented
        opacity: root.entryProgress
        transform: Translate { y: Theme.motionFactor > 0 ? 8 * (1 - root.entryProgress) : 0 }
        source:root.activeTab!==""?Qt.resolvedUrl("tabs/"+root.tabs[root.activeTab].file):""
        property string loadedTab:""
        onLoaded:{loadedTab=root.activeTab;if(item){if(root.keyboardInput)Qt.callLater(root.focusKeyboardTarget);else item.forceActiveFocus();if(root.searchPending&&loadedTab==="system"){root.searchPending=false;item.openSearch();}}}
    }
    Column {
        anchors.centerIn:page;spacing:8;visible:page.status===Loader.Error
        Label {text:"This page could not load";color:Theme.orange;font.pixelSize:Theme.fontSmall}
        IslandButton {text:"Retry";icon:"refresh";onClicked:page.request()}
    }
    Shortcut {sequence:"Escape";context:Qt.WindowShortcut;enabled:root.visible;onActivated:{
        if(page.item&&typeof page.item.goBack==="function"&&page.item.goBack())return;
        if(root.summaryEnabled&&!root.summaryActive){root.showSummary();return;}
        root.closeRequested();
    }}
    Shortcut {sequence:"Ctrl+K";context:Qt.WindowShortcut;enabled:root.visible&&root.enabledTabs.includes("system");onActivated:{
        root.searchPending=true;root.selectTab("system");searchFocus.restart();
    }}
    Timer {id:searchFocus;interval:0;onTriggered:if(page.loadedTab==="system"&&page.item){root.searchPending=false;page.item.openSearch();}}
    Shortcut {sequence:"Ctrl+Tab";context:Qt.WindowShortcut;enabled:root.visible;onActivated:root.stepTab(1)}
    Shortcut {sequence:"Ctrl+Shift+Tab";context:Qt.WindowShortcut;enabled:root.visible;onActivated:root.stepTab(-1)}
    Shortcut {sequence:"Ctrl+Shift+P";context:Qt.WindowShortcut;enabled:root.visible;onActivated:root.pinned=!root.pinned}
}
