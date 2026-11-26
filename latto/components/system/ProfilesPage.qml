import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
ControlPage {
    title:"Profiles";icon:"settings"
    Component.onCompleted:IslandProfiles.refresh()
    Component.onDestruction:IslandProfiles.clear()
    Label {width:parent.width;wrapMode:Text.Wrap;text:IslandProfiles.error||"Review a saved Studio profile before applying it.";font.pixelSize:Theme.fontSmall;color:IslandProfiles.error!==""?Theme.orange:Theme.textSecondary}
    Label {visible:IslandProfiles.busy;text:"Opening profile…";font.pixelSize:Theme.fontSmall;color:Theme.textTertiary}
    Repeater {
        model:IslandProfiles.names
        ControlButton {
            required property string modelData
            width:parent.width;text:modelData;icon:"chevronRight"
            enabled:!IslandProfiles.busy&&!DesktopSettings.busy
            selected:IslandProfiles.reviewed.name===modelData
            onClicked:IslandProfiles.review(modelData)
        }
    }
    Label {visible:!IslandProfiles.busy&&IslandProfiles.names.length===0;width:parent.width;wrapMode:Text.Wrap;text:"Save a profile in Studio to see it here.";font.pixelSize:Theme.fontSmall;color:Theme.textSecondary}
    Label {visible:IslandProfiles.reviewed.ok===true;width:parent.width;wrapMode:Text.Wrap;text:IslandProfiles.changes.length+" changes in “"+(IslandProfiles.reviewed.name||"")+"”";font.pixelSize:Theme.fontBody;color:Theme.accent}
    Repeater {
        model:IslandProfiles.reviewed.ok===true?IslandProfiles.changes:[]
        Label {required property var modelData;width:parent.width;wrapMode:Text.Wrap;text:modelData.label+" → "+modelData.value;font.pixelSize:Theme.fontSmall;color:Theme.textSecondary}
    }
    ControlButton {objectName:"applyReviewedProfile";visible:IslandProfiles.reviewed.ok===true;text:"Apply reviewed profile";icon:"check";enabled:!DesktopSettings.busy&&IslandProfiles.changes.length>0;onClicked:IslandProfiles.apply()}
    ControlButton {text:"Manage profiles in Studio…";icon:"settings";onClicked:SystemControls.run("studio","profiles")}
}
