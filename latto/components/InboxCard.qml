import QtQuick
import Quickshell
import "../services"
import "../theme"

Rectangle {
    id: root
    required property var notification
    property real now: Date.now()
    property bool expanded: false
    readonly property bool critical: notification.urgency === 2
    readonly property var app: NotificationInbox.appFor(notification)
    readonly property string age: {
        const mins=Math.max(0,Math.floor((now-notification.at)/60000));
        return mins<1?"now":mins<60?mins+"m":mins<1440?Math.floor(mins/60)+"h":Math.floor(mins/1440)+"d";
    }
    implicitHeight: content.implicitHeight+24
    radius: 15; color: Theme.surface
    border.width: 1
    border.color: critical?Qt.rgba(Theme.orange.r,Theme.orange.g,Theme.orange.b,.4):Theme.border
    Rectangle {x:0;y:15;width:3;height:20;radius:1.5;color:root.critical?Theme.orange:Theme.accent;visible:root.notification.unread||root.critical}
    Rectangle {
        id:iconTile;x:12;y:13;width:32;height:32;radius:10
        color:Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,.13)
        Image {
            id:appIcon;anchors.centerIn:parent;width:22;height:22;sourceSize.width:44;sourceSize.height:44;fillMode:Image.PreserveAspectFit
            source: {
                const icon = root.app ? root.app.icon : String(root.notification.appIcon||"");
                if(!icon || icon.includes("://") || icon.startsWith("data:"))return "";
                return Quickshell.iconPath(icon,true);
            }
        }
        Icon {anchors.centerIn:parent;name:root.critical?"info":"bell";size:17;color:root.critical?Theme.orange:Theme.accent;visible:appIcon.status!==Image.Ready}
    }
    Column {
        id:content;x:54;y:12;width:parent.width-67;spacing:5
        Item {
            width:parent.width;height:19
            Label {width:parent.width-62;anchors.verticalCenter:parent.verticalCenter;text:(root.notification.appName||"Notification")+(root.critical?" · Important":"");font.pixelSize:Theme.fontCaption;font.weight:Font.Medium;color:root.critical?Theme.orange:Theme.textTertiary;elide:Text.ElideRight;textFormat:Text.PlainText}
            Label {anchors.right:close.left;anchors.rightMargin:6;anchors.verticalCenter:parent.verticalCenter;text:root.age;font.pixelSize:Theme.fontCaption;color:Theme.textTertiary}
            IslandButton {id:close;objectName:"dismissInboxNotification";anchors.right:parent.right;width:22;height:20;icon:"close";iconSize:10;accessibleLabel:"Dismiss notification";hint:"Dismiss";onClicked:NotificationInbox.dismiss(root.notification)}
        }
        Label {width:parent.width;text:root.notification.summary;font.pixelSize:Theme.fontBody;font.weight:Font.DemiBold;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;textFormat:Text.PlainText}
        Label {
            id:body;width:parent.width;visible:text!=="";text:Notifications.plainText(root.notification.body)
            color:Theme.textSecondary;font.pixelSize:Theme.fontSmall;wrapMode:Text.Wrap
            maximumLineCount:root.expanded?100:3;elide:Text.ElideRight;textFormat:Text.PlainText
        }
        Row {
            width:parent.width;spacing:6
            visible:root.app!==null||body.truncated||root.expanded
            IslandButton {text:"Open app";icon:"chevronRight";iconSize:12;fontSize:Theme.fontSmall;subtle:true;visible:root.app!==null;onClicked:NotificationInbox.openApp(root.notification)}
            IslandButton {text:root.expanded?"Less":"Read more";fontSize:Theme.fontSmall;subtle:true;visible:body.truncated||root.expanded;onClicked:root.expanded=!root.expanded}
        }
    }
}
