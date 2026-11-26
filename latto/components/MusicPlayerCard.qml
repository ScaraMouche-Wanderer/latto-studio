import QtQuick
import "../services"
import "../theme"

Rectangle {
    id:root
    objectName:"musicPlayerCard"
    property bool hasPlayer:false
    readonly property bool isNative:Media.source==="Latto Music"
    readonly property bool loading:isNative&&LattoMusic.phase==="loading"
    height:164;radius:17;color:Theme.surface;border.width:1;border.color:Theme.border
    RoundedImage {id:art;x:12;y:12;width:64;height:64;radius:12;source:root.hasPlayer?Media.art:""}
    Label {x:88;y:11;width:parent.width-102;text:!root.hasPlayer?"MUSIC":root.loading?"LOADING AUDIO":root.isNative&&LattoMusic.phase==="error"?"UNAVAILABLE":Media.playing?"NOW PLAYING":root.isNative&&LattoMusic.phase==="stopped"?"STOPPED":"PAUSED";font.pixelSize:9;font.letterSpacing:1.1;font.weight:Font.DemiBold;color:root.loading||Media.playing?Theme.accent:Theme.textTertiary}
    Label {x:88;y:29;width:parent.width-102;text:root.hasPlayer?Media.title:"Find your next song";font.pixelSize:Theme.fontTitle;font.weight:Font.DemiBold;elide:Text.ElideRight;textFormat:Text.PlainText}
    Label {x:88;y:53;width:parent.width-102;text:root.hasPlayer?(Media.artist||Media.source):"Search below, then choose a track.";font.pixelSize:Theme.fontSmall;color:Theme.textSecondary;elide:Text.ElideRight;textFormat:Text.PlainText}
    Label {x:88;y:71;width:parent.width-102;visible:root.hasPlayer&&Settings.showLyrics&&text!=="";text:Lyrics.currentText;font.pixelSize:Theme.fontCaption;color:Theme.accent;elide:Text.ElideRight;textFormat:Text.PlainText}
    MusicSeekBar {x:12;y:88;width:parent.width-24;visible:root.hasPlayer}
    Label {x:14;y:97;width:parent.width-28;visible:!root.hasPlayer;text:"Background playback · no extra window";font.pixelSize:Theme.fontCaption;color:Theme.textTertiary}
    Row {
        anchors.horizontalCenter:parent.horizontalCenter;y:121;height:32;spacing:7
        IslandButton {objectName:"musicPreviousButton";width:28;height:32;icon:"previous";iconSize:18;enabled:!!Media.player&&Media.player.canGoPrevious;accessibleLabel:"Previous track";hint:"Previous track";onClicked:Media.previous()}
        IslandButton {objectName:"musicPlayButton";width:36;height:32;primary:true;icon:Media.playing?"pause":"play";iconSize:19;enabled:!!Media.player&&Media.player.canTogglePlaying;accessibleLabel:root.isNative&&LattoMusic.phase==="error"?"Retry track":Media.playing?"Pause":"Play";hint:root.isNative&&LattoMusic.phase==="error"?"Retry this track":"";onClicked:Media.toggle()}
        IslandButton {objectName:"musicNextButton";width:28;height:32;icon:"next";iconSize:18;enabled:!!Media.player&&Media.player.canGoNext;accessibleLabel:"Next track";hint:"Next track";onClicked:Media.next()}
    }
    IslandButton {objectName:"musicStopButton";x:9;y:123;width:48;height:28;text:"Stop";fontSize:Theme.fontSmall;visible:root.isNative&&root.hasPlayer;color:Theme.textTertiary;onClicked:LattoMusic.stop()}
    IslandButton {x:12;y:123;width:28;height:28;icon:"shuffle";iconSize:14;visible:!root.isNative&&Media.shuffleSupported;color:Media.shuffle?Theme.accent:Theme.textTertiary;accessibleLabel:"Shuffle";onClicked:Media.toggleShuffle()}
    MusicVolume {anchors.right:parent.right;anchors.rightMargin:12;y:123;visible:root.hasPlayer}
}
