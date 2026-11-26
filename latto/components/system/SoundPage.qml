import QtQuick
import "."
import "../../services"
import "../../theme"
import ".."
ControlPage {
    title:"Sound";icon:"volume"
    ControlSlider { objectName:"outputVolume";text:"Output volume";icon:Audio.muted?"volumeOff":"volume";value:Audio.volume;enabled:Audio.hasOutput;disabledReason:"No audio output is connected";live:true;onMoved:fraction=>Audio.setVolume(fraction);onCommitted:fraction=>Audio.setVolume(fraction) }
    ControlToggle { objectName:"outputMuteToggle";text:"Mute speakers";icon:"volumeOff";checked:Audio.muted;enabled:Audio.hasOutput;disabledReason:"No audio output is connected";onToggled:Audio.toggleMute() }
    ControlChoice {
        visible:Audio.outputs.length>0;text:"Output device";value:Audio.sink
        options:Audio.outputs.map(node=>({label:Audio.deviceName(node),value:node}))
        onSelected:node=>Audio.selectOutput(node)
    }
    ControlSlider { text:"Microphone level";icon:"mic";tint:Theme.green;value:Audio.microphoneVolume;enabled:Audio.hasMicrophone;disabledReason:"No microphone is connected";live:true;onMoved:fraction=>Audio.setMicrophoneVolume(fraction);onCommitted:fraction=>Audio.setMicrophoneVolume(fraction) }
    ControlToggle {
        objectName:"microphoneMuteToggle"
        text:"Mute microphone";icon:"micOff";tint:Theme.green
        checked:Audio.microphoneMuted;enabled:Audio.hasMicrophone;disabledReason:"No microphone is connected"
        detail:Audio.deviceName(Audio.source)+(Settings.privacyIndicators?" · "+Privacy.microphoneStatus:"")
        onToggled:muted=>Audio.setMicrophoneMuted(muted)
    }
    ControlChoice { visible:Audio.inputs.length>0;text:"Input device";value:Audio.source;options:Audio.inputs.map(node=>({label:Audio.deviceName(node),value:node}));onSelected:node=>Audio.selectInput(node) }
}
