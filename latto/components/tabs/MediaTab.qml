import QtQuick
import "../../services"
import "../../theme"
import ".."

Item {
    id:root
    property bool searchHeld:false
    property bool searchEdited:false
    readonly property bool hasPlayer:Media.player!==null&&(Media.source!=="Latto Music"||!!LattoMusic.state.track)
    function syncSearchHold(){const want=visible&&musicSearch.activeFocus;if(want===searchHeld)return;searchHeld=want;if(want)IslandState.holdOpen();else IslandState.release();}
    function focusSearch(){musicSearch.forceActiveFocus();musicSearch.selectAll();}
    function searchMusic(){const query=musicSearch.text.trim();if(!query||LattoMusic.searching)return;searchEdited=false;LattoMusic.search(query,20);root.forceActiveFocus();}
    function goBack(){if(musicSearch.activeFocus){root.forceActiveFocus();return true;}if(results.leaveKeyboard()){root.forceActiveFocus();return true;}return false;}
    onVisibleChanged:syncSearchHold()
    Component.onCompleted:musicSearch.text=LattoMusic.query
    Component.onDestruction:if(searchHeld)IslandState.release()
    Connections {target:LattoMusic;function onQueryChanged(){if(!root.searchEdited)musicSearch.text=LattoMusic.query;}}
    Shortcut {sequence:"Ctrl+F";context:Qt.WindowShortcut;enabled:root.visible;onActivated:root.focusSearch()}
    MusicPlayerCard {id:playerArea;anchors.top:parent.top;width:parent.width;hasPlayer:root.hasPlayer}
    Rectangle {
        id:searchBar;objectName:"youtubeMusicSearchBar"
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:playerArea.bottom;anchors.topMargin:10
        height:36;radius:12;color:Theme.surface;border.width:1;border.color:musicSearch.activeFocus?Theme.accent:Theme.border
        Icon {x:12;anchors.verticalCenter:parent.verticalCenter;name:"search";size:15;color:Theme.accent}
        TextInput {
            id:musicSearch;objectName:"youtubeMusicSearchInput"
            x:36;width:Math.max(1,clearSearch.x-x-5);height:parent.height
            color:Theme.text;selectionColor:Theme.accent;selectedTextColor:Theme.island
            font.family:Theme.fontFamily;font.pixelSize:Theme.fontSmall
            verticalAlignment:TextInput.AlignVCenter;selectByMouse:true;clip:true;maximumLength:500
            Accessible.name:"Search the music catalog"
            onActiveFocusChanged:root.syncSearchHold()
            onTextEdited:root.searchEdited=true
            onAccepted:root.searchMusic()
            Keys.onDownPressed:results.focusFirst()
            TextEntryFocus {}
            Label {anchors.fill:parent;verticalAlignment:Text.AlignVCenter;visible:musicSearch.text==="";text:"Search songs or artists…";font.pixelSize:Theme.fontSmall;color:Theme.textTertiary}
        }
        IslandButton {id:clearSearch;objectName:"musicClearSearch";anchors.right:searchButton.left;anchors.rightMargin:2;anchors.verticalCenter:parent.verticalCenter;width:25;height:28;icon:"close";iconSize:11;visible:musicSearch.text!=="";accessibleLabel:"Clear search";hint:"Clear search";onClicked:{root.searchEdited=true;musicSearch.text="";musicSearch.forceActiveFocus();}}
        IslandButton {
            id:searchButton;objectName:"youtubeMusicSearchButton"
            anchors.right:parent.right;anchors.rightMargin:4;anchors.verticalCenter:parent.verticalCenter
            width:82;height:28;text:LattoMusic.searching?"Finding…":"Search";fontSize:Theme.fontSmall;color:Theme.accent;subtle:true
            enabled:musicSearch.text.trim()!==""&&!LattoMusic.searching
            accessibleLabel:"Find songs to play in Latto";hint:"Enter searches · ↓ browses results";onClicked:root.searchMusic()
        }
    }
    MusicResults {id:results;anchors.top:searchBar.bottom;anchors.topMargin:6;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom}
}
