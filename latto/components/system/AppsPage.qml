import QtQuick
import Quickshell
import "."
import ".."
import "../../services"
import "../../theme"

Item {
    id: root
    objectName: "appsHub"
    implicitHeight: 402
    signal back()
    property string section: "launch"
    property string query: ""
    property bool searchHeld: false
    property bool watching: false
    readonly property var matches: Applications.matching(query)
    function syncHold() {
        const want = visible && section === "launch" && (search.activeFocus || list.activeFocus);
        if (want === searchHeld) return;
        searchHeld = want;
        if (want) IslandState.holdOpen(); else IslandState.release();
    }
    function syncStreams() {
        const want = visible && section === "audio";
        if (want === watching) return;
        watching = want;
        if (want) Audio.watchStreams(); else Audio.unwatchStreams();
    }
    onVisibleChanged: { syncHold(); syncStreams(); }
    onSectionChanged: { syncHold(); syncStreams(); list.positionViewAtBeginning(); }
    Component.onCompleted: syncStreams()
    Component.onDestruction: {
        if (searchHeld) IslandState.release();
        if (watching) Audio.unwatchStreams();
    }

    Rectangle {
        width: parent.width; height: 30; radius: 10; color: Theme.surface
        ControlButton { x: 2; y: 2; width: 29; height: 26; icon: "chevronLeft"; onClicked: root.back() }
        Icon { x: 42; anchors.verticalCenter: parent.verticalCenter; name: "grid"; size: 16; color: Theme.accent }
        Label { x: 67; anchors.verticalCenter: parent.verticalCenter; text: "Apps"; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
        Label { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "On this desktop"; color: Theme.textTertiary; font.pixelSize: Theme.fontCaption }
    }
    Row {
        y: 40; width: parent.width; spacing: 6
        Repeater {
            model: [{key:"launch",title:"Launch",icon:"grid"},{key:"media",title:"Media",icon:"music"},{key:"audio",title:"App audio",icon:"volume"}]
            ControlButton {
                required property var modelData
                width: (root.width-12)/3; height: 32
                text: modelData.title; icon: modelData.icon
                selected: root.section === modelData.key
                onClicked: root.section = modelData.key
            }
        }
    }
    Item {
        y: 82; width: parent.width; height: 34
        visible: root.section === "launch"
        Rectangle { anchors.fill: parent; radius: 10; color: Theme.surface; border.width: 1; border.color: search.activeFocus ? Theme.accent : Theme.border }
        Icon { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; color: Theme.textTertiary }
        TextInput {
            id: search; objectName: "appsSearch"
            x: 35; width: parent.width-70; height: parent.height
            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSmall
            verticalAlignment: TextInput.AlignVCenter; clip: true; selectByMouse: true
            text: root.query; onTextEdited: { root.query = text; list.positionViewAtBeginning(); }
            onActiveFocusChanged: root.syncHold()
            TextEntryFocus {}
            Keys.onReturnPressed: if (root.matches.length) Applications.launch(root.matches[0])
            Keys.onDownPressed: { list.currentIndex = 0; list.forceActiveFocus(); }
            Label { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: search.text === ""; text: "Find an application…"; color: Theme.textTertiary; font.pixelSize: Theme.fontSmall }
        }
        IslandButton { anchors.right: parent.right; width: 30; height: 34; icon: "close"; iconSize: 12; visible: root.query !== ""; accessibleLabel: "Clear app search"; onClicked: { root.query = ""; search.forceActiveFocus(); } }
    }
    Item {
        y: 82; width: parent.width; height: 34
        visible: root.section === "media"
        Label { width: parent.width-155; anchors.verticalCenter: parent.verticalCenter; text: Media.automatic ? "Following the active player" : "Controlling · " + Media.source; elide: Text.ElideRight; font.pixelSize: Theme.fontSmall; color: Theme.textSecondary }
        ControlButton { anchors.right: parent.right; width: 142; height: 30; text: "Follow active player"; selected: Media.automatic; onClicked: Media.useAutomatic() }
    }
    Label { y: 88; width: parent.width; visible: root.section === "audio"; text: "Playback and recording streams · drag to adjust, click to mute"; font.pixelSize: Theme.fontSmall; color: Theme.textSecondary; elide: Text.ElideRight }

    ListView {
        id: list; objectName: "appsList"
        onActiveFocusChanged: root.syncHold()
        x: 0; y: 126; width: parent.width; height: parent.height-158
        clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
        model: root.section === "launch" ? root.matches : root.section === "media" ? Media.players : Audio.streams
        delegate: Loader {
            id: rowLoader
            required property var modelData
            // A ListView can recycle a delegate before its section changes.
            // Choose the component from the entry itself, never a stale tab.
            readonly property var entry: modelData || ({})
            readonly property var audioNode: entry.audio || null
            readonly property string rowKind: entry.audio !== undefined ? "audio" : entry.identity !== undefined ? "media" : entry.id !== undefined ? "launch" : ""
            width: list.width-6
            height: rowKind === "audio" ? 88 : rowKind === "media" ? 102 : 52
            sourceComponent: rowKind === "launch" ? launchRow : rowKind === "media" ? mediaRow : rowKind === "audio" ? audioRow : null
            Component {
                id: launchRow
                Rectangle {
                    objectName: "appLaunchRow"
                    radius: 11; color: launchMouse.containsMouse || activeFocus ? Theme.surfaceRaised : Theme.surface
                    border.width: 1; border.color: activeFocus || (rowLoader.ListView.isCurrentItem && list.activeFocus) ? Theme.accent : Theme.border
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button; Accessible.name: "Launch " + rowLoader.entry.name
                    Keys.onReturnPressed: Applications.launch(rowLoader.entry)
                    Keys.onSpacePressed: Applications.launch(rowLoader.entry)
                    Image { id: appIcon; x: 12; y: 11; width: 30; height: 30; sourceSize.width: 48; sourceSize.height: 48; source: rowLoader.entry.icon ? Quickshell.iconPath(rowLoader.entry.icon, true) : ""; fillMode: Image.PreserveAspectFit }
                    Icon { x: 16; y: 15; name: "grid"; size: 22; visible: appIcon.status !== Image.Ready; color: Theme.accent }
                    Label { x: 54; y: 8; width: parent.width-95; text: rowLoader.entry.name || "Application"; font.pixelSize: Theme.fontSmall; elide: Text.ElideRight; font.weight: Font.Medium }
                    Label { x: 54; y: 29; width: parent.width-95; text: rowLoader.entry.genericName || "Application"; font.pixelSize: Theme.fontCaption; color: Theme.textTertiary; elide: Text.ElideRight }
                    Icon { anchors.right: parent.right; anchors.rightMargin: 13; anchors.verticalCenter: parent.verticalCenter; name: "chevronRight"; size: 15; color: Theme.textTertiary }
                    MouseArea { id: launchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { parent.forceActiveFocus(); Applications.launch(rowLoader.entry); } }
                }
            }
            Component {
                id: mediaRow
                Rectangle {
                    radius: 11; color: Theme.surface
                    border.width: 1; border.color: Media.player === rowLoader.entry ? Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.5) : Theme.border
                    Label { x: 12; y: 10; width: parent.width-158; text: rowLoader.entry.identity || "Media player"; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSmall; elide: Text.ElideRight }
                    Label { x: 12; y: 32; width: parent.width-24; text: rowLoader.entry.trackTitle || "No track information"; color: Theme.textSecondary; font.pixelSize: Theme.fontSmall; elide: Text.ElideRight }
                    ControlButton { anchors.right: parent.right; anchors.rightMargin: 10; y: 8; width: 126; height: 26; text: Media.player === rowLoader.entry ? (Media.automatic ? "Following" : "Selected") : "Use in island"; selected: Media.player === rowLoader.entry; onClicked: Media.selectPlayer(rowLoader.entry) }
                    Row {
                        x: 12; y: 62; spacing: 6
                        ControlButton { width: 42; height: 28; icon: "previous"; enabled: !!rowLoader.entry.canGoPrevious; onClicked: rowLoader.entry.previous() }
                        ControlButton { width: 94; height: 28; icon: rowLoader.entry.isPlaying ? "pause" : "play"; text: rowLoader.entry.isPlaying ? "Pause" : "Play"; enabled: !!rowLoader.entry.canTogglePlaying; onClicked: rowLoader.entry.togglePlaying() }
                        ControlButton { width: 42; height: 28; icon: "next"; enabled: !!rowLoader.entry.canGoNext; onClicked: rowLoader.entry.next() }
                    }
                }
            }
            Component {
                id: audioRow
                Rectangle {
                    radius: 11; color: Theme.surface
                    Label { x: 12; y: 8; width: parent.width-135; text: Audio.streamName(rowLoader.entry); font.pixelSize: Theme.fontSmall; font.weight: Font.Medium; elide: Text.ElideRight }
                    // A sink stream consumes captured audio; a source stream
                    // produces audio for playback (PipeWire's stream direction).
                    Label { x: 12; y: 27; text: rowLoader.entry.isSink ? "Recording" : "Playback"; color: rowLoader.entry.isSink ? Theme.orange : Theme.textTertiary; font.pixelSize: Theme.fontCaption }
                    ControlButton { anchors.right: parent.right; anchors.rightMargin: 10; y: 8; width: 110; height: 28; enabled: !!rowLoader.entry.ready && rowLoader.audioNode !== null; text: (rowLoader.audioNode ? rowLoader.audioNode.muted : false) ? "Unmute" : "Mute"; icon: (rowLoader.audioNode ? rowLoader.audioNode.muted : false) ? "volumeOff" : "volume"; selected: (rowLoader.audioNode ? rowLoader.audioNode.muted : false); onClicked: Audio.toggleStreamMute(rowLoader.entry) }
                    ControlSlider { objectName: "appAudioLevel"; x: 12; y: 41; width: parent.width-24; height: 44; text: "Level"; value: rowLoader.audioNode ? rowLoader.audioNode.volume : 0; enabled: !!rowLoader.entry.ready && rowLoader.audioNode !== null; live: true; onMoved: value => Audio.setStreamVolume(rowLoader.entry,value); onCommitted: value => Audio.setStreamVolume(rowLoader.entry,value) }
                }
            }
        }
        Keys.onReturnPressed: if (root.section === "launch" && currentIndex >= 0 && currentIndex < root.matches.length) Applications.launch(root.matches[currentIndex])
        Rectangle { anchors.centerIn: parent; width: Math.min(390,parent.width-24); height: 116; radius: 14; color: Theme.surface; visible: list.count === 0
            Icon { anchors.horizontalCenter: parent.horizontalCenter; y: 15; name: root.section === "launch" ? "search" : root.section === "media" ? "music" : "volume"; size: 22; color: Theme.textTertiary }
            Label { y: 49; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.section === "launch" ? "No matching applications" : root.section === "media" ? "No media player connected" : "No active audio streams"; font.pixelSize: Theme.fontSmall }
            Label { x: 15; y: 74; width: parent.width-30; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: root.section === "launch" ? "Try an app name or keyword." : root.section === "media" ? "Open an app that exposes desktop playback controls." : "Start playback or recording in an app to control its level."; font.pixelSize: Theme.fontCaption; color: Theme.textTertiary }
        }
    }
    Rectangle { x: parent.width-3; y: list.y+(list.height-height)*(list.visibleArea.yPosition/Math.max(.001,1-list.visibleArea.heightRatio)); width: 3; height: Math.max(14,list.height*list.visibleArea.heightRatio); radius: 1.5; color: Theme.textTertiary; visible: list.contentHeight > list.height }
    Label { anchors.bottom: parent.bottom; width: parent.width; height: 23; verticalAlignment: Text.AlignVCenter; text: Applications.feedback || (root.section === "launch" ? root.matches.length + " applications · Enter launches the first search result" : root.section === "media" ? "Player selection also updates the compact island and Media tab." : "Levels apply to individual streams, not the master volume."); color: Applications.feedback ? (Applications.failed ? Theme.orange : Theme.green) : Theme.textTertiary; font.pixelSize: Theme.fontCaption; elide: Text.ElideRight }
}
