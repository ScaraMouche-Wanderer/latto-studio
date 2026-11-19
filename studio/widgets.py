"""Small native widgets shared by Latto Studio."""
import datetime
from pathlib import Path
from PySide6.QtCore import Qt,QRectF,QSize,QTimer
from PySide6.QtGui import QColor,QPainter,QFont,QLinearGradient,QPen,QPainterPath
from PySide6.QtWidgets import QWidget,QCheckBox,QStyledItemDelegate,QPushButton
from model import DEFAULTS,TABS,effective_width
from ambient import AmbientRenderer

class Toggle(QCheckBox):
    def __init__(self,text=''):
        super().__init__(text)
        self.setCursor(Qt.PointingHandCursor)
        self.setMinimumHeight(30)
        self.setAccessibleName(text)
    def paintEvent(self,event):
        p=QPainter(self);p.setRenderHint(QPainter.Antialiasing)
        track=QRectF(2,(self.height()-18)/2,32,18)
        p.setPen(QPen(QColor('#8e4e2a' if self.hasFocus() else '#9a5d37' if self.isChecked() else '#9ba68b'),1))
        p.setBrush(QColor('#a46a42' if self.isChecked() else '#ccd3bf'));p.drawRoundedRect(track,9,9)
        p.setPen(Qt.NoPen);p.setBrush(QColor('#fffaf3' if self.isChecked() else '#ffffff'))
        p.drawEllipse(QRectF(track.x()+(18 if self.isChecked() else 3),track.y()+3,12,12))
        p.setPen(QColor('#30372a' if self.isEnabled() else '#7a856e'));p.setFont(self.font())
        p.drawText(QRectF(44,0,self.width()-44,self.height()),Qt.AlignVCenter|Qt.AlignLeft,self.text())
    def sizeHint(self):
        return QSize(self.fontMetrics().horizontalAdvance(self.text())+50,30)
    def hitButton(self,pos):
        # Our painted track reserves more space than a native checkbox.
        # Keep all visible label text clickable without activating blank rows.
        return self.rect().contains(pos) and pos.x() <= min(self.width(),self.sizeHint().width())

