import QtQuick
import "AmbientField.js" as Field

// Background only: never owns pointer handlers or changes island geometry.
Canvas {
    id: root
    property string motif: "off"
    property color accent: "#c4a7e7"
    property bool followAccent: false
    property real intensity: 0.55
    property real speed: 1.0
    property real phase: 0
    property real cornerRadius: 18
    property bool attached: false
    property bool notched: attached
    property real inset: attached ? 14 : 0
    property bool animate: true
    property bool active: true
    property int frameInterval: 80
    readonly property bool animating: visible && active && animate && intensity > 0
    visible: active && intensity > 0 && ["embers","haunted","prism","odyssey","reactor","web","neon","aurora","solar","candy"].includes(motif)
    renderStrategy: Canvas.Cooperative
    onMotifChanged: { phase = 0; requestPaint(); }
    onIntensityChanged: requestPaint()
    onAccentChanged: requestPaint()
    onFollowAccentChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onAttachedChanged: requestPaint()
    onNotchedChanged: requestPaint()
    onInsetChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onAnimateChanged: { if (!animate) phase=0; requestPaint(); }
    Timer {
        interval: Math.max(40, root.frameInterval)
        repeat: true
        running: root.animating
        onTriggered: root.phase = (root.phase + interval / 18000 * Math.max(.25, Math.min(2,root.speed))) % 1
    }
    onPaint: {
        const ctx=getContext("2d");
        if (!visible || width<=0 || height<=0) { ctx.reset(); ctx.clearRect(0,0,width,height); return; }
        ctx.reset();ctx.clearRect(0,0,width,height);
        // Match NotchSurface's cubic outline, including both flared shoulders.
        // The field spans the complete island; an inner rectangular viewport
        // would leave dark wedges where the shoulders meet the screen edge.
        const side=notched?Math.max(0,Math.min(inset,width/4,height/2)):0;
        const r=Math.max(0,Math.min(cornerRadius,(width-2*side)/2,height/2));
        const sh=Math.min(28,height/2), top=notched&&attached?0:r;
        const ty=notched&&attached?-1:0, k=.552285;
        ctx.save();ctx.beginPath();ctx.moveTo(top,ty);ctx.lineTo(width-top,ty);
        if(notched) {
            ctx.bezierCurveTo(attached?width-side:width-top*.45,attached?sh/3:0,
                              width-side,attached?sh*2/3:top*.45,width-side,attached?sh:top);
        } else ctx.bezierCurveTo(width-r*(1-k),0,width,r*(1-k),width,r);
        ctx.lineTo(width-side,height-r);
        ctx.bezierCurveTo(width-side,height-r*(1-k),width-side-r*(1-k),height,width-side-r,height);
        ctx.lineTo(side+r,height);
        ctx.bezierCurveTo(side+r*(1-k),height,side,height-r*(1-k),side,height-r);
        ctx.lineTo(side,notched&&attached?sh:top);
        if(notched) {
            ctx.bezierCurveTo(side,attached?sh*2/3:top*.45,
                              attached?side:top*.45,attached?sh/3:0,top,ty);
        } else ctx.bezierCurveTo(0,r*(1-k),r*(1-k),0,r,0);
        ctx.closePath();ctx.clip();
        const shapes=Field.frame(motif,width,height,phase,intensity,String(accent));
        const paintColors = new Map();
        const tint = Qt.rgba(accent.r, accent.g, accent.b, 0.72);
        function paintColor(color) {
            if (!root.followAccent) return Qt.color(color);
            if (!paintColors.has(color)) {
                paintColors.set(color, Qt.tint(Qt.color(color), tint));
            }
            return paintColors.get(color);
        }
        for (let i=0;i<shapes.length;i++) {
            const s=shapes[i];ctx.globalAlpha=s.alpha;
            if(s.kind==="cloud") {
                ctx.save();ctx.translate(s.x,s.y);ctx.rotate(s.rotation);ctx.scale(s.rx,s.ry);
                const c=paintColor(s.color),g=ctx.createRadialGradient(0,0,0,0,0,1);
                g.addColorStop(0,Qt.rgba(c.r,c.g,c.b,1));
                g.addColorStop(s.softness,Qt.rgba(c.r,c.g,c.b,.62));
                g.addColorStop(.68,Qt.rgba(c.r,c.g,c.b,.16));
                g.addColorStop(1,Qt.rgba(c.r,c.g,c.b,0));
                ctx.fillStyle=g;ctx.beginPath();ctx.arc(0,0,1,0,Math.PI*2);ctx.fill();ctx.restore();
                continue;
            }
            if(s.gradient) {
                const g=s.gradient,paint=ctx.createLinearGradient(g.x1,g.y1,g.x2,g.y2);
                for(let k=0;k<g.stops.length;k++) {
                    const stop=g.stops[k],c=paintColor(stop[1]);paint.addColorStop(stop[0],Qt.rgba(c.r,c.g,c.b,stop[2]));
                }
                ctx.strokeStyle=paint;ctx.fillStyle=paint;
            } else {ctx.strokeStyle=paintColor(s.color);ctx.fillStyle=paintColor(s.color);}
            ctx.lineWidth=s.width;ctx.lineCap="round";ctx.lineJoin="round";
            ctx.beginPath();
            if(s.kind==="circle") ctx.arc(s.x,s.y,s.r,0,Math.PI*2);
            else if(s.points.length) {
                ctx.moveTo(s.points[0][0],s.points[0][1]);
                for(let j=1;j<s.points.length;j++)ctx.lineTo(s.points[j][0],s.points[j][1]);
            }
            if(s.fill){ctx.closePath();ctx.fill();}else ctx.stroke();
        }
        ctx.restore();
    }
}
