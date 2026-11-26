import QtQuick
import Quickshell
import "../../services"
import "../../theme"
import ".."

Item {
    id:root
    property bool importantOnly:false
    property bool confirmingClear:false
    readonly property var entries:NotificationInbox.history.filter(item=>!importantOnly||item.urgency===2)
    property bool watching:false
    readonly property bool inboxVisible:visible&&!Settings.notificationsEnabled
    function syncView(){if(watching===inboxVisible)return;watching=inboxVisible;if(watching)NotificationInbox.watchView();else NotificationInbox.unwatchView();}
    onInboxVisibleChanged:syncView()
    Component.onCompleted:syncView()
    Component.onDestruction:if(watching)NotificationInbox.unwatchView()
    function resetNavigation() {
        confirmingClear = false;
        importantOnly = false;
        resetClear.stop();
        list.positionViewAtBeginning();
    }
    function goBack(){if(confirmingClear){confirmingClear=false;return true;}if(importantOnly){importantOnly=false;return true;}return false;}
    SystemClock {id:clock;precision:SystemClock.Minutes}
    Loader {anchors.fill:parent;active:Settings.notificationsEnabled;source:active?"LegacyNotificationsTab.qml":""}
    Item {
        anchors.fill:parent;visible:!Settings.notificationsEnabled
        Item {
            id:header;width:parent.width;height:36
            Rectangle {width:32;height:32;y:2;radius:11;color:Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.12);Icon {anchors.centerIn:parent;name:"bell";size:17;color:Theme.accent}}
            Label {x:43;y:0;text:"Notifications";font.pixelSize:Theme.fontBody;font.weight:Font.DemiBold}
            Label {x:43;y:21;text:NotificationInbox.locked&&NotificationInbox.ready?"Hidden while locked":NotificationInbox.count>0?NotificationInbox.count+" in your center":"A little room for what matters";font.pixelSize:Theme.fontCaption;color:Theme.textTertiary}
            IslandButton {objectName:"inboxDndButton";anchors.right:parent.right;y:3;height:30;width:128;icon:"moon";iconSize:13;text:Notifications.doNotDisturb?"Quiet mode on":"Quiet mode";fontSize:Theme.fontSmall;subtle:true;color:Notifications.doNotDisturb?Theme.accent:Theme.textSecondary;enabled:Notifications.canSetDoNotDisturb;accessibleLabel:"Toggle desktop Do Not Disturb";Accessible.role:Accessible.CheckBox;Accessible.checked:Notifications.doNotDisturb;onClicked:Notifications.toggleDoNotDisturb()}
        }
        Rectangle {
            id:filters;y:46;width:parent.width;height:32;radius:10;color:Theme.surface
            Row {x:3;y:3;spacing:3
                IslandButton {width:64;height:26;text:"All";Accessible.role:Accessible.RadioButton;Accessible.checked:!root.importantOnly;fontSize:Theme.fontSmall;subtle:!root.importantOnly;color:!root.importantOnly?Theme.accent:Theme.textTertiary;onClicked:root.importantOnly=false}
                IslandButton {width:90;height:26;text:"Important";Accessible.role:Accessible.RadioButton;Accessible.checked:root.importantOnly;fontSize:Theme.fontSmall;subtle:root.importantOnly;color:root.importantOnly?Theme.accent:Theme.textTertiary;onClicked:root.importantOnly=true}
            }
            IslandButton {objectName:"clearInboxButton";anchors.right:parent.right;anchors.rightMargin:3;y:3;height:26;width:root.confirmingClear?110:80;text:root.confirmingClear?"Confirm clear":"Clear all";fontSize:Theme.fontSmall;color:root.confirmingClear?Theme.orange:Theme.textTertiary;enabled:NotificationInbox.count>0;onClicked:{if(root.confirmingClear){NotificationInbox.clearAll();root.confirmingClear=false;}else{root.confirmingClear=true;resetClear.restart();}}}
        }
        Timer {id:resetClear;interval:4000;onTriggered:root.confirmingClear=false}
        ListView {
            id:list;objectName:"notificationInboxList"
            y:88;width:parent.width;height:Math.max(1,parent.height-y-25)
            model:root.entries;spacing:8;clip:true;boundsBehavior:Flickable.StopAtBounds
            delegate:InboxCard {required property var modelData;width:list.width-5;notification:modelData;now:clock.date.getTime()}
            add:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:Theme.pageDuration}}
            displaced:Transition {NumberAnimation {properties:"x,y";duration:Theme.pageDuration;easing.type:Easing.OutCubic}}
        }
        Rectangle {x:parent.width-3;y:list.y+(list.height-height)*list.visibleArea.yPosition/Math.max(.001,1-list.visibleArea.heightRatio);width:3;height:Math.max(14,list.height*list.visibleArea.heightRatio);radius:1.5;color:Theme.textTertiary;visible:list.contentHeight>list.height}
        Column {
            anchors.centerIn:list;width:Math.min(340,parent.width-40);spacing:9;visible:list.count===0
            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;width:54;height:54;radius:18;color:Theme.surface;Icon {anchors.centerIn:parent;name:NotificationInbox.doNotDisturb?"moon":"bell";size:24;color:Theme.accent}}
            Label {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:!NotificationInbox.ready?"Connecting to your desktop…":NotificationInbox.locked?"Notifications are private":"You're all caught up";font.pixelSize:Theme.fontBody;font.weight:Font.Medium}
            Label {width:parent.width;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap;text:NotificationInbox.locked&&NotificationInbox.ready?"Unlock your session to view this center.":root.importantOnly?"Important notifications will appear here.":"New desktop notifications collect here while Latto is running.";font.pixelSize:Theme.fontSmall;color:Theme.textTertiary}
        }
        Label {anchors.bottom:parent.bottom;width:parent.width;height:17;text:NotificationInbox.error||"On this device · history clears when Latto restarts";font.pixelSize:Theme.fontCaption;color:NotificationInbox.error?Theme.orange:Theme.textTertiary;elide:Text.ElideRight}
    }
}