class Preview(QWidget):
    """Illustrated states, deliberately using sample media and statistics."""
    def __init__(self):
        super().__init__()
        self.ambient_renderer=AmbientRenderer(self)
        self.ambient_phase=0.0
        self.ambient_timer=QTimer(self)
        self.ambient_timer.setInterval(50)
        self.ambient_timer.timeout.connect(self.advance_ambient)
        self.data=DEFAULTS.copy()
        self.mode='Compact'
        self.stage='Paper'
        self.metrics={'available':False,'percent':0,'charging':False,'cpu':0,'memory':0}
        self.previous_cpu=None
        self.last_layout={}
        self.read_metrics()
        self.refresh_timer=QTimer(self)
        self.refresh_timer.setInterval(3000)
        self.refresh_timer.timeout.connect(self.refresh_metrics)
        self.refresh_timer.start()
        self.setMinimumHeight(142)
        self.setAccessibleName('Latto sample preview')
    def read_metrics(self):
        self.metrics['available']=False
        for battery in sorted(Path('/sys/class/power_supply').glob('BAT*')):
            try:
                self.metrics.update(available=True,percent=max(0,min(100,int((battery/'capacity').read_text()))),charging=(battery/'status').read_text().strip()=='Charging')
                break
            except (OSError,ValueError):continue
        try:
            cpu=[int(x) for x in Path('/proc/stat').read_text().splitlines()[0].split()[1:9]]
            current=(sum(cpu),cpu[3]+cpu[4])
            if self.previous_cpu and current[0]>self.previous_cpu[0]:
                self.metrics['cpu']=max(0,min(100,(1-(current[1]-self.previous_cpu[1])/(current[0]-self.previous_cpu[0]))*100))
            self.previous_cpu=current
            mem={line.split(':')[0]:int(line.split()[1]) for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith(('MemTotal:','MemAvailable:'))}
            self.metrics['memory']=(mem['MemTotal']-mem['MemAvailable'])/1048576
        except (OSError,ValueError,KeyError,IndexError):pass
    def refresh_metrics(self):
        if self.isVisible():self.read_metrics();self.update()
    def sync_ambient(self):
        moving=self.isVisible() and self.data.get('ambientStyle','off')!='off' and self.data.get('ambientIntensity',.55)>0 and self.data.get('motionStyle')!='reduced'
        if moving:self.ambient_timer.start()
        else:self.ambient_timer.stop()
    def advance_ambient(self):
        if not self.isVisible():self.ambient_timer.stop();return
        self.ambient_phase=(self.ambient_phase+.05*self.data.get('ambientSpeed',1)/18)%1
        self.update()
    def showEvent(self,event):
        super().showEvent(event);self.sync_ambient()
    def hideEvent(self,event):
        self.ambient_timer.stop();super().hideEvent(event)
    def set_data(self,data):
        previous=self.data.get('ambientStyle','off')
        self.data={**DEFAULTS,**data}
        if previous!=self.data.get('ambientStyle') or self.data.get('motionStyle')=='reduced':self.ambient_phase=0
        self.sync_ambient()
        self.refresh_timer.setInterval(max(1000,self.data.get('statsInterval',3000)))
        self.update()
    def set_mode(self,mode):
        if mode not in {'Compact','Music','Expanded'}:
            raise ValueError('Unsupported sample preview mode.')
        self.mode=mode
        self.setAccessibleDescription(mode+' sample preview')
        # Draw the selected state immediately, including on composited desktops.
        self.repaint()
    def set_stage(self,name):
        if name not in {'Paper','Slate','Night'}:raise ValueError('Unsupported preview backdrop.')
        self.stage=name;self.update()
    def paintEvent(self,event):
        d=self.data
        p=QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        w,h=self.width(),self.height()
        paper=self.stage=='Paper'
        p.setBrush(QColor({'Paper':'#c6bfac','Slate':'#454e47','Night':'#20271e'}[self.stage]));p.setPen(Qt.NoPen)
        p.drawRoundedRect(self.rect(),4,4)
        # Sparse crop marks frame a desktop object, without competing with it.
        p.setPen(QPen(QColor('#777c68' if paper else '#697762'),.7))
        for x,dx in [(12,1),(w-12,-1)]:
            for y,dy in [(12,1),(h-12,-1)]:
                p.drawLine(x,y,x+dx*9,y);p.drawLine(x,y,x,y+dy*9)
        def color(key,fallback):
            c=QColor(d.get(key,fallback))
            return c if c.isValid() else QColor(fallback)
        accent=color('accentColor','#c4a7e7');text=color('textColor','#f5f5f7')
        island=color('backgroundColor','#000000');island.setAlphaF(float(d.get('backgroundOpacity',1)))
        surface=color('surfaceColor','#141416')
        def label(rect,value,size=10,col=None,alignment=Qt.AlignVCenter|Qt.AlignLeft,bold=False):
            font=QFont(d.get('fontFamily') or 'Noto Sans',size)
            font.setBold(bold);p.setFont(font);p.setPen(col or text);p.drawText(rect,alignment,value)
        compact=self.mode=='Compact'
        width=effective_width(d) if compact else 340 if self.mode=='Music' else 420
        attached=d.get("edgeReveal",False)
        self.render_scale=min(1,max(1,w-32)/(width+(28 if attached else 0)))
        # Shrink the whole illustration, never its layout. A wide Monitor
        # preset must retain the same indicators in the narrow viewfinder.
        p.save();pivot_y=0 if attached else h/2-7;p.translate(w/2,pivot_y);p.scale(self.render_scale,self.render_scale);p.translate(-w/2,-pivot_y)
        height=36 if compact or self.mode=='Music' else 102
        rect=QRectF((w-width)/2,0 if attached else (h-height)/2-7,width,height)
        shadow=QColor('#000000');shadow.setAlpha(60)
        p.setPen(Qt.NoPen);p.setBrush(shadow)
        if not attached:p.drawRoundedRect(rect.translated(0,5),20,20)
        # The live island has no outer outline; preserve borders inside controls.
        p.setBrush(island);p.setPen(Qt.NoPen);radius=11 if d.get('cornerStyle')=='rounded' else min(24,height/2)
        if attached:
            left,right=rect.left(),rect.right();top=-1;bottom=rect.bottom();shoulder=min(28,height/2);r=min(radius,height/2);k=.552285
            shape=QPainterPath();shape.moveTo(left-14,top);shape.lineTo(right+14,top)
            shape.cubicTo(right,shoulder/3,right,shoulder*2/3,right,shoulder);shape.lineTo(right,bottom-r)
            shape.cubicTo(right,bottom-r*(1-k),right-r*(1-k),bottom,right-r,bottom);shape.lineTo(left+r,bottom)
            shape.cubicTo(left+r*(1-k),bottom,left,bottom-r*(1-k),left,bottom-r);shape.lineTo(left,shoulder)
            shape.cubicTo(left,shoulder*2/3,left,shoulder/3,left-14,top);shape.closeSubpath();p.drawPath(shape)
        else:p.drawRoundedRect(rect,radius,radius)
        # Clip the shared pattern to the same silhouette as the preview body.
        p.save()
        if attached:p.setClipPath(shape)
        else:
            ambient_clip=QPainterPath();ambient_clip.addRoundedRect(rect,radius,radius);p.setClipPath(ambient_clip)
        self.ambient_renderer.paint(p,rect.adjusted(-14,0,14,0) if attached else rect,d,self.ambient_phase)
        p.restore()
        if compact:
            items=d.get('compactItems',[])
            secondary=QColor(text);secondary.setAlphaF(.66)
            font=QFont(d.get('fontFamily') or 'Noto Sans');font.setPixelSize(11);font.setWeight(QFont.Medium)
            clock_font=QFont(font);clock_font.setPixelSize(13);clock_font.setWeight(QFont.DemiBold)
            date_format={'ddd d':'%a {day}','ddd, MMM d':'%a, %b {day}','dd/MM':'%d/%m','MMM d':'%b {day}'}[d.get('dateFormat','ddd d')]
            now=datetime.datetime.now()
            left=now.strftime(date_format).format(day=now.day) if 'date' in items else ''
            timeformat=('%I:%M' if d.get('clockFormat')=='12h' else '%H:%M')+(':%S' if d.get('showSeconds') else '')+(' %p' if d.get('clockFormat')=='12h' else '')
            right=now.strftime(timeformat) if 'clock' in items else ''
            if d.get('clockFormat')=='12h':right=right.lstrip('0')
            p.setFont(font);left_width=p.fontMetrics().horizontalAdvance(left) if left else 0
            p.setPen(secondary);p.drawText(rect.adjusted(12,0,-12,0),Qt.AlignVCenter|Qt.AlignLeft,left)
            p.setFont(clock_font);right_width=p.fontMetrics().horizontalAdvance(right) if right else 0
            p.setPen(text);p.drawText(rect.adjusted(12,0,-12,0),Qt.AlignVCenter|Qt.AlignRight,right)
            p.setFont(font)
            metrics=[]
            if 'cpu' in items:metrics.append(('text',f"CPU {self.metrics['cpu']:.0f}%",accent))
            if 'memory' in items:metrics.append(('text',f"RAM {self.metrics['memory']:.1f}G",secondary))
            if 'activity' in items:metrics.append(('dot','',accent))
            battery_color=QColor('#ff453a') if self.metrics['percent']<=d.get('lowBatteryPercent',15) else QColor('#30d158') if self.metrics['charging'] else secondary
            if 'battery' in items and self.metrics['available']:
                metrics.append(('battery',str(self.metrics['percent'])+'%' if d.get('batteryPercentage',True) else '',battery_color))
            stats_font=QFont(font);stats_font.setWeight(QFont.Normal)
            def metric_width(entry):
                kind,value,col=entry
                p.setFont(stats_font if kind=='text' else font)
                return 5 if kind=='dot' else 20+(14 if self.metrics['charging'] else 0)+(3+p.fontMetrics().horizontalAdvance(value) if value else 0) if kind=='battery' else p.fontMetrics().horizontalAdvance(value)
            free_left=rect.left()+12+left_width+6
            free_right=rect.right()-12-right_width-6
            space=max(0,free_right-free_left)
            def total(entries):return sum(metric_width(entry) for entry in entries)+5*max(0,len(entries)-1)
            if total(metrics)>space:metrics=[entry for entry in metrics if entry[0]!='text']
            if total(metrics)>space:metrics=[entry for entry in metrics if entry[0]!='dot']
            if total(metrics)>space:metrics=[]
            widths=[metric_width(entry) for entry in metrics]
            group_width=sum(widths)+5*max(0,len(widths)-1)
            x=(free_left+free_right-group_width)/2
            self.last_layout={'battery_available':self.metrics['available'],'battery_percent':self.metrics['percent'],'status_center':x+group_width/2,'free_center':(free_left+free_right)/2,'width':width,'height':height,'left_end':free_left,'right_start':free_right,'metrics_width':group_width,'stats_visible':any(entry[0]=='text' for entry in metrics)}
            p.save();p.setClipRect(QRectF(free_left,rect.top(),max(0,free_right-free_left),36))
            for (kind,value,col),item_width in zip(metrics,widths):
                p.setFont(stats_font if kind=='text' else font)
                if kind=='text':
                    p.setPen(col);p.drawText(QRectF(x,rect.y(),item_width,36),Qt.AlignVCenter|Qt.AlignLeft,value)
                elif kind=='dot':
                    c=QColor(col);c.setAlphaF(.7);p.setPen(Qt.NoPen);p.setBrush(c);p.drawEllipse(QRectF(x,rect.center().y()-2.5,5,5))
                else:
                    y=rect.center().y()-5.5
                    p.setPen(QPen(col,1));p.setBrush(Qt.NoBrush);p.drawRoundedRect(QRectF(x,y+.5,17,10),2,2)
                    p.setPen(Qt.NoPen);p.setBrush(col);p.drawRoundedRect(QRectF(x+2,y+2.5,13*self.metrics['percent']/100,6),.8,.8);p.drawRoundedRect(QRectF(x+18,y+3.5,2,4),.8,.8)
                    text_x=x+20
                    if self.metrics['charging']:
                        # Same bolt SVG path used by Latto's Icon.qml, scaled to 11 px.
                        from PySide6.QtSvg import QSvgRenderer
                        svg=b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#30d158" d="M11 21h-1l1-7H7.5c-.88 0-.33-.75-.31-.78C8.48 10.94 10.42 7.54 13.01 3h1l-1 7h3.51c.4 0 .62.19.4.66C12.97 17.55 11 21 11 21z"/></svg>'
                        QSvgRenderer(svg).render(p,QRectF(text_x+3,rect.center().y()-5.5,11,11));text_x+=14
                    if value:p.setPen(QColor('#ff453a') if self.metrics['percent']<=d.get('lowBatteryPercent',15) else secondary);p.drawText(QRectF(text_x+3,rect.y(),item_width-(text_x-x)-3,36),Qt.AlignVCenter|Qt.AlignLeft,value)
                x+=item_width+5
            p.restore()
            glow=QLinearGradient(rect.x()+width*.175,0,rect.x()+width*.825,0)
            c=QColor(accent);c.setAlphaF(.4);glow.setColorAt(0,QColor('transparent'));glow.setColorAt(.5,c);glow.setColorAt(1,QColor('transparent'));p.setPen(Qt.NoPen);p.setBrush(glow);p.drawRect(QRectF(rect.x()+width*.175,rect.bottom()-1,width*.65,1))
        elif self.mode=='Music':
            art=QRectF(rect.x()+6,rect.y()+6,24,24)
            p.setPen(Qt.NoPen);p.setBrush(accent);p.drawRoundedRect(art,8,8)
            label(art,'♫',12,island,Qt.AlignCenter)
            music_font=QFont(d.get('fontFamily') or 'Noto Sans');music_font.setPixelSize(12);music_font.setWeight(QFont.Medium);p.setFont(music_font);p.setPen(text)
            p.drawText(rect.adjusted(40,0,-65,0),Qt.AlignVCenter|Qt.AlignLeft,'Night drive · demo track')
            for i,bar in enumerate([8,14,10,18,12]):
                p.setPen(Qt.NoPen);p.setBrush(accent);p.drawRoundedRect(QRectF(rect.right()-43+i*6,rect.center().y()-bar/2,3,bar),1.5,1.5)
        else:
            tabs=d.get('tabs',[]);names='   ·   '.join(TABS.get(t,t) for t in tabs[:5])
            label(rect.adjusted(20,8,-20,-68),names,8,accent,Qt.AlignCenter)
            for i,(title,value) in enumerate([('CPU',f"{self.metrics['cpu']:.0f}%"),('Memory',f"{self.metrics['memory']:.1f} GB"),('Battery',str(self.metrics['percent'])+'%' if self.metrics['available'] else 'Unavailable')]):
                card=QRectF(rect.x()+14+i*(width-28)/3,rect.y()+42,(width-40)/3,46)
                p.setPen(Qt.NoPen);p.setBrush(surface);p.drawRoundedRect(card,9,9)
                label(card.adjusted(11,1,-4,-20),title,8)
                label(card.adjusted(11,19,-4,0),value,11,accent,bold=True)
        p.restore()
        p.setPen(QColor('#555f4d' if paper else '#b1bda7'));p.setFont(QFont('JetBrains Mono',8))
        note=f'{effective_width(d)} PX / COMPACT' if compact else 'MUSIC / SAMPLE' if self.mode=='Music' else 'EXPANDED / SUMMARY'
        if self.render_scale<.99:note+=f' / {self.render_scale:.0%}'
        p.drawText(QRectF(0,h-24,w,20),Qt.AlignCenter,note)


