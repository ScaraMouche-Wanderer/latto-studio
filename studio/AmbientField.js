.pragma library
// Shared deterministic vector geometry. Both Studio and the island call frame().
// No assets, network access, random state or shader/runtime dependencies.
var TAU = Math.PI * 2;
function frame(style, w, h, phase, intensity, accent) {
    var out = [], t = phase * TAU, strength = Math.max(0, Math.min(0.8, intensity)) * 0.55;
    if (style === "off" || !style || w <= 0 || h <= 0 || strength <= 0) return out;
    function path(points, color, alpha, width, fill) {
        out.push({kind:"path", points:points, color:color, alpha:alpha*strength,
                  width:width || 1, fill:!!fill});
    }
    function circle(x,y,r,color,alpha,fill,width) {
        out.push({kind:"circle",x:x,y:y,r:r,color:color,alpha:alpha*strength,
                  fill:fill !== false,width:width || 1});
    }
    function ellipse(x,y,rx,ry,color,alpha,fill,rotation) {
        var points=[], rot=rotation || 0;
        for (var i=0;i<=48;i++) {
            var a=i*TAU/48, xx=Math.cos(a)*rx, yy=Math.sin(a)*ry;
            points.push([x+xx*Math.cos(rot)-yy*Math.sin(rot),y+xx*Math.sin(rot)+yy*Math.cos(rot)]);
        }
        path(points,color,alpha,1,fill);
    }
    function wave(y,amplitude,color,alpha,offset,width) {
        var points=[];
        for (var i=0;i<=40;i++) {
            var x=i*w/40;
            points.push([x,y+Math.sin(i/40*TAU*1.2-t+offset)*amplitude]);
        }
        path(points,color,alpha,width,false);
    }
    function gradient(colors) {
        return {x1:0,y1:h*.2,x2:w,y2:h*.8,stops:[[0,colors[0],0],[.13,colors[0],1],[.5,colors[1],1],[.87,colors[2],1],[1,colors[2],0]]};
    }
    function field(x,y,rx,ry,color,alpha) {
        out.push({kind:"cloud",x:x,y:y,rx:rx,ry:ry,rotation:0,color:color,alpha:alpha,softness:.3});
    }
    function filament(points,color,alpha,width,colors,family,strand) {
        path(points,color,alpha,width,false);
        var s=out[out.length-1];s.alpha=alpha;s.gradient=gradient(colors);s.role="filament";s.family=family;s.strand=strand;
    }
    function woven(style) {
        var palettes=style==="prism"?[["#26f5e3","#4f7dff","#b96bff"],["#ff54c5","#ff8c63","#ffe066"],["#8cffbd","#35cfff","#c278ff"]]
          :style==="candy"?[["#ff47bf","#b96cff","#56edff"],["#7e70ff","#ff65bf","#ffc2ec"],["#49e7ed","#ed6cff","#ff618e"]]
          :style==="haunted"?[["#73ffc5","#4aa99a","#c0a3ff"],["#b6a1ff","#71c9b3","#9bffc5"],["#61dbad","#9282db","#a1f0dc"]]
          :style==="web"?[["#ff477d","#fa7193","#b55cff"],["#df376b","#8d58e9","#ff8274"],["#ff5c9d","#ff9d7b","#c456de"]]
          :[["#18edff","#4f68ff","#cf4cff"],["#ff35c5","#a95aff","#31ddff"],["#71faff","#ef60df","#7274ff"]];
        var power=Math.max(0,Math.min(.8,intensity))/.8;
        power*=.065+.935*Math.max(0,Math.min(1,(h-36)/140));
        var morph=.5-.5*Math.cos(t), amplitude=Math.min(88,h*.28), n=18;
        for(var g=0;g<3;g++) {
            var dir=g%2?-1:1, tilt=style==="candy"?h*.5:style==="web"?h*(g===1?-.28:.28):0;
            var band=gradient(palettes[g]);
            function center(f) {
                var a=Math.sin(f*TAU*.95-dir*t+g*2.0);
                var b=Math.sin(f*TAU*1.35+dir*t+g*.8);
                return h*(style==="web"?.32+g*.18:.27+g*.23)+amplitude*(a*(1-morph)+b*morph)+tilt*(f-.5);
            }
            // Each family is a sheet of tightly spaced strands, twisting from
            // open fans into pinched/interlocking forms as its phase advances.
            for(var k=0;k<n;k++) {
                var q=(k/(n-1)-.5)*2, points=[];
                for(var j=0;j<=48;j++) {
                    var f=j/48, twist=Math.sin(f*TAU*.7-dir*t+g*.9);
                    var spread=Math.min(29,h*.14)*twist;
                    points.push([f*w,center(f)+q*spread+q*q*Math.sin(f*TAU+t+g)*Math.min(8,h*.04)]);
                }
                var edge=1-Math.abs(q)*.45, depth=.8+.2*Math.sin(t+g*2.1);
                filament(points,palettes[g][1],(.48+.24*edge)*power*depth,.8,palettes[g],g,k);
            }
            // A traveling luminous segment follows the middle of the sheet.
            var progress=(phase+g/3)%1, trace=[];
            for(var j=0;j<=12;j++) {
                var f=Math.max(0,Math.min(1,progress-.055+j*.009));trace.push([f*w,center(f)]);
            }
            path(trace,palettes[g][0],.55*power*Math.sin(Math.PI*progress),2.0,false);
            out[out.length-1].gradient=band;out[out.length-1].role="highlight";
        }
        // Keep the exposed label zone quiet without dulling the colored edges.
        field(w*.5,h*.52,w*.52,h*.61,"#070a18",.33+.2*(1-Math.max(0,Math.min(1,(h-36)/140))));
    }
    function orbital(style) {
        var power=Math.max(0,Math.min(.8,intensity))/.8;
        power*=.075+.925*Math.max(0,Math.min(1,(h-36)/140));
        var colors=style==="solar"?["#ff5d49","#ffad37","#fff0a0"]:["#128fff","#18eaff","#d5ffff"];
        var cx=w*.74,cy=h*.53,rx=Math.min(w*.35,h*.88),ry=h*.28;
        function orbitPoint(a,g,offset,tilt) {
            var ripple=1+.055*Math.sin(a*3-t+g);
            var spread=offset*(.75+.25*Math.sin(a*2+t+g));
            var x=Math.cos(a)*(rx*(.52+g*.23)*(1+.12*Math.sin(t+g))+spread)*ripple;
            var y=Math.sin(a)*(ry*(.52+g*.23)*(1+.22*Math.cos(t+g*.8))+spread)*ripple;
            return [cx+x*Math.cos(tilt)-y*Math.sin(tilt),cy+x*Math.sin(tilt)+y*Math.cos(tilt)];
        }
        for(var g=0;g<3;g++) {
            var tilt=g*TAU/3+.32*Math.sin(t+g*1.2),dir=g%2?-1:1;
            for(var k=0;k<12;k++) {
                var points=[],offset=(k-5.5)*1.45;
                for(var j=0;j<=64;j++)points.push(orbitPoint(j/64*TAU+dir*t+g*.8,g,offset,tilt));
                filament(points,colors[1],power*(.48+.14*Math.cos(t+g)),.8,colors,g,k);
            }
            var trace=[];
            for(var j=0;j<=12;j++)trace.push(orbitPoint(dir*t+g*2.1+j*.045,g,0,tilt));
            path(trace,colors[2],.7,1.8,false);
            var light=out[out.length-1];light.alpha=.7*power;light.gradient=gradient(colors);light.role="highlight";
        }
        field(cx,cy,rx*.4,ry*.44,colors[1],.16*power);
        field(w*.48,h*.53,w*.47,h*.63,"#070b18",.38);
    }
    if (["prism","neon","candy","haunted","web"].indexOf(style)>=0) {
        woven(style);return out;
    }
    if (["reactor","solar"].indexOf(style)>=0) {orbital(style);return out;}
    if (style === "embers") {
        for (var i=0;i<19;i++) {
            var f=(i*0.61803398875+phase)%1;
            circle(((i*0.381966+0.14)%1)*w+Math.sin(t+i)*w*0.018,
                   h*(1-f),0.7+(i%3)*0.55,i%3 ? "#ff9c3b":"#ffdb8a",
                   0.7*Math.sin(Math.PI*f),true);
        }
        var x=w*0.91, y=h>70?18:h*.53, r=Math.min(h>70?14:h*.3,w*.08);
        ellipse(x,y,r*1.2,r,"#e96122",0.12,true,0);
        path([[x-r*.85,y-r*.13],[x-r*.28,y-r*.45],[x-r*.18,y+r*.12]],"#ffc35d",0.8,1,true);
        path([[x+r*.85,y-r*.13],[x+r*.28,y-r*.45],[x+r*.18,y+r*.12]],"#ffc35d",0.8,1,true);
        path([[x-r*.6,y+r*.38],[x-r*.25,y+r*.62],[x,y+r*.4],[x+r*.25,y+r*.62],[x+r*.6,y+r*.38]],"#ff9c3b",0.5,1.2,false);
        wave(h*.92,h*.09,"#ff783b",0.5,0,2);
    } else if (style === "aurora") {
        // Soft elliptical light fields: no centerline strokes or hard contours.
        var power=Math.max(0,Math.min(.8,intensity))/.8;
        var compact=Math.max(0,Math.min(1,(h-36)/130));
        power *= .32 + .68 * compact;
        var drift=Math.sin(t), swell=Math.cos(t);
        function cloud(x,y,rx,ry,color,opacity,rotation,softness) {
            out.push({kind:"cloud",x:x,y:y,rx:rx,ry:ry,rotation:rotation||0,
                color:color,alpha:opacity*power,softness:softness||.3});
        }
        cloud(w*(.04+.13*drift),h*(.06+.08*swell),w*.55,h*.9,
              "#00efae",.76,-.2+.07*swell,.22);
        cloud(w*(.37+.14*Math.cos(t+.6)),h*(-.13+.12*Math.sin(t+.7)),w*.5,h*.8,
              "#00aaff",.68,.12+.1*drift,.25);
        cloud(w*(1.01+.12*Math.sin(t+2)),h*(.17+.09*Math.cos(t+1.3)),w*.53,h*.92,
              "#8848ff",.78,-.25+.1*Math.cos(t+1),.28);
        cloud(w*(.86+.14*Math.cos(t+1.5)),h*(1.08+.1*Math.sin(t+2.2)),w*.59,h*.82,
              "#ff36b8",.72,.18+.1*drift,.24);
        cloud(w*(.02+.07*Math.cos(t+2.7)),h*(1.02+.08*Math.sin(t+.3)),w*.5,h*.67,
              "#08c9e8",.6,-.12+.12*Math.sin(t+.8),.2);
        // A luminous, uneven crest dissolves into the larger cloud fields.
        for(var i=0;i<7;i++) {
            var f=i/6;
            var x=w*(f+.025*Math.sin(t+i*.5));
            var y=h*(.1+.11*Math.sin(f*TAU*.65-t));
            cloud(x,y,w*(.14+.02*Math.cos(t+i)),h*(.25+.025*Math.sin(t+i)),
                  i<3?"#48ffd4":i<5?"#43bcff":"#c477ff",.13+.04*Math.sin(t+i),-.1+i*.04,.16);
        }
        // Constant-direction light mist keeps flowing between the larger swells.
        // Each field enters/exits outside the island and fades at the wrap point.
        var mistColors=["#43ffd0","#32cfff","#8c7bff","#ef65d7","#64dfef"];
        for(var i=0;i<5;i++) {
            var f=(phase+i*.2)%1, envelope=Math.pow(Math.sin(Math.PI*f),2);
            var x=w*(-.24+1.48*(i%2?1-f:f));
            var y=h*(i%2?.86:.13)+Math.sin(t+i*.9)*h*.1;
            cloud(x,y,w*.24,h*.42,mistColors[i],.24*envelope,
                  -.25+Math.sin(t+i)*.1,.2);
        }
        // Quiet negative space protects exposed labels; colorful edges remain.
        cloud(w*.5,h*.53,w*.56,h*.64,"#070b18",.47+.12*(1-compact),0,.35);
    } else if (style === "odyssey") {
        ellipse(w*.22+Math.sin(t)*w*.08,h*.7,w*.35,h*.43,"#8168e8",.11,true,-.12);
        ellipse(w*.78+Math.cos(t)*w*.06,h*.28,w*.3,h*.35,"#428fd9",.12,true,.15);
        for(var i=0;i<31;i++) {
            var x=((i*.618034+.08)%1)*w,y=((i*.414214+.13)%1)*h;
            circle(x,y,i%5?0.65:1.2,i%3?"#c2c8ff":"#ffcf9a",.3+.25*(.5+.5*Math.sin(t+i)),true);
        }
        ellipse(w*.52,h*.55,w*.42,h*.37,"#9daaff",.23,false,-.09);
        var a=t;
        circle(w*.52+Math.cos(a)*w*.42,h*.55+Math.sin(a)*h*.37,2,"#ffdbac",.9,true);
    }
    return out;
}
