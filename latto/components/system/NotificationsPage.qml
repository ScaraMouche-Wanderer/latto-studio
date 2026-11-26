import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
ControlPage {
    title:"Notifications";icon:"bell"
    Component.onCompleted:DesktopSettings.watch()
    Component.onDestruction:DesktopSettings.unwatch()
    ControlToggle {
        objectName: "gnomeDndToggle"
        text: "Do Not Disturb"
        detail: Settings.notificationsEnabled ? "Silence Latto notification banners" : "Silence GNOME desktop notification banners"
        icon: "moon"
        tint: Theme.indigo
        checked: Notifications.doNotDisturb
        enabled: Notifications.canSetDoNotDisturb
        disabledReason: "Unavailable in this desktop session"
        onToggled: value => Notifications.setDoNotDisturb(value)
    }
    ControlToggle { text:"Show notifications on lock screen";icon:"lock";checked:DesktopSettings.get("lockNotifications",false);enabled:DesktopSettings.canSet("lockNotifications");disabledReason:DesktopSettings.unavailable("lockNotifications");onToggled:value=>DesktopSettings.set("lockNotifications",value) }
}
