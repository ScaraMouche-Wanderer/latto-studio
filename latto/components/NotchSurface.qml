import QtQuick
import QtQuick.Shapes

// Flush top, flared shoulders and soft lower corners. The curve and native
// window mask share these dimensions so invisible corners remain clickable.
Shape {
    id: root
    property bool attached: true
    property real dip: 0
    property real inset: 14
    property real cornerRadius: 18
    property color fill: "black"
    property color outline: "transparent"
    readonly property real shoulderHeight: Math.min(28, height / 2)
    readonly property real sideInset: Math.min(inset, width / 4, height / 2)
    readonly property real bottomRadius: Math.max(0, Math.min(cornerRadius, (width - sideInset * 2) / 2, height / 2))
    readonly property real topY: attached ? -1 : 0
    readonly property real topRadius: attached ? 0 : bottomRadius
    readonly property real center: width / 2
    readonly property real dipHalfWidth: Math.min(10 + dip * 0.85, Math.max(0, center - sideInset - bottomRadius))
    function insetAt(y) {
        const t = Math.max(0, Math.min(1, y / Math.max(1, shoulderHeight)));
        return sideInset * (1 - Math.pow(1 - t, 3));
    }
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: 1
        strokeColor: root.outline
        fillColor: root.fill
        // Start above the screen for the attached notch. The floating pill rounds all four corners.
        startX: root.topRadius; startY: root.topY
        PathLine { x: root.width - root.topRadius; y: root.topY }
        PathCubic {
            control1X: root.attached ? root.width - root.sideInset : root.width - root.topRadius * 0.45
            control1Y: root.attached ? root.shoulderHeight / 3 : 0
            control2X: root.width - root.sideInset
            control2Y: root.attached ? root.shoulderHeight * 2 / 3 : root.topRadius * 0.45
            x: root.width - root.sideInset
            y: root.attached ? root.shoulderHeight : root.topRadius
        }
        PathLine { x: root.width-root.sideInset; y: root.height-root.bottomRadius }
        PathCubic {
            control1X: root.width-root.sideInset; control1Y: root.height-root.bottomRadius*(1-0.552285)
            control2X: root.width-root.sideInset-root.bottomRadius*(1-0.552285); control2Y: root.height
            x: root.width-root.sideInset-root.bottomRadius; y: root.height
        }
        PathLine { x: root.center + root.dipHalfWidth; y: root.height }
        PathCubic {
            control1X: root.center + root.dipHalfWidth * 0.36; control1Y: root.height
            control2X: root.center + root.dipHalfWidth * 0.40; control2Y: root.height + root.dip
            x: root.center; y: root.height + root.dip
        }
        PathCubic {
            control1X: root.center - root.dipHalfWidth * 0.40; control1Y: root.height + root.dip
            control2X: root.center - root.dipHalfWidth * 0.36; control2Y: root.height
            x: root.center - root.dipHalfWidth; y: root.height
        }
        PathLine { x: root.sideInset+root.bottomRadius; y: root.height }
        PathCubic {
            control1X: root.sideInset+root.bottomRadius*(1-0.552285); control1Y: root.height
            control2X: root.sideInset; control2Y: root.height-root.bottomRadius*(1-0.552285)
            x: root.sideInset; y: root.height-root.bottomRadius
        }
        PathLine { x: root.sideInset; y: root.attached ? root.shoulderHeight : root.topRadius }
        PathCubic {
            control1X: root.sideInset
            control1Y: root.attached ? root.shoulderHeight * 2 / 3 : root.topRadius * 0.45
            control2X: root.attached ? root.sideInset : root.topRadius * 0.45
            control2Y: root.attached ? root.shoulderHeight / 3 : 0
            x: root.topRadius; y: root.topY
        }
    }
}
