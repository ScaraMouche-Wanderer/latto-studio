"""Cinematic theme invariants and real Studio edit/preview workflows, isolated from live settings."""
import os,json,math
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
import pytest
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QColor
from PySide6.QtTest import QTest
from model import DEFAULTS,PRESETS,CINEMA_NOTES,Profiles,validate
from studio import Studio,STYLE
from widgets import Preview

@pytest.fixture(scope='module')
def app():
    app=QApplication.instance() or QApplication([])
    app.setStyle('Fusion');app.setStyleSheet(STYLE)
    return app

@pytest.mark.parametrize('name',list(CINEMA_NOTES))
def test_theme_flow(app,tmp_path,name):
    path=tmp_path/'config.json';path.write_text(json.dumps({'unmanaged':{'keep':True},'notificationsEnabled':False,'tabs':['stats','media'],'motionStyle':'reduced'}))
    original=path.read_bytes();studio=Studio(path,tmp_path/'backups',monitor=False);studio.show();app.processEvents()
    studio.live.setChecked(False);studio.preset_buttons[name].click();app.processEvents()
    assert path.read_bytes()==original
    data=studio.collect();assert data['ambientStyle']==PRESETS[name]['ambientStyle']
    assert data['tabs']==['stats','media'] and data['motionStyle']=='reduced'
    assert not studio.preview.ambient_timer.isActive()
    assert sum(button.isChecked() for button in studio.preset_buttons.values())==1
    studio.apply();assert json.loads(path.read_text())['unmanaged']=={'keep':True}
    profile=tmp_path/'profile.json';Profiles.export(profile,data);assert Profiles.read(profile)['ambientStyle']==data['ambientStyle']
    for mode in ['Compact','Music','Expanded']:
        studio.preview.set_mode(mode);app.processEvents();assert not studio.preview.grab().isNull()
    studio.controls['motionStyle'].setCurrentIndex(studio.controls['motionStyle'].findData('smooth'))
    app.processEvents();phase=studio.preview.ambient_phase;QTest.qWait(140)
    assert studio.preview.ambient_phase!=phase and studio.preview.ambient_timer.isActive()
    studio.preview.hide();assert not studio.preview.ambient_timer.isActive()
    studio.preview.show();assert studio.preview.ambient_timer.isActive()
    studio.controls['ambientIntensity'][0].setValue(0);assert not studio.preview.ambient_timer.isActive()
    studio.use_preset('Graphite');assert studio.collect()['ambientStyle']=='off'
    studio.undo_changes();assert json.loads(path.read_text())['unmanaged']=={'keep':True}
    assert studio.collect()['ambientStyle']=='off'
    studio.close();app.processEvents()

@pytest.mark.parametrize('name',list(CINEMA_NOTES))
def test_shared_geometry_is_finite_deterministic_and_animated(app,name):
    preview=Preview();d=PRESETS[name];renderer=preview.ambient_renderer
    for width,height in [(180,36),(260,36),(600,276),(700,520)]:
        frames=[]
        for phase in [0,.23,.56,.99]:
            shapes=renderer.geometry(d['ambientStyle'],width,height,phase,d['ambientIntensity'],d['accentColor']);assert shapes
            assert shapes==renderer.geometry(d['ambientStyle'],width,height,phase,d['ambientIntensity'],d['accentColor'])
            for shape in shapes:
                assert 0<=shape['alpha']<=.8 and QColor(shape['color']).isValid()
                values=[v for point in shape['points'] for v in point] if shape['kind']=='path' else [shape['x'],shape['y'],shape.get('r',shape.get('rx')),shape.get('ry',0),shape.get('rotation',0)]
                assert all(math.isfinite(value) for value in values)
            frames.append(shapes)
        assert frames[0]!=frames[1]
    assert renderer.geometry('off',600,200,0,.8,'#ffffff')==[]
    assert renderer.geometry(d['ambientStyle'],600,200,0,0,d['accentColor'])==[]
    preview.close()

@pytest.mark.parametrize('key,value',[
    ('ambientStyle','unknown'),('ambientStyle',True),('ambientIntensity',float('nan')),
    ('ambientIntensity',float('inf')),('ambientIntensity',True),('ambientIntensity',.81),
    ('ambientIntensity',-.1),('ambientSpeed',float('nan')),('ambientSpeed',True),
    ('ambientSpeed',.24),('ambientSpeed',2.01),
])
def test_reject_invalid_effect_settings(key,value):
    with pytest.raises(ValueError):validate({key:value})

