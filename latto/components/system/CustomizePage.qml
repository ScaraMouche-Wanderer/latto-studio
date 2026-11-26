import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
ControlPage {
    signal requestPage(string page)
    title:"Customize the island";icon:"settings"
    ControlChoice { objectName:"islandPalette";text:"Colour palette";options:[{label:"Midnight",value:"Midnight"},{label:"Violet",value:"Violet dusk"},{label:"Graphite",value:"Graphite"},{label:"Ocean",value:"Ocean"}];enabled:!DesktopSettings.busy;onSelected:value=>DesktopSettings.setLatto("preset",value) }
    ControlChoice { text:"Accent";value:Settings.accentColor;options:[{label:"Lavender",value:"#c4a7e7"},{label:"Mint",value:"#86d4bd"},{label:"Blue",value:"#7dd3fc"},{label:"Rose",value:"#f4a5cb"}];enabled:!DesktopSettings.busy;onSelected:value=>DesktopSettings.setLatto("accentColor",value) }
    ControlChoice { text:"Corners";value:Settings.cornerStyle;options:[{label:"Pill",value:"pill"},{label:"Rounded",value:"rounded"}];enabled:!DesktopSettings.busy;onSelected:value=>DesktopSettings.setLatto("cornerStyle",value) }
    ControlChoice { text:"Motion";value:Settings.motionStyle;options:[{label:"Smooth",value:"smooth"},{label:"Snappy",value:"snappy"},{label:"Reduced",value:"reduced"}];enabled:!DesktopSettings.busy;onSelected:value=>DesktopSettings.setLatto("motionStyle",value) }
    ControlSlider { text:"Preferred compact width";icon:"display";from:180;to:480;suffix:" px";value:(Settings.idleWidth-180)/300;enabled:!DesktopSettings.busy;onCommitted:fraction=>DesktopSettings.setLatto("idleWidth",Math.round(180+fraction*300)) }
    ControlButton {text:"Saved profiles";icon:"settings";onClicked:requestPage("profiles")}
    ControlButton { text:"Full Latto Studio…";icon:"settings";onClicked:SystemControls.run("studio") }
}