class NavigationDelegate(QStyledItemDelegate):
    """Numbered navigation with one persistent selection marker."""
    def paint(self,painter,option,index):
        from PySide6.QtWidgets import QStyle
        painter.save();painter.setRenderHint(QPainter.Antialiasing)
        r=QRectF(option.rect).adjusted(0,1,0,-1)
        selected=bool(option.state & QStyle.State_Selected)
        hovered=bool(option.state & QStyle.State_MouseOver)
        if selected or hovered:
            painter.setPen(Qt.NoPen);painter.setBrush(QColor('#e5dccb' if selected else '#f0eee4'));painter.drawRoundedRect(r,4,4)
        if selected:
            painter.fillRect(QRectF(r.x(),r.y()+12,2,r.height()-24),QColor('#995b35'))
        font=QFont('JetBrains Mono');font.setPixelSize(9);painter.setFont(font);painter.setPen(QColor('#995b35' if selected else '#6a765d'))
        painter.drawText(r.adjusted(12,0,0,0),Qt.AlignVCenter|Qt.AlignLeft,f'{index.row()+1:02}')
        font=QFont('Noto Sans');font.setPixelSize(11);font.setWeight(QFont.Medium if selected else QFont.Normal);painter.setFont(font);painter.setPen(QColor('#292f23' if selected else '#58634e'))
        painter.drawText(r.adjusted(39,0,-4,0),Qt.AlignVCenter|Qt.AlignLeft,index.data())
        if option.state & QStyle.State_HasFocus:
            painter.setBrush(Qt.NoBrush);painter.setPen(QPen(QColor('#a5724c'),1));painter.drawRoundedRect(r.adjusted(1,1,-1,-1),4,4)
        painter.restore()

