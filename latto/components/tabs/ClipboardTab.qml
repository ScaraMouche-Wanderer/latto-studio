import QtQuick
import QtQuick.Controls as QQC
import "../../services"
import "../../theme"
import ".."

// Local clipboard history using the island's shared surfaces and controls.
Item {
    id: root
    property string filter: "all"
    property bool confirmClear: false
    property bool searchHeld: false
    property bool listHeld: false
    property string selectedId: ""
    property bool syncing: false
    function syncItems() {
        if(syncing)return;
        syncing=true;
        const selected=list.currentIndex>=0&&list.currentIndex<history.count?history.get(list.currentIndex).payload.id:selectedId;
        const oldIndex=list.currentIndex;
        const anchorIndex=list.contentY>2?list.indexAt(1,list.contentY+2):-1;
        const anchorId=anchorIndex>=0&&anchorIndex<history.count?history.get(anchorIndex).payload.id:"";
        const anchorItem=anchorIndex>=0?list.itemAtIndex(anchorIndex):null;
        const offset=anchorItem?list.contentY-anchorItem.y:0;
        const incoming=Clipboard.items;
        for(let i=0;i<incoming.length;i++){
            let found=-1;
            for(let j=i;j<history.count;j++)if(history.get(j).payload.id===incoming[i].id){found=j;break;}
            if(found<0)history.insert(i,{payload:incoming[i]});
            else {
                if(found!==i)history.move(found,i,1);
                if(JSON.stringify(history.get(i).payload)!==JSON.stringify(incoming[i]))history.setProperty(i,"payload",incoming[i]);
            }
        }
        while(history.count>incoming.length)history.remove(history.count-1);
        let current=-1,anchor=-1;
        for(let i=0;i<history.count;i++){
            const id=history.get(i).payload.id;
            if(id===selected)current=i;
            if(id===anchorId)anchor=i;
        }
        list.currentIndex=selected?(current>=0?current:Math.min(oldIndex,history.count-1)):-1;
        selectedId=list.currentIndex>=0?history.get(list.currentIndex).payload.id:"";
        list.forceLayout();
        if(anchor>=0){
            list.positionViewAtIndex(anchor,ListView.Beginning);
            const item=list.itemAtIndex(anchor);
            if(item)list.contentY=Math.max(list.originY,Math.min(item.y+offset,list.originY+list.contentHeight-list.height));
        }
        syncing=false;
    }
    ListModel {id:history;dynamicRoles:true}
    Connections {target:Clipboard;function onItemsChanged(){root.syncItems();}}
    function goBack() {
        if(confirmClear){confirmClear=false;return true;}
        if(search.activeFocus){search.focus=false;return true;}
        if(list.activeFocus){list.focus=false;return true;}
        return false;
    }
    function updateSearch(){selectedId="";list.currentIndex=-1;Clipboard.search(search.text,filter);list.positionViewAtBeginning();}
    function bytes(value){return value===0?"0 KB":value>=1048576?(value/1048576).toFixed(1)+" MB":Math.max(1,Math.round(value/1024))+" KB";}
    function kindLabel(kind){return ({text:"Text",link:"Link",image:"Image",file:"File"})[kind]||"Clipboard item";}
    onConfirmClearChanged: {if(confirmClear)IslandState.holdOpen();else IslandState.release();}
    Component.onDestruction: {if(confirmClear)IslandState.release();if(searchHeld)IslandState.release();if(listHeld)IslandState.release();}
    Component.onCompleted: {filter=Clipboard.kind;search.text=Clipboard.query;root.syncItems();}
    Shortcut {sequence:"Ctrl+F";enabled:root.visible;onActivated:{search.forceActiveFocus();search.selectAll();}}
    Timer {id:debounce;interval:160;onTriggered:root.updateSearch()}

    Item {
        id:header
        anchors.top:parent.top
        width:parent.width;height:36
        Rectangle {
            width:32;height:32;y:2;radius:11
            color:Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.12)
            Icon {anchors.centerIn:parent;name:"clipboard";size:17;color:Theme.accent}
        }
        Label {x:43;y:0;text:"Clipboard";font.pixelSize:Theme.fontBody;font.weight:Font.DemiBold}
        Label {
            x:43;y:21;width:Math.max(0,privateMode.x-x-12)
            text:Clipboard.ready&&Clipboard.locked?"Hidden while locked":Clipboard.paused?"New copies aren’t being saved":Clipboard.count+" of "+Clipboard.limit+" saved copies"
            font.pixelSize:Theme.fontCaption;color:Theme.textTertiary;elide:Text.ElideRight
        }
        IslandButton {
            id:privateMode;objectName:"clipboardPause"
            anchors.right:parent.right;y:3;width:128;height:30
            icon:"lock";iconSize:13;text:Clipboard.paused?"Private mode on":"Private mode"
            fontSize:Theme.fontSmall;subtle:true
            color:Clipboard.paused?Theme.accent:Theme.textSecondary
            enabled:Clipboard.ready&&!Clipboard.locked
            Accessible.role:Accessible.CheckBox
            Accessible.checked:Clipboard.paused
            accessibleLabel:"Toggle clipboard private mode"
            hint:Clipboard.paused?"Resume saving new copies":"Pause saving new copies"
            onClicked:Clipboard.togglePause()
        }
    }

    Rectangle {
        id:searchBar;objectName:"clipboardSearchBar"
        anchors.top:header.bottom;anchors.topMargin:10
        width:parent.width;height:36;radius:12;color:Theme.surface
        border.width:1;border.color:search.activeFocus?Theme.accent:Theme.border
        Behavior on border.color {ColorAnimation {duration:Theme.fadeDuration}}
        Icon {x:12;anchors.verticalCenter:parent.verticalCenter;name:"search";size:15;color:search.activeFocus?Theme.accent:Theme.textTertiary}
        TextInput {
            id:search;objectName:"clipboardSearch";x:36;anchors.verticalCenter:parent.verticalCenter;width:parent.width-71;clip:true;color:Theme.text;font.family:Theme.fontFamily;font.pixelSize:Theme.fontSmall;selectByMouse:true;selectionColor:Theme.accent;selectedTextColor:Theme.island;maximumLength:200
            Accessible.name:"Search clipboard history"
            enabled:Clipboard.ready&&!Clipboard.locked
            onTextEdited:debounce.restart()
            onActiveFocusChanged:{if(activeFocus&&!root.searchHeld){root.searchHeld=true;IslandState.holdOpen();}else if(!activeFocus&&root.searchHeld){root.searchHeld=false;IslandState.release();}}
            Keys.onDownPressed:{focus=false;list.forceActiveFocus();if(list.count)list.currentIndex=0;}
            TextEntryFocus {}
            Label {visible:!search.text&&!search.activeFocus;text:"Search clipboard…";font.pixelSize:Theme.fontSmall;color:Theme.textTertiary}
        }
        IslandButton {anchors.right:parent.right;anchors.rightMargin:4;anchors.verticalCenter:parent.verticalCenter;width:28;height:28;icon:"close";iconSize:13;visible:search.text.length>0;accessibleLabel:"Clear clipboard search";onClicked:{search.text="";root.updateSearch();}}
    }
    Rectangle {
        id:filters
        anchors.top:searchBar.bottom;anchors.topMargin:8
        width:parent.width;height:32;radius:10;color:Theme.surface
        Row {
            x:3;y:3;spacing:3
            Repeater {
                model:[{id:"all",label:"All"},{id:"text",label:"Text"},{id:"link",label:"Links"},{id:"image",label:"Images"},{id:"file",label:"Files"}]
                IslandButton {
                    required property var modelData
                    objectName:"clipboardFilter"+modelData.id
                    width:Math.max(34,Math.min(64,(filters.width-clearHistory.width-18)/5));height:26
                    text:modelData.label;fontSize:Theme.fontSmall
                    subtle:root.filter===modelData.id
                    color:root.filter===modelData.id?Theme.accent:Theme.textTertiary
                    Accessible.role:Accessible.RadioButton
                    Accessible.checked:root.filter===modelData.id
                    onClicked:{root.filter=modelData.id;root.updateSearch();}
                }
            }
        }
        IslandButton {
            id:clearHistory;objectName:"clipboardClear"
            anchors.right:parent.right;anchors.rightMargin:3;y:3;width:88;height:26
            text:"Clear all";icon:"trash";iconSize:12;fontSize:Theme.fontSmall
            color:root.confirmClear?Theme.red:Theme.textTertiary
            enabled:Clipboard.ready&&!Clipboard.locked&&Clipboard.count>0
            accessibleLabel:"Clear saved clipboard history"
            onClicked:root.confirmClear=!root.confirmClear
        }
    }
    Rectangle {
        id:confirmation;objectName:"clipboardClearConfirmation"
        anchors.top:filters.bottom;anchors.topMargin:root.confirmClear?8:0
        width:parent.width;height:root.confirmClear?38:0;visible:root.confirmClear
        radius:12;color:Theme.surface;border.width:1;border.color:Theme.border
        Label {x:12;anchors.verticalCenter:parent.verticalCenter;text:"Clear saved history?";font.pixelSize:Theme.fontSmall;color:Theme.textSecondary}
        Row {anchors.right:parent.right;anchors.rightMargin:5;anchors.verticalCenter:parent.verticalCenter;spacing:4
            IslandButton {height:28;text:"Cancel";fontSize:Theme.fontCaption;onClicked:root.confirmClear=false}
            IslandButton {objectName:"clipboardConfirmClear";height:28;text:"Delete all";fontSize:Theme.fontCaption;color:Theme.red;subtle:true;onClicked:{Clipboard.clear();root.confirmClear=false;}}
        }
    }
    ListView {
        id:list;objectName:"clipboardHistoryList"
        anchors.top:confirmation.bottom;anchors.topMargin:8;anchors.bottom:footer.top;anchors.bottomMargin:8
        width:parent.width;clip:true;spacing:6;model:history;currentIndex:-1;boundsBehavior:Flickable.StopAtBounds
        onCurrentIndexChanged:if(!root.syncing)root.selectedId=currentIndex>=0&&currentIndex<history.count?history.get(currentIndex).payload.id:""
        add:Transition {enabled:list.contentY<=2;NumberAnimation {property:"opacity";from:0;to:1;duration:Theme.pageDuration}}
        move:Transition {enabled:list.contentY<=2;NumberAnimation {property:"y";duration:Theme.pageDuration;easing.type:Easing.OutCubic}}
        displaced:Transition {enabled:list.contentY<=2;NumberAnimation {property:"y";duration:Theme.pageDuration;easing.type:Easing.OutCubic}}
        onActiveFocusChanged:{if(activeFocus&&!root.listHeld){root.listHeld=true;IslandState.holdOpen();}else if(!activeFocus&&root.listHeld){root.listHeld=false;IslandState.release();}}
        Keys.onReturnPressed:if(currentItem)Clipboard.copy(currentItem.modelData.id)
        Keys.onSpacePressed:if(currentItem)Clipboard.copy(currentItem.modelData.id)
        delegate:Rectangle {
            id:entry;objectName:"clipboardHistoryRow";required property var payload;required property int index
            readonly property var modelData:payload
            readonly property bool copied:Clipboard.copiedId===modelData.id
            readonly property bool highlighted:list.activeFocus&&list.currentIndex===index
            width:ListView.view.width-6;height:54;radius:15
            color:rowHover.hovered||highlighted?Theme.surfaceRaised:Theme.surface
            border.width:1
            border.color:highlighted?Theme.accent:copied?Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.4):Theme.border
            Accessible.role:Accessible.Button
            Accessible.name:"Copy "+(modelData.text||"clipboard item")
            Accessible.description:metadata.text
            Behavior on color {ColorAnimation {duration:Theme.fadeDuration}}
            Behavior on border.color {ColorAnimation {duration:Theme.fadeDuration}}
            scale:rowMouse.pressed?.993:1
            Behavior on scale {NumberAnimation {duration:Theme.pressDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.springCurve}}
            HoverHandler {id:rowHover}
            MouseArea {id:rowMouse;anchors.fill:parent;enabled:!Clipboard.busyId;cursorShape:Qt.PointingHandCursor;onClicked:{list.currentIndex=entry.index;Clipboard.copy(entry.modelData.id);}}
            Rectangle {
                id:badge
                x:12;anchors.verticalCenter:parent.verticalCenter;width:32;height:32;radius:10
                color:Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.12)
                Image {id:thumbnail;anchors.fill:parent;anchors.margins:3;visible:entry.modelData.kind==="image"&&!entry.copied;source:entry.modelData.thumbnail||"";sourceSize.width:64;sourceSize.height:64;asynchronous:true;cache:false;fillMode:Image.PreserveAspectFit}
                Icon {anchors.centerIn:parent;visible:entry.copied||entry.modelData.kind!=="image"||thumbnail.status!==Image.Ready;name:entry.copied?"check":entry.modelData.kind==="image"?"image":entry.modelData.kind==="link"?"link":entry.modelData.kind==="file"?"file":"copy";size:16;color:Theme.accent}
            }
            Label {
                id:preview
                anchors.left:badge.right;anchors.leftMargin:10;anchors.right:deleteButton.left;anchors.rightMargin:6;y:8
                text:entry.modelData.text||"Clipboard item";font.pixelSize:Theme.fontBody;font.weight:Font.Medium
                elide:Text.ElideRight;textFormat:Text.PlainText
            }
            Label {
                id:metadata
                anchors.left:preview.left;anchors.right:preview.right;y:30
                text:Clipboard.busyId===entry.modelData.id?"Restoring…":entry.copied?"Copied · ready to paste":root.kindLabel(entry.modelData.kind)+" · "+root.bytes(entry.modelData.size)+(entry.modelData.mime==="text/uri-list"||entry.modelData.mime==="x-special/gnome-copied-files"?" · original required":"")
                font.pixelSize:Theme.fontCaption;color:entry.copied?Theme.accent:Theme.textTertiary
                elide:Text.ElideRight;textFormat:Text.PlainText
            }
            QQC.ToolTip {
                id:rowTip
                parent:entry;visible:rowHover.hovered&&!deleteButton.activeFocus&&!deleteHover.hovered;text:metadata.text;delay:700;timeout:2000
                contentItem:Label {text:rowTip.text;color:Theme.text;font.pixelSize:Theme.fontCaption}
                background:Rectangle {radius:8;color:Theme.surfaceRaised;border.width:1;border.color:Theme.border}
            }
            IslandButton {id:deleteButton;objectName:"clipboardDeleteItem";anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;width:28;height:28;opacity:rowHover.hovered||activeFocus||entry.highlighted?1:0;enabled:opacity>0;icon:"trash";iconSize:13;color:deleteHover.hovered?Theme.red:Theme.textTertiary;accessibleLabel:"Delete saved clipboard item";hint:"Remove from history";onClicked:Clipboard.remove(entry.modelData.id);HoverHandler {id:deleteHover}}
        }
        QQC.ScrollBar.vertical: QQC.ScrollBar {
            width:4;policy:QQC.ScrollBar.AsNeeded
            contentItem:Rectangle {implicitWidth:3;radius:1.5;color:Theme.textTertiary;opacity:parent.active?.7:.3}
            background:Item {}
        }
        Column {
            anchors.centerIn:parent;width:Math.min(340,parent.width-40);spacing:9;visible:!list.count
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;width:54;height:54;radius:18;color:Theme.surface;Icon {anchors.centerIn:parent;name:Clipboard.ready&&Clipboard.locked?"lock":"clipboard";size:24;color:Theme.accent}}
            Label {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:!Clipboard.enabled?"Clipboard history is off":!Clipboard.ready?"Connecting to clipboard…":Clipboard.locked?"Your copies are private":search.text||root.filter!=="all"?"No matching copies":Clipboard.paused?"Private mode is on":"Your clipboard is empty";font.pixelSize:Theme.fontBody;font.weight:Font.Medium}
            Label {width:parent.width;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;text:!Clipboard.enabled?"Enable clipboard history in Studio.":!Clipboard.ready?"Saved copies will appear here when connected.":Clipboard.locked?"Unlock your session to view your history.":search.text||root.filter!=="all"?"Try another search or choose a different type.":Clipboard.paused?"Turn off Private mode to save new copies.":"Copy text, links, images or files to keep them here.";font.pixelSize:Theme.fontSmall;color:Theme.textTertiary}
        }
    }
    Label {
        id:footer;objectName:"clipboardStatus";anchors.bottom:parent.bottom;width:parent.width;height:Clipboard.error?28:17;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;font.pixelSize:Theme.fontCaption;color:Clipboard.error?Theme.orange:Theme.textTertiary;text:Clipboard.error||(Clipboard.paused?"Private mode · new copies aren’t saved":"Saved on this device · kept after logout")
    }
}
