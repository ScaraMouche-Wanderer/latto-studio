import QtQuick
import "../theme"

// A restrained glass-like material drawn in the main scene graph. It does
// not capture other windows or allocate a live blur texture during resizing.
Rectangle {
    id:root
    property real emphasis:0
    property color tint:Theme.accent
    radius:12
    readonly property color upper:Qt.lighter(Theme.surface,1.55)
    gradient:Gradient {
        GradientStop {position:0;color:Qt.rgba(root.upper.r,root.upper.g,root.upper.b,.96)}
        GradientStop {position:.5;color:Qt.rgba(Theme.surface.r,Theme.surface.g,Theme.surface.b,.78)}
        GradientStop {position:1;color:Qt.rgba(Theme.surface.r,Theme.surface.g,Theme.surface.b,.9)}
    }
    border.width:1
    border.color:Qt.rgba(Theme.text.r,Theme.text.g,Theme.text.b,.08+root.emphasis*.1)
    Rectangle {
        anchors.fill:parent;radius:parent.radius
        gradient:Gradient {
            GradientStop {position:0;color:Qt.rgba(root.tint.r,root.tint.g,root.tint.b,.055+root.emphasis*.045)}
            GradientStop {position:.7;color:"transparent"}
        }
    }
    Rectangle {
        anchors.top:parent.top;anchors.topMargin:1;anchors.horizontalCenter:parent.horizontalCenter
        width:Math.max(0,parent.width-parent.radius*2);height:1
        color:Qt.rgba(Theme.text.r,Theme.text.g,Theme.text.b,.1+root.emphasis*.08)
    }
    Behavior on emphasis {NumberAnimation {duration:Theme.pageDuration;easing.type:Easing.OutCubic}}
    Behavior on border.color {ColorAnimation {duration:Theme.pageDuration}}
}
