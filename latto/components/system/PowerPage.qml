import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
ControlPage {
    title:"Power";icon:"bolt"
    Component.onCompleted:DesktopSettings.watch()
    Component.onDestruction:DesktopSettings.unwatch()
    Label { width:parent.width;text:SystemControls.data.battery.available?Math.round(SystemControls.data.battery.percent)+"% · "+SystemControls.data.battery.status+(SystemControls.data.battery.health!=null?" · Health "+SystemControls.data.battery.health+"%":""):"No battery";font.pixelSize:Theme.fontSmall;color:Theme.green;elide:Text.ElideRight }
    ControlChoice { visible:SystemControls.data.profiles.available.length>0;text:"Power profile";value:SystemControls.data.profiles.active;options:SystemControls.data.profiles.available.map(mode=>({label:({"power-saver":"Power saver",balanced:"Balanced",performance:"Performance"})[mode],value:mode}));enabled:!SystemControls.busy;onSelected:value=>SystemControls.run("profile",value) }
    Label { visible:SystemControls.data.profiles.available.length===0; text:"Power profiles are unavailable on this system";color:Theme.textTertiary;font.pixelSize:Theme.fontCaption }
    ControlToggle { text:"Keep awake";detail:"Prevent automatic idle sleep";icon:"coffee";checked:Caffeine.active;tint:Theme.yellow;onToggled:Caffeine.toggle() }
    ControlChoice { text:"Screen blanking";value:DesktopSettings.get("idleDelay",300);enabled:DesktopSettings.canSet("idleDelay");options:[{label:"Never",value:0},{label:"1 min",value:60},{label:"5 min",value:300},{label:"10 min",value:600},{label:"30 min",value:1800}];onSelected:value=>DesktopSettings.set("idleDelay",value) }
    ControlToggle { text:"Automatic sleep on battery";icon:"moon";checked:DesktopSettings.get("sleepBattery","nothing")==="suspend";enabled:DesktopSettings.canSet("sleepBattery");disabledReason:DesktopSettings.unavailable("sleepBattery");onToggled:value=>DesktopSettings.set("sleepBattery",value?"suspend":"nothing") }
    ControlToggle { text:"Automatic sleep when plugged in";icon:"bolt";checked:DesktopSettings.get("sleepAC","nothing")==="suspend";enabled:DesktopSettings.canSet("sleepAC");disabledReason:DesktopSettings.unavailable("sleepAC");onToggled:value=>DesktopSettings.set("sleepAC",value?"suspend":"nothing") }
}