def test_old_profiles_default_to_quiet(tmp_path):
    p=tmp_path/'old.json';p.write_text(json.dumps({'format':'latto-studio','version':1,'settings':{'idleWidth':260}}))
    assert Profiles.read(p)['ambientStyle']=='off'


def test_geometry_loop_is_seamless(app):
    preview=Preview();renderer=preview.ambient_renderer
    def numbers(value):
        if isinstance(value,(float,int)):return [float(value)]
        if isinstance(value,list):return [v for x in value for v in numbers(x)]
        if isinstance(value,dict):return [v for k in sorted(value) for v in numbers(value[k])]
        return []
    for name in CINEMA_NOTES:
        d=PRESETS[name]
        a=numbers(renderer.geometry(d['ambientStyle'],600,276,0,d['ambientIntensity'],d['accentColor']))
        b=numbers(renderer.geometry(d['ambientStyle'],600,276,1,d['ambientIntensity'],d['accentColor']))
        assert len(a)==len(b) and max(abs(x-y) for x,y in zip(a,b))<1e-8,name
    preview.close()

@pytest.mark.parametrize('name',list(CINEMA_NOTES))
def test_max_strength_preserves_sampled_text_contrast(app,name):
    from PySide6.QtGui import QImage,QPainter
    from PySide6.QtCore import QRectF
    def luminance(color):
        channels=[color.redF(),color.greenF(),color.blueF()]
        linear=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in channels]
        return sum(a*b for a,b in zip(linear,[.2126,.7152,.0722]))
    preview=Preview();data={**PRESETS[name],'ambientIntensity':.8};fg=luminance(QColor(data['textColor']))
    protected=data['ambientStyle'] in ['aurora','prism','neon','candy','haunted','web','reactor','solar']
    if protected:
        _assert_protected_surfaces(data,luminance)
    for width,height in [(260,36),(600,276)]:
        if protected and height>36:continue
        for phase in [0,.23,.56,.83]:
            image=QImage(width,height,QImage.Format_RGB32);image.fill(QColor(data['backgroundColor']))
            painter=QPainter(image);painter.setRenderHint(QPainter.Antialiasing)
            preview.ambient_renderer.paint(painter,QRectF(0,0,width,height),data,phase);painter.end()
            for y in ([18] if protected else range(0,height,3)):
                for x in (list(range(12,85,3))+list(range(175,248,3)) if protected else range(0,width,3)):
                    bg=luminance(image.pixelColor(x,y));ratio=(max(fg,bg)+.05)/(min(fg,bg)+.05)
                    if protected:
                        # Date/clock use secondary text in compact mode.
                        text=QColor(data['textColor']);background=image.pixelColor(x,y)
                        secondary=QColor.fromRgbF(*[a*.66+b*.34 for a,b in zip([text.redF(),text.greenF(),text.blueF()],[background.redF(),background.greenF(),background.blueF()])])
                        ratio=(luminance(secondary)+.05)/(bg+.05)
                    assert ratio>=4.5,(name,width,height,phase,ratio)
    preview.close()


BUNDLE_STYLES=['prism','neon','candy','haunted','web','reactor','solar']

def _assert_protected_surfaces(data,lum):
    text=QColor(data['textColor']);surface=QColor(data['surfaceColor']);base=QColor(data['backgroundColor'])
    secondary=QColor.fromRgbF(*[a*.66+b*.34 for a,b in zip([text.redF(),text.greenF(),text.blueF()],[surface.redF(),surface.greenF(),surface.blueF()])])
    assert (lum(secondary)+.05)/(lum(surface)+.05)>=4.5
    # Actual QuickToggle backing is 78% base; assume white art underneath.
    background=QColor.fromRgbF(*[v*.78+.22 for v in [base.redF(),base.greenF(),base.blueF()]])
    foreground=QColor.fromRgbF(*[a*.82+b*.18 for a,b in zip([text.redF(),text.greenF(),text.blueF()],[background.redF(),background.greenF(),background.blueF()])])
    assert (lum(foreground)+.05)/(lum(background)+.05)>=4.5

