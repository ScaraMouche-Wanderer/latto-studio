import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
ControlPage {
    id:root
    title:"About this system";icon:"info"
    readonly property var info:SystemControls.data.system||({})
    Label { width:parent.width;text:root.info.osName||"Linux";font.pixelSize:Theme.fontTitle;font.weight:Font.DemiBold;elide:Text.ElideRight }
    Label { width:parent.width;text:"Kernel  "+(root.info.kernel||"Unavailable");font.pixelSize:Theme.fontSmall;color:Theme.textSecondary;elide:Text.ElideRight }
    Label { width:parent.width;text:root.info.uptimeSeconds!=null?"Uptime  "+Math.floor(root.info.uptimeSeconds/86400)+"d "+Math.floor(root.info.uptimeSeconds/3600)%24+"h "+Math.floor(root.info.uptimeSeconds/60)%60+"m":"Uptime unavailable";font.pixelSize:Theme.fontSmall;elide:Text.ElideRight }
    Label { width:parent.width;text:root.info.storageFreeGiB!=null?"Home storage  "+root.info.storageFreeGiB.toFixed(1)+" / "+root.info.storageTotalGiB.toFixed(1)+" GiB free":"Storage unavailable";font.pixelSize:Theme.fontSmall;color:Theme.accent;elide:Text.ElideRight }
    ControlButton { text:"Open live CPU & memory statistics";icon:"barChart";onClicked:IslandState.openRequested("stats") }
}
