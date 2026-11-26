import QtQuick
import QtQml.Models
import Quickshell

// A fixed number of shallow native regions follows the two curved shoulders.
// No image masks, per-frame allocation, or rectangular dead input corners.
Region {
    id: root
    required property var surface
    required property var body
    property bool active: false
    property var strips: []
    item: active ? body : null
    radius: Math.round(surface.bottomRadius)
    topLeftRadius: 0
    topRightRadius: 0
    regions: strips
    property Instantiator bands: Instantiator {
        model: 16
        delegate: Region {
            required property int index
            readonly property real bandHeight: root.surface.shoulderHeight / 16
            readonly property real cut: root.surface.insetAt(index * bandHeight)
            x: Math.floor(root.surface.x + cut)
            y: Math.floor(root.surface.y + index * bandHeight)
            width: root.active ? Math.ceil(root.surface.width - cut*2) + 1 : 0
            height: root.active ? Math.ceil(bandHeight) + 1 : 0
        }
        onObjectAdded: (index, object) => { root.strips = root.strips.concat([object]); }
        onObjectRemoved: (index, object) => { root.strips = root.strips.filter(item => item !== object); }
    }
}