@pytest.mark.parametrize('style',BUNDLE_STYLES)
def test_bundles_remain_fine_and_dense_at_all_sizes(app,style):
    preview=Preview();renderer=preview.ambient_renderer
    for width,height in [(180,36),(600,276),(700,640)]:
        shapes=renderer.geometry(style,width,height,.23,.8,'#ffffff')
        filaments=[s for s in shapes if s.get('role')=='filament']
        families={s['family'] for s in filaments}
        assert len(families)>=3
        for family in families:
            strands=[s for s in filaments if s['family']==family]
            assert len(strands)>=12
            assert all(0<s['width']<=1 for s in strands)
            # A strand fan must contain neighboring threads, not isolated waves.
            a,b=strands[:2]
            assert max(math.dist(p,q) for p,q in zip(a['points'],b['points']))<7
        for shape in filaments:
            g=shape['gradient'];stops=g['stops']
            assert all(math.isfinite(g[k]) for k in ['x1','y1','x2','y2'])
            assert all(QColor(c).isValid() and 0<=a<=1 and 0<=f<=1 for f,c,a in stops)
            assert stops[0][2]==stops[-1][2]==0
    preview.close()

def _crosses(a,b):
    def side(p,q,r):return (q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
    return any(side(p,q,r)*side(p,q,s)<0 and side(r,s,p)*side(r,s,q)<0
               for p,q in zip(a,a[1:]) for r,s in zip(b,b[1:]))

@pytest.mark.parametrize('style',BUNDLE_STYLES)
def test_bundle_families_cross_and_morph_without_scene_cuts(app,style):
    preview=Preview();renderer=preview.ambient_renderer;frames=[]
    for phase in [0,.23,.56]:
        shapes=renderer.geometry(style,600,276,phase,.8,'#ffffff')
        representatives=[next(s['points'] for s in shapes if s.get('role')=='filament' and s['family']==g) for g in range(3)]
        assert sum(_crosses(a,b) for i,a in enumerate(representatives) for b in representatives[i+1:])>=2
        frames.append(representatives)
    assert frames[0]!=frames[1]!=frames[2]
    # A single timer tick cannot teleport the bundle or replace its topology.
    a=renderer.geometry(style,600,276,.23,.8,'#ffffff')
    b=renderer.geometry(style,600,276,.232,.8,'#ffffff')
    assert len(a)==len(b)
    for x,y in zip(a,b):
        if x.get('role')=='filament':assert max(math.dist(p,q) for p,q in zip(x['points'],y['points']))<6
    preview.close()


def test_aurora_has_soft_fields_and_protected_text_surfaces(app):
    from PySide6.QtGui import QImage,QPainter
    from PySide6.QtCore import QRectF
    preview=Preview();data=PRESETS['Aurora Rush'];renderer=preview.ambient_renderer
    shapes=renderer.geometry('aurora',600,276,.12,.8,data['accentColor'])
    assert shapes and all(s['kind']=='cloud' for s in shapes)
    assert all(s['rx']>0 and s['ry']>0 and 0<s['softness']<1 for s in shapes)
    def lum(color):
        channels=[color.redF(),color.greenF(),color.blueF()]
        return sum((v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4)*weight for v,weight in zip(channels,[.2126,.7152,.0722]))
    # The real Overview card/tab labels use opaque surface backgrounds.
    assert (lum(QColor(data['textColor']))+.05)/(lum(QColor(data['surfaceColor']))+.05)>=7
    # Exposed toggle captions have a local backing; test worst-case white light.
    backing=QColor(data['backgroundColor']);fg=QColor(data['textColor'])
    background=QColor.fromRgbF(*[v*.78+.22 for v in [backing.redF(),backing.greenF(),backing.blueF()]])
    foreground=QColor.fromRgbF(*[a*.82+b*.18 for a,b in zip([fg.redF(),fg.greenF(),fg.blueF()],[background.redF(),background.greenF(),background.blueF()])])
    assert (lum(foreground)+.05)/(lum(background)+.05)>=4.5
    # Compact date/clock remain readable over the quieter compact blend.
    for phase in [0,.23,.56,.83]:
        image=QImage(260,36,QImage.Format_RGB32);image.fill(backing)
        painter=QPainter(image);renderer.paint(painter,QRectF(0,0,260,36),data,phase);painter.end()
        for x in list(range(12,85,3))+list(range(175,248,3)):
            bg=image.pixelColor(x,18)
            secondary=QColor.fromRgbF(*[a*.66+b*.34 for a,b in zip([fg.redF(),fg.greenF(),fg.blueF()],[bg.redF(),bg.greenF(),bg.blueF()])])
            assert (lum(secondary)+.05)/(lum(bg)+.05)>=4.5
    preview.close()
