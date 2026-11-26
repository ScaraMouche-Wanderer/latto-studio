import QtQuick
import "../../services"
import "../../theme"
import ".."
import "../system" as Controls

Item {
    id:root
    property string page:""
    property string lastPage:""
    property bool searching:false
    property bool searchHeld:false
    function holdSearch(want){if(want&&!searchHeld){searchHeld=true;IslandState.holdOpen();}else if(!want&&searchHeld){searchHeld=false;IslandState.release();}}
    onSearchingChanged:if(!searching)holdSearch(false)
    property string query:""
    property string pending:""
    property string returnTile:""
    property bool held:false
    readonly property var destinations:[
                    {key:"apps",title:"Apps",detail:"Launch, media & app audio",icon:"grid",tint:Theme.accent,keywords:"applications launcher player mixer streams control"},
                    {key:"display",keywords:"brightness screen night light warmth scaling text",title:"Display",detail:"Screen & colour",icon:"display",tint:Theme.yellow},
                    {key:"sound",keywords:"volume speakers microphone mute output input headphones",title:"Sound",detail:"Volume & mic",icon:"volume",tint:Theme.accent},
                    {key:"power",keywords:"battery sleep keep awake profiles blanking",title:"Power",detail:"Battery & sleep",icon:"bolt",tint:Theme.green},
                    {key:"wifi",title:"Wi-Fi",detail:"Networks",icon:"wifi",tint:Theme.blue},
                    {key:"bluetooth",title:"Bluetooth",detail:"Nearby devices",icon:"bluetooth",tint:Theme.cyan},
                    {key:"notifications",title:"Notifications",detail:"Do Not Disturb",icon:"bell",tint:Theme.orange},
                    {key:"system",title:"About",detail:"Uptime & storage",icon:"info",tint:Theme.textSecondary},
                    {key:"profiles",title:"Profiles",detail:"Saved setups",icon:"settings",tint:Theme.accent,keywords:"profile saved collection"},
                    {key:"studio",keywords:"appearance palette colours colors corners animation motion profiles",title:"Customize",detail:"Colours & shape",icon:"settings",tint:Theme.accent}
                ]
    readonly property var filteredDestinations:destinations.filter(entry=>(!["profiles","apps"].includes(entry.key)||query.trim()!=="")&&(entry.title+" "+entry.detail+" "+(entry.keywords||"")).toLowerCase().includes(query.trim().toLowerCase()))
    function openSearch(){navigate("");searching=true;Qt.callLater(function(){searchInput.forceActiveFocus();searchInput.selectAll();});}
    function goBack(){
        if(page!==""){if(panel.item&&panel.item.askingFor){panel.item.closePassword();return true;}navigate("");return true;}
        if(pending!==""){pending="";return true;}
        if(searching){searching=false;query="";focusHomeTile();return true;}
        return false;
    }
    readonly property var info:SystemControls.data.system||({})
    readonly property var routes:({display:displayPage,sound:soundPage,power:powerPage,wifi:wifiPage,bluetooth:bluetoothPage,notifications:notificationsPage,system:aboutPage,studio:customizePage,profiles:profilesPage,apps:appsPage})
    Component { id:appsPage; Controls.AppsPage {} }
    Component { id:displayPage; Controls.DisplayPage {} }
    Component { id:soundPage; Controls.SoundPage {} }
    Component { id:powerPage; Controls.PowerPage {} }
    Component { id:wifiPage; WifiList {} }
    Component { id:bluetoothPage; BluetoothList {} }
    Component { id:notificationsPage; Controls.NotificationsPage {} }
    Component { id:aboutPage; Controls.AboutPage {} }
    Component { id:profilesPage; Controls.ProfilesPage {} }
    Component { id:customizePage; Controls.CustomizePage {} }
    // Width is a stable page preference; height follows the actual controls.
    readonly property real preferredIslandWidth:({display:580,sound:620,power:600,wifi:620,bluetooth:600,notifications:560,system:540,studio:600,apps:620})[page]||Theme.expandedWidth
    readonly property real preferredPageHeight:page===""?194:Math.max(194,panel.item&&panel.item.implicitHeight>0?Math.ceil(panel.item.implicitHeight):304)
    onPendingChanged:{
        if(pending!==""&&!held){IslandState.holdOpen();held=true;}
        else if(pending===""&&held){IslandState.release();held=false;}
    }
    function resetNavigation(){
        if(panel.item&&typeof panel.item.closePassword==="function")panel.item.closePassword();
        pending="";page="";lastPage="";searching=false;query="";
    }
    onVisibleChanged:if(!visible)resetNavigation()
    Component.onCompleted:SystemControls.watch()
    Component.onDestruction:{SystemControls.unwatch();holdSearch(false);if(held)IslandState.release();}
    function focusHomeTile(){
        if(!visible||page!=="")return;
        for(let i=0;i<homeTiles.count;i++){
            const tile=homeTiles.itemAt(i);
            if(tile&&tile.modelData.key===returnTile){tile.forceActiveFocus();return;}
        }
        root.forceActiveFocus();
    }
    function navigate(name){
        if(name!==""&&!Object.prototype.hasOwnProperty.call(routes,name))return;
        const previous=page;
        if(name!==""){lastPage=name;returnTile=name;searching=false;query="";}
        pending="";page=name;
        if(name===""&&previous!=="")Qt.callLater(focusHomeTile);
    }
    Shortcut { sequence:"Alt+Left";context:Qt.WindowShortcut;enabled:root.visible&&root.page!=="";onActivated:root.navigate("") }
    function timeText(hours){if(hours==null)return "Estimate unavailable";const minutes=Math.round(hours*60);return Math.floor(minutes/60)+"h "+minutes%60+"m estimated";}
    function uptimeText(seconds){if(seconds==null)return "Uptime unavailable";const days=Math.floor(seconds/86400);return "Up "+(days>0?days+"d ":"")+Math.floor(seconds/3600)%24+"h "+Math.floor(seconds/60)%60+"m";}
    Keys.onEscapePressed:event=>{event.accepted=goBack();}

    Swappable {
        objectName:"systemHomeTransition"
        anchors.fill:parent
        travel:-Theme.pageTravel
        shown:root.page===""||panel.item===null
        onVisibleChanged:if(visible&&root.page==="")Qt.callLater(root.focusHomeTile)
    Column {
        id:home
        objectName:"systemContent"
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
        spacing:8
        height:implicitHeight
        Item {
            width:parent.width;height:36
            visible:!root.searching
            Rectangle { x:0;y:3;width:30;height:30;radius:10;color:Qt.rgba(Theme.green.r,Theme.green.g,Theme.green.b,.12)
                Icon { anchors.centerIn:parent;name:Battery.charging?"bolt":"battery";size:17;color:Theme.green }
            }
            Label { x:40;y:0;text:"System";font.pixelSize:Theme.fontBody;font.weight:Font.DemiBold }
            Label { x:40;y:20;width:parent.width-215;text:SystemControls.error||((Battery.available?Battery.percent+"% battery · ":"")+root.uptimeText(root.info.uptimeSeconds));font.pixelSize:Theme.fontCaption;color:SystemControls.error!==""?Theme.orange:Theme.textSecondary;elide:Text.ElideRight }
            Controls.ControlButton { objectName:"openAppsHub";anchors.right:parent.right;anchors.rightMargin:38;anchors.verticalCenter:parent.verticalCenter;width:82;height:30;text:"Apps";icon:"grid";onClicked:root.navigate("apps") }
            IslandButton { anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:30;height:30;icon:"search";iconSize:14;accessibleLabel:"Find a System control";hint:"Search";onClicked:root.openSearch() }
        }
        Item {
            width:parent.width;height:36;visible:root.searching
            Rectangle {anchors.fill:parent;radius:10;color:Theme.surface;border.color:Theme.accent;border.width:1}
            Icon {x:10;anchors.verticalCenter:parent.verticalCenter;name:"search";size:15;color:Theme.accent}
            TextInput {
                onActiveFocusChanged:root.holdSearch(activeFocus&&root.searching)
                id:searchInput;objectName:"systemSearchInput";x:34;width:parent.width-70;height:parent.height
                verticalAlignment:TextInput.AlignVCenter;color:Theme.text;font.family:Theme.fontFamily;font.pixelSize:Theme.fontBody
                text:root.query;onTextEdited:root.query=text;selectByMouse:true;clip:true
                TextEntryFocus {}
                Keys.onReturnPressed:if(root.query.trim().toLowerCase().includes("profile"))root.navigate("profiles");else if(root.filteredDestinations.length)root.navigate(root.filteredDestinations[0].key)
                Label {anchors.fill:parent;verticalAlignment:Text.AlignVCenter;text:"Find a control…";color:Theme.textTertiary;visible:searchInput.text==="";font.pixelSize:Theme.fontSmall}
            }
            IslandButton {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:30;height:30;icon:"close";iconSize:14;accessibleLabel:"Close search";onClicked:{root.searching=false;root.query="";root.focusHomeTile();}}
        }
        Grid {
            width:parent.width;height:110;columns:4;spacing:6
            onWidthChanged:Qt.callLater(forceLayout)
            Repeater {
                id:homeTiles
                model:root.filteredDestinations
                Rectangle {
                    id:tile
                    objectName:"systemButton"
                    required property var modelData
                    width:(root.width-18)/4;height:52;radius:12
                    function activate(){tileFeedback.play();root.navigate(modelData.key);}
                    scale:tileMouse.pressed&&Theme.motionFactor>0?.97:1
                    Behavior on scale {NumberAnimation {duration:Theme.pressDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.springCurve}}
                    color:hover.hovered?Theme.surfaceRaised:Theme.surface
                    border.color:activeFocus?modelData.tint:Theme.border;border.width:1
                    activeFocusOnTab:true
                    Accessible.role:Accessible.Button
                    Accessible.name:modelData.title
                    Keys.onSpacePressed:activate()
                    Keys.onReturnPressed:activate()
                    Behavior on color { ColorAnimation {duration:Theme.fadeDuration} }
                    TapFeedback {id:tileFeedback;anchors.fill:parent;radius:tile.radius;tint:tile.modelData.tint}
                    Rectangle { x:9;y:14;width:25;height:25;radius:8;color:Qt.rgba(tile.modelData.tint.r,tile.modelData.tint.g,tile.modelData.tint.b,.13)
                        Icon { anchors.centerIn:parent;name:tile.modelData.icon;size:16;color:tile.modelData.tint }
                    }
                    Label { x:42;y:10;width:parent.width-49;text:tile.modelData.title;font.pixelSize:Theme.fontSmall;font.weight:Font.Medium;elide:Text.ElideRight }
                    Label { x:42;y:29;width:parent.width-49;text:tile.modelData.key==="bluetooth"?Bluetooth.statusLabel:tile.modelData.detail;font.pixelSize:Theme.fontCaption;color:Theme.textTertiary;elide:Text.ElideRight }
                    HoverHandler { id:hover }
                    MouseArea { id:tileMouse;anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:tile.activate() }
                }
            }
        }
        Row {
            width:parent.width;spacing:4;visible:root.pending===""
            onWidthChanged:Qt.callLater(forceLayout)
            Repeater {
                model:[{key:"lock",label:"Lock",icon:"lock"},{key:"suspend",label:"Sleep",icon:"moon"},{key:"logout",label:"Log out",icon:"logout"},{key:"restart",label:"Restart",icon:"refresh"},{key:"shutdown",label:"Shut down",icon:"power"}]
                Controls.ControlButton {
                    objectName:"systemButton"
                    required property var modelData
                    width:(root.width-16)/5;height:28
                    text:modelData.label;icon:modelData.icon;tint:modelData.key==="shutdown"?Theme.red:Theme.textSecondary
                    onClicked:{if(modelData.key==="lock")SystemControls.run("lock");else root.pending=modelData.key;}
                }
            }
        }
        Item {
            width:parent.width;height:28;visible:root.pending!==""
            Label { anchors.left:parent.left;anchors.right:cancel.left;anchors.rightMargin:8;height:parent.height;verticalAlignment:Text.AlignVCenter;text:({suspend:"Put the system to sleep?",logout:"Log out of this session?",restart:"Restart the system?",shutdown:"Shut down the system?"})[root.pending]||"";font.pixelSize:Theme.fontSmall;elide:Text.ElideRight }
            Controls.ControlButton { id:cancel;anchors.right:confirm.left;anchors.rightMargin:4;width:72;height:28;text:"Cancel";onClicked:root.pending="" }
            Controls.ControlButton { id:confirm;anchors.right:parent.right;width:72;height:28;text:"Confirm";tint:Theme.red;enabled:!SystemControls.busy;onClicked:{const action=root.pending;root.pending="";SystemControls.run(action);} }
        }
    }
    }
    Label {anchors.horizontalCenter:parent.horizontalCenter;y:90;visible:root.page===""&&root.searching&&root.filteredDestinations.length===0;text:"No matching controls";font.pixelSize:Theme.fontSmall;color:Theme.textSecondary}
    PageHost {
        id:panel
        objectName:"systemPanelLoader"
        anchors.fill:parent
        // Keep the outgoing controls alive through Back, then release their
        // watchers and focus holds when the visual exit actually finishes.
        active:root.page!==""||opacity>.001
        sourceComponent:root.routes[root.page||root.lastPage]||null
        opacity:root.page!==""&&item!==null?1:0
        enabled:root.page!==""
        transform:Translate {x:Theme.motionFactor>0&&root.page===""?Theme.pageTravel:0;Behavior on x {NumberAnimation {duration:Theme.pageDuration;easing.type:Easing.BezierSpline;easing.bezierCurve:Theme.smoothCurve}}}
        Behavior on opacity {NumberAnimation {duration:Theme.pageDuration;easing.type:Easing.OutCubic}}
        onLoaded:if(item)item.forceActiveFocus();
    }
    Column {
        objectName:"systemPageError"
        anchors.centerIn:parent
        width:Math.min(parent.width,360)
        spacing:10
        visible:panel.status===Loader.Error
        Label { width:parent.width;text:"This settings page could not load.";wrapMode:Text.Wrap;font.pixelSize:Theme.fontBody;color:Theme.orange }
        Label { width:parent.width;text:"Return to System and try again.";wrapMode:Text.Wrap;font.pixelSize:Theme.fontSmall;color:Theme.textSecondary }
        Controls.ControlButton { text:"Back to System";icon:"chevronLeft";onClicked:root.navigate("") }
    }
    Connections { target:panel.item;ignoreUnknownSignals:true;function onBack(){root.navigate("");} function onRequestPage(name){root.navigate(name);} }
}