class PaletteTile(QPushButton):
    """A material sample, rather than a coloured label."""
    def __init__(self,name,values):
        super().__init__();self.name=name;self.values=values;self.ambient_renderer=AmbientRenderer(self)
        self.setCheckable(True);self.setObjectName("paletteTile");self.setMinimumHeight(90);self.setMinimumWidth(100)
        self.setCursor(Qt.PointingHandCursor);self.setAccessibleName(name+' palette');self.setToolTip(name+' · '+values['accentColor'])
    def paintEvent(self,event):
        p=QPainter(self);p.setRenderHint(QPainter.Antialiasing)
        r=QRectF(self.rect()).adjusted(1,1,-1,-1);v=self.values
        p.setBrush(QColor('#fffdf6'));p.setPen(QPen(QColor('#995b35' if self.isChecked() or self.hasFocus() else '#9ba589' if self.underMouse() else '#ccd2be'),1.5 if self.isChecked() else 1));p.drawRoundedRect(r,5,5)
        sample=QRectF(r.x()+8,r.y()+8,r.width()-16,40)
        p.setBrush(QColor(v['surfaceColor']));p.setPen(Qt.NoPen);p.drawRoundedRect(sample,3,3)
        pill=QRectF(sample.center().x()-min(40,sample.width()/2-5),sample.center().y()-9,min(80,sample.width()-10),18)
        p.setBrush(QColor(v['backgroundColor']));p.drawRoundedRect(pill,9 if v['cornerStyle']=='pill' else 4,9 if v['cornerStyle']=='pill' else 4)
        p.save();tile_clip=QPainterPath();tile_clip.addRoundedRect(pill,9,9);p.setClipPath(tile_clip)
        self.ambient_renderer.paint(p,pill,v,.18);p.restore()
        p.setBrush(QColor(v['accentColor']));p.drawEllipse(QRectF(pill.left()+8,pill.center().y()-2,4,4));p.setPen(QPen(QColor(v['textColor']),1.5));p.drawLine(pill.right()-23,pill.center().y(),pill.right()-9,pill.center().y())
        f=QFont('Noto Sans');f.setPixelSize(11);p.setFont(f);p.setPen(QColor('#30382a'));p.drawText(r.adjusted(9,51,-9,-14),Qt.AlignLeft|Qt.AlignVCenter,self.name)
        for i,key in enumerate(['backgroundColor','surfaceColor','accentColor','textColor']):
            p.setPen(Qt.NoPen);p.setBrush(QColor(v[key]));p.drawRoundedRect(QRectF(r.x()+9+i*14,r.bottom()-13,10,3),1,1)
        if self.isChecked():
            p.setPen(QPen(QColor('#91512c'),1.5));x=r.right()-13;y=r.bottom()-12;p.drawLine(x-4,y,x-1,y+3);p.drawLine(x-1,y+3,x+5,y-4)
        p.end()
