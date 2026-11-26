import QtQuick
import "../services"
import "../theme"

Item {
    id:root
    objectName:"musicCatalog"
    readonly property bool loading:LattoMusic.phase==="loading"
    readonly property bool hideExplicit:LattoMusic.cleanOnly
    readonly property string sortMode:LattoMusic.resultSort
    property bool keyboardBrowsing:false
    property bool held:false
    property real savedOffset:0
    property bool restoreOffset:false
    readonly property var rows: {
        const rows=LattoMusic.results.filter(track=>!hideExplicit||!track.explicit);
        if(sortMode==="title")rows.sort((a,b)=>a.title.localeCompare(b.title));
        else if(sortMode==="artist")rows.sort((a,b)=>a.artist.localeCompare(b.artist)||a.title.localeCompare(b.title));
        else if(sortMode==="duration")rows.sort((a,b)=>(a.duration||Infinity)-(b.duration||Infinity));
        return rows;
    }
    function syncHold(){const want=visible&&keyboardBrowsing;if(want===held)return;held=want;if(want)IslandState.holdOpen();else IslandState.release();}
    function focusFirst(){if(!list.count)return;keyboardBrowsing=true;syncHold();list.currentIndex=Math.max(0,list.currentIndex);list.forceActiveFocus();list.positionViewAtIndex(list.currentIndex,ListView.Contain);}
    function leaveKeyboard(){if(!keyboardBrowsing)return false;keyboardBrowsing=false;syncHold();return true;}
    function cycleSort(){const modes=["match","title","artist","duration"];LattoMusic.resultSort=modes[(modes.indexOf(sortMode)+1)%modes.length];}
    onVisibleChanged:if(!visible)leaveKeyboard()
    Component.onDestruction:if(held)IslandState.release()
    Connections {target:LattoMusic;function onCatalogAboutToChange(append){root.savedOffset=append?list.contentY:0;root.restoreOffset=append;}}
    Item {
        id:header;width:parent.width;height:36
        Label {x:2;anchors.verticalCenter:parent.verticalCenter;width:Math.max(40,parent.width-261);elide:Text.ElideRight;wrapMode:Text.Wrap;maximumLineCount:2;font.pixelSize:Theme.fontCaption;color:LattoMusic.error?Theme.orange:Theme.textTertiary;text:LattoMusic.error||(LattoMusic.searching?"Searching the catalog…":root.loading?"Getting your track ready…":LattoMusic.results.length?(root.rows.length===LattoMusic.results.length?root.rows.length+" songs":root.rows.length+" of "+LattoMusic.results.length+" songs"):"↑↓ browse · Enter play · Ctrl+F search")}
        Row {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:4
            IslandButton {objectName:"musicCleanFilter";width:52;height:26;text:"Clean";fontSize:Theme.fontCaption;subtle:root.hideExplicit;color:root.hideExplicit?Theme.accent:Theme.textTertiary;accessibleLabel:root.hideExplicit?"Show explicit tracks":"Hide explicit tracks";hint:"Hide tracks marked explicit";onClicked:{root.leaveKeyboard();LattoMusic.cleanOnly=!root.hideExplicit;}}
            IslandButton {objectName:"musicSortButton";width:101;height:26;text:"Sort: "+({match:"Match",title:"Title",artist:"Artist",duration:"Length"})[root.sortMode];fontSize:Theme.fontCaption;color:Theme.textSecondary;hint:"Cycle: relevance, title, artist, length";onClicked:{root.leaveKeyboard();root.cycleSort();}}
            IslandButton {objectName:"musicMoreButton";width:88;height:26;visible:LattoMusic.error!==""||LattoMusic.state.hasMore===true;text:LattoMusic.error?(LattoMusic.ready?"Retry search":"Reconnect"):"More";icon:LattoMusic.error?"refresh":"";iconSize:11;fontSize:Theme.fontCaption;enabled:!LattoMusic.searching;color:LattoMusic.error?Theme.orange:Theme.accent;onClicked:{root.leaveKeyboard();if(LattoMusic.error)LattoMusic.retry();else LattoMusic.more();}}
        }
    }
    ListView {
        id:list;objectName:"musicResultsList"
        anchors.top:header.bottom;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
        clip:true;spacing:5;boundsBehavior:Flickable.StopAtBounds;model:root.rows
        keyNavigationEnabled:true
        onActiveFocusChanged:if(!activeFocus)root.leaveKeyboard()
        Keys.onReturnPressed:if(currentItem)currentItem.activate()
        Keys.onSpacePressed:if(currentItem)currentItem.activate()
        onModelChanged:{if(root.restoreOffset)Qt.callLater(function(){list.contentY=Math.min(root.savedOffset,Math.max(0,list.contentHeight-list.height));root.restoreOffset=false;});else positionViewAtBeginning();}
        delegate:Rectangle {
            id:row
            required property var modelData
            width:list.width-5;height:52;radius:11
            readonly property bool current:!!LattoMusic.state.track&&LattoMusic.state.track.id===modelData.id
            readonly property bool busy:current&&root.loading
            function activate(fromPointer){if(!busy){rowFeedback.play();if(fromPointer)root.leaveKeyboard();LattoMusic.activate(modelData.id);}}
            scale:rowMouse.pressed&&Theme.motionFactor>0?.988:1
            Behavior on scale {NumberAnimation {duration:Theme.pressDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.springCurve}}
            color:hover.hovered?Theme.surfaceRaised:Theme.surface
            border.width:1;border.color:activeFocus||(ListView.isCurrentItem&&list.activeFocus)?Theme.accent:current?Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.4):Theme.border
            Behavior on color {ColorAnimation {duration:Theme.fadeDuration}}
            Behavior on border.color {ColorAnimation {duration:Theme.fadeDuration}}
            TapFeedback {id:rowFeedback;anchors.fill:parent;radius:row.radius}
            activeFocusOnTab:true
            Accessible.role:Accessible.Button;Accessible.name:(row.current&&LattoMusic.phase==="playing"?"Pause ":"Play ")+modelData.title+" by "+modelData.artist
            Keys.onReturnPressed:activate()
            Keys.onSpacePressed:activate()
            Rectangle {x:9;y:10;width:31;height:31;radius:9;color:Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.12);AnimatedIcon {anchors.centerIn:parent;size:15;name:row.busy?"music":row.current&&LattoMusic.phase==="playing"?"pause":"play";color:Theme.accent}}
            Label {x:50;y:8;width:Math.max(1,parent.width-121);text:row.modelData.title;elide:Text.ElideRight;font.pixelSize:Theme.fontSmall;font.weight:Font.Medium;textFormat:Text.PlainText}
            Label {x:50;y:29;width:Math.max(1,parent.width-121);text:row.modelData.artist+(row.modelData.album?" · "+row.modelData.album:"")+(row.modelData.explicit?" · E":"");elide:Text.ElideRight;font.pixelSize:Theme.fontCaption;color:Theme.textTertiary;textFormat:Text.PlainText}
            Label {anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;text:row.busy?"Loading":row.current&&LattoMusic.phase==="playing"?"Playing":row.modelData.durationText;font.pixelSize:Theme.fontCaption;color:row.current?Theme.accent:Theme.textTertiary}
            HoverHandler {id:hover}
            MouseArea {id:rowMouse;anchors.fill:parent;enabled:!row.busy;cursorShape:Qt.PointingHandCursor;onClicked:{row.forceActiveFocus();row.activate(true);}}
        }
        Column {
            anchors.centerIn:parent;width:parent.width-42;spacing:6;visible:list.count===0
            Label {width:parent.width;text:LattoMusic.searching?"Finding your music…":LattoMusic.error?"Let's try that again":root.hideExplicit&&LattoMusic.results.length?"No clean matches in these results":LattoMusic.query!==""?"No matching songs":"Your music, without another window.";horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;font.pixelSize:Theme.fontSmall;color:Theme.textSecondary}
            Label {width:parent.width;text:root.hideExplicit&&LattoMusic.results.length?"Turn off Clean or load more results.":"Try a song title, artist, or a more specific search.";visible:!LattoMusic.searching;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;font.pixelSize:Theme.fontCaption;color:Theme.textTertiary}
        }
    }
    Rectangle {x:parent.width-3;y:list.y+(list.height-height)*list.visibleArea.yPosition/Math.max(.001,1-list.visibleArea.heightRatio);width:3;height:Math.max(14,list.height*list.visibleArea.heightRatio);radius:1.5;color:Theme.textTertiary;visible:list.contentHeight>list.height}
}
