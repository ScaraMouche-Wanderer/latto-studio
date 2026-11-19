"""Paint the live island's shared vector geometry in Studio, without a second effect implementation."""
from pathlib import Path
from PySide6.QtQml import QJSEngine,QJSValue
from PySide6.QtGui import QColor,QPainterPath,QPen,QRadialGradient,QBrush,QLinearGradient
from PySide6.QtCore import Qt,QRectF

SOURCE=Path(__file__).with_name('AmbientField.js')
class AmbientRenderer:
    def __init__(self,parent):
        self.engine=QJSEngine(parent)
        result=self.engine.evaluate(SOURCE.read_text().replace('.pragma library',''))
        if result.isError():raise RuntimeError(result.toString())
        self.function=self.engine.globalObject().property('frame')
    def geometry(self,style,width,height,phase,intensity,accent):
        values=[QJSValue(v) for v in [style,float(width),float(height),float(phase),float(intensity),accent]]
        result=self.function.call(values)
        if result.isError():raise RuntimeError(result.toString())
        return result.toVariant()
    def paint(self,painter,rect,data,phase=0):
        style=data.get('ambientStyle','off')
        if style=='off':return
        painter.save();painter.translate(rect.x(),rect.y())
        for shape in self.geometry(style,rect.width(),rect.height(),phase,data.get('ambientIntensity',.55),data.get('accentColor','#c4a7e7')):
            if shape['kind']=='cloud':
                painter.save();painter.translate(shape['x'],shape['y']);painter.rotate(shape['rotation']*180/3.141592653589793)
                painter.scale(shape['rx'],shape['ry']);gradient=QRadialGradient(0,0,1)
                for stop,alpha in [(0,1),(shape['softness'],.62),(.68,.16),(1,0)]:
                    color=QColor(shape['color']);color.setAlphaF(alpha);gradient.setColorAt(stop,color)
                painter.setOpacity(shape['alpha']);painter.setPen(Qt.NoPen);painter.setBrush(QBrush(gradient))
                painter.drawEllipse(QRectF(-1,-1,2,2));painter.restore();continue
            gradient=shape.get('gradient')
            if gradient:
                painter.save();g=QLinearGradient(gradient['x1'],gradient['y1'],gradient['x2'],gradient['y2'])
                for stop,col,alpha in gradient['stops']:
                    c=QColor(col);c.setAlphaF(alpha);g.setColorAt(stop,c)
                painter.setOpacity(shape['alpha']);pen=QPen(QBrush(g),shape['width']);pen.setCapStyle(Qt.RoundCap);pen.setJoinStyle(Qt.RoundJoin)
                painter.setPen(pen);painter.setBrush(Qt.NoBrush)
                path=QPainterPath();points=shape['points']
                if points:
                    path.moveTo(*points[0])
                    for point in points[1:]:path.lineTo(*point)
                    painter.drawPath(path)
                painter.restore();continue
            color=QColor(shape['color']);color.setAlphaF(shape['alpha'])
            painter.setPen(Qt.NoPen if shape['fill'] else QPen(color,shape['width']))
            painter.setBrush(color if shape['fill'] else Qt.NoBrush)
            if shape['kind']=='circle':
                r=shape['r'];painter.drawEllipse(QRectF(shape['x']-r,shape['y']-r,r*2,r*2))
            else:
                path=QPainterPath();points=shape['points']
                if not points:continue
                path.moveTo(*points[0])
                for point in points[1:]:path.lineTo(*point)
                if shape['fill']:path.closeSubpath()
                painter.drawPath(path)
        painter.restore()
