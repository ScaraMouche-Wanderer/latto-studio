import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
ControlPage {
    title:"Display";icon:"display"
    Component.onCompleted:DesktopSettings.watch()
    Component.onDestruction:DesktopSettings.unwatch()
    ControlSlider { objectName:"displayBrightness";text:"Screen brightness";icon:"brightness";tint:Theme.yellow;enabled:Brightness.available;disabledReason:"No controllable screen backlight";value:Brightness.level;onCommitted:fraction=>Brightness.set(fraction) }
    ControlToggle { objectName:"nightLightToggle";text:"Night Light";detail:"Uses your GNOME schedule";icon:"nightLight";tint:Theme.orange;checked:DesktopSettings.get("nightLight",false);enabled:DesktopSettings.canSet("nightLight");disabledReason:DesktopSettings.unavailable("nightLight");onToggled:value=>DesktopSettings.set("nightLight",value) }
    ControlSlider { text:"Night Light warmth";icon:"nightLight";tint:Theme.orange;from:1700;to:6500;suffix:" K";value:(DesktopSettings.get("temperature",4000)-1700)/4800;enabled:DesktopSettings.canSet("temperature");disabledReason:DesktopSettings.unavailable("temperature");onCommitted:fraction=>DesktopSettings.set("temperature",Math.round(1700+fraction*4800)) }
    ControlChoice { text:"Desktop appearance";value:DesktopSettings.get("colorScheme","default");enabled:DesktopSettings.canSet("colorScheme");options:[{label:"Automatic",value:"default"},{label:"Light",value:"prefer-light"},{label:"Dark",value:"prefer-dark"}];onSelected:value=>DesktopSettings.set("colorScheme",value) }
    ControlSlider { text:"Desktop text size";icon:"display";from:80;to:150;value:(DesktopSettings.get("textScale",1)-.8)/.7;enabled:DesktopSettings.canSet("textScale");disabledReason:DesktopSettings.unavailable("textScale");onCommitted:fraction=>DesktopSettings.set("textScale",Math.round((.8+.7*fraction)*100)/100) }
    ControlButton { text:"Advanced display settings…";icon:"settings";onClicked:SystemControls.run("settings","display") }
}
