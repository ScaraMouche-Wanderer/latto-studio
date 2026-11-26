import QtQuick
import "."
import "../../theme"
import ".."
Column {
    id:root
    property string text:""
    property var options:[]
    property var value:null
    signal selected(var value)
    width:parent?parent.width:300;spacing:5
    Label { width:parent.width;visible:root.text!=="";text:root.text;font.pixelSize:Theme.fontCaption;color:Theme.textSecondary }
    Flow {
        width:parent.width;spacing:4
        Repeater {
            model:root.options
            ControlButton {
                required property var modelData
                width:(root.width-4*Math.max(0,root.options.length-1))/Math.max(1,root.options.length)
                height:26;text:modelData.label;selected:root.value===modelData.value
                onClicked:root.selected(modelData.value)
            }
        }
    }
}
