import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
Item {
    id:root
    property string title:""
    property string icon:""
    implicitHeight:Math.ceil(38+body.implicitHeight+18)
    readonly property real contentHeight:body.implicitHeight
    signal back()
    default property alias content:body.data
    Rectangle { x:0;y:0;width:parent.width;height:30;radius:10;color:Theme.surface
        ControlButton { x:2;y:2;width:29;height:26;icon:"chevronLeft";onClicked:root.back() }
        Icon { x:42;anchors.verticalCenter:parent.verticalCenter;size:16;name:root.icon;color:Theme.accent }
        Label { x:67;anchors.verticalCenter:parent.verticalCenter;width:parent.width-78;text:root.title;font.pixelSize:Theme.fontBody;font.weight:Font.DemiBold;elide:Text.ElideRight }
    }
    Flickable {
        id:scroll
        objectName:"systemPageScroll"
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.topMargin:38;anchors.bottom:error.top;anchors.bottomMargin:5
        clip:true;contentWidth:width;contentHeight:body.implicitHeight;boundsBehavior:Flickable.StopAtBounds
        Column { id:body;objectName:"systemPageBody";width:scroll.width-5;spacing:9 }
    }
    Rectangle { width:3;x:parent.width-3;y:38+(scroll.height-height)*(scroll.visibleArea.yPosition/Math.max(.001,1-scroll.visibleArea.heightRatio));height:Math.max(14,scroll.height*scroll.visibleArea.heightRatio);radius:1.5;color:Theme.textTertiary;visible:scroll.contentHeight>scroll.height }
    Label { id:error;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:13;visible:true;text:DesktopSettings.error||SystemControls.error||(DesktopSettings.busy?"Applying…":DesktopSettings.phase==="applied"?"Applied":"");font.pixelSize:Theme.fontCaption;color:DesktopSettings.error!==""||SystemControls.error!==""?Theme.orange:Theme.green;elide:Text.ElideRight }
}
