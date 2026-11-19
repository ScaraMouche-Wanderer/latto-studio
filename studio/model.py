from pathlib import Path
import json,re,os,tempfile,fcntl,datetime,shutil,stat
TABS={'media':'Media','stats':'Statistics','system':'System','timers':'Timers','calendar':'Calendar','overview':'Overview','notifications':'Notifications','clipboard':'Clipboard','codex':'Codex'}
ITEMS={'date':'Date','clock':'Clock','battery':'Battery','activity':'Activity dot','cpu':'CPU percentage','memory':'RAM usage'}
DEFAULTS={'accentColor':'#0a84ff','backgroundColor':'#000000','surfaceColor':'#141416','textColor':'#f5f5f7','backgroundOpacity':1.0,'borderOpacity':0.08,'idleWidth':260,'topOffset':44,'cornerStyle':'pill','motionStyle':'smooth','compactItems':['date','clock','battery','activity'],'tabs':['media','notifications','stats','timers','clipboard','calendar','overview','codex'],'hoverToExpand':True,'mediaAlwaysShown':False,'nowPlayingDuration':4000,'fontFamily':''}
PRESETS={
 'Midnight':{'backgroundColor':'#000000','surfaceColor':'#141416','textColor':'#f5f5f7','accentColor':'#c4a7e7','backgroundOpacity':1.0,'cornerStyle':'pill'},
 'Violet dusk':{'backgroundColor':'#191724','surfaceColor':'#26233a','textColor':'#e0def4','accentColor':'#c4a7e7','backgroundOpacity':0.97,'cornerStyle':'pill'},
 'Graphite':{'backgroundColor':'#171c22','surfaceColor':'#252e37','textColor':'#edf4f5','accentColor':'#86d4bd','backgroundOpacity':1.0,'cornerStyle':'rounded'},
 'Frost':{'backgroundColor':'#edf1f9','surfaceColor':'#dbe2ef','textColor':'#172239','accentColor':'#5468d4','backgroundOpacity':0.94,'cornerStyle':'pill'}
}

DEFAULTS.update({
 'expandedLayout':'tabs',
 'clipboardEnabled':False,'clipboardHistoryLimit':100,'compactAlwaysVisible':False,'hoverExpandDelay':600,'hoverCloseDelay':420,'edgeReveal':False,'calendarEnabled':False,'clockFormat':'24h','showSeconds':False,'dateFormat':'ddd d','batteryPercentage':True,
 'pomodoroFocusMinutes':25,'pomodoroBreakMinutes':5,'pomodoroLongBreakMinutes':15,
 'pomodoroRounds':4,'pomodoroDnd':True,'timerSound':True,
 'privacyIndicators':True,'capsLockIndicator':True,'bluetoothAlerts':True,
 'codexTypingEnabled':True,
 'lowBatteryPercent':15,'hudDuration':1500,'statsInterval':2000,
})
PRESETS.update({
 'Ocean':{'backgroundColor':'#0b1925','surfaceColor':'#152c3c','textColor':'#e4f5ff','accentColor':'#7dd3fc','backgroundOpacity':1.0,'cornerStyle':'pill'},
 'Ember':{'backgroundColor':'#211812','surfaceColor':'#34251c','textColor':'#fff1df','accentColor':'#f5b980','backgroundOpacity':1.0,'cornerStyle':'rounded'},
 'Rose':{'backgroundColor':'#241821','surfaceColor':'#382435','textColor':'#ffedf7','accentColor':'#f4a5cb','backgroundOpacity':1.0,'cornerStyle':'pill'},
 'Matcha':{'backgroundColor':'#18201a','surfaceColor':'#27352a','textColor':'#eff8e9','accentColor':'#bad69b','backgroundOpacity':1.0,'cornerStyle':'rounded'},
})
# Classic palettes explicitly turn the ambient motif off.
for _palette in PRESETS.values():
 _palette.update(ambientStyle='off',ambientIntensity=.55,ambientSpeed=1.0)
DEFAULTS.update(ambientStyle='off',ambientIntensity=.55,ambientSpeed=1.0)
CINEMA_NOTES={
 'Halloween':'Jack-o-lantern eyes and slowly rising embers.',
 'Haunted':'Layered spectral mint/violet filament veils.',
 'Prism Flow':'Dense rainbow filament sheets crossing and morphing between shapes.',
 'Odyssey':'Deterministic stars, orbiting light and a drifting nebula.',
 'Arc Reactor':'Breathing orbital filament bundles around a cyan core.',
 'Crimson Web':'Overlapping crimson lace fans that twist and open.',
 'Neon Pulse':'Interlocking cyan/magenta strand bundles with traveling light.',
 'Aurora Rush':'Flowing emerald, cyan, violet and pink clouds of light.',
 'Solar Flare':'Layered orange-gold orbital strands with flowing deformation.',
 'Candy Surge':'Twisting fuchsia/aqua filament fans with moving highlights.',
}
_CINEMA=[
 ('Halloween','#190f15','#2c1920','#fff0d5','#ffac50','embers',.65,.8),
 ('Haunted','#10191d','#1c2b30','#e8fff4','#8de2b3','haunted',.6,.65),
 ('Prism Flow','#111322','#21253d','#f5f1ff','#cfb1ff','prism',.65,1.0),
 ('Odyssey','#101328','#1c2443','#edf1ff','#aab8ff','odyssey',.7,.6),
 ('Arc Reactor','#0c1a21','#18303b','#e1faff','#72e5ff','reactor',.6,1.0),
 ('Crimson Web','#200e1b','#361e32','#fff0f5','#ff8095','web',.7,.8),
 ('Neon Pulse','#080b21','#171a39','#f7f8ff','#31eaff','neon',.8,1.1),
 ('Aurora Rush','#070b18','#151c32','#f2f7ff','#72efd2','aurora',.8,1.2),
 ('Solar Flare','#1a0b13','#341521','#fff5df','#ffb63e','solar',.8,1.0),
 ('Candy Surge','#180b28','#2b173f','#fff2ff','#ff67e2','candy',.8,1.15),
]
for _name,_bg,_surface,_text,_accent,_style,_intensity,_speed in _CINEMA:
 PRESETS[_name]=dict(backgroundColor=_bg,surfaceColor=_surface,textColor=_text,accentColor=_accent,
  backgroundOpacity=1.0,cornerStyle='pill',ambientStyle=_style,ambientIntensity=_intensity,ambientSpeed=_speed)
LAYOUTS={
 'Minimal':{'compactItems':['date','clock'],'idleWidth':200},
 'Balanced':{'compactItems':['date','clock','battery','activity'],'idleWidth':230},
 'Monitor':{'compactItems':['date','clock','cpu','memory','battery'],'idleWidth':340,'mediaAlwaysShown':False},
}

def decode_json(text):
 def reject_constant(value):raise ValueError('JSON must use finite numbers; '+value+' is not supported.')
 return json.loads(text,parse_constant=reject_constant)


def effective_width(data):
 items=data.get('compactItems',DEFAULTS['compactItems'])
 floor=320 if 'cpu' in items and 'memory' in items else 280 if 'cpu' in items or 'memory' in items else 180
 # Extra clock characters need room beside CPU/RAM and battery.
 if 'date' in items and data.get('dateFormat')=='ddd, MMM d':floor+=30
 if 'clock' in items:floor+= (20 if data.get('clockFormat')=='12h' else 0)+(18 if data.get('showSeconds') else 0)
 return max(floor,min(480,data.get('idleWidth',260)))

def validate(data):
 d={**DEFAULTS,**data}
 for key in ['accentColor','backgroundColor','surfaceColor','textColor']:
  if not isinstance(d[key],str) or not re.fullmatch(r'#[0-9a-fA-F]{6}',d[key]):raise ValueError('Use a six-digit hex colour, such as #c4a7e7.')
 for key,low,high in [('clipboardHistoryLimit',50,100),('hoverExpandDelay',140,1000),('hoverCloseDelay',180,1000),('idleWidth',180,480),('topOffset',32,160),('nowPlayingDuration',1000,12000),('pomodoroFocusMinutes',1,180),('pomodoroBreakMinutes',1,60),('pomodoroLongBreakMinutes',1,120),('pomodoroRounds',1,12),('lowBatteryPercent',5,50),('hudDuration',500,6000),('statsInterval',1000,10000)]:
  if type(d[key]) is not int or not low<=d[key]<=high:raise ValueError(key+' is outside its supported range.')
 for key,low,high in [('backgroundOpacity',0.35,1.0),('borderOpacity',0,0.4),('ambientIntensity',0,.8),('ambientSpeed',.25,2)]:
  if type(d[key]) not in {int,float} or not low<=d[key]<=high:raise ValueError(key+' is outside its supported range.')
 for key,choices in [('ambientStyle',{'off','embers','haunted','prism','odyssey','reactor','web','neon','aurora','solar','candy'}),('cornerStyle',{'pill','rounded'}),('motionStyle',{'smooth','snappy','reduced'}),('expandedLayout',{'tabs','summary'}),('clockFormat',{'24h','12h'}),('dateFormat',{'ddd d','ddd, MMM d','dd/MM','MMM d'})]:
  if not isinstance(d[key],str) or d[key] not in choices:raise ValueError('Unsupported '+key)
 for key,choices in [('tabs',TABS),('compactItems',ITEMS)]:
  value=d[key]
  if not isinstance(value,list) or not value or any(not isinstance(v,str) or v not in choices for v in value) or len(value)!=len(set(value)):raise ValueError('Choose at least one unique '+('tab' if key=='tabs' else 'compact indicator')+'.')
 for key in ['clipboardEnabled','compactAlwaysVisible','edgeReveal','hoverToExpand','mediaAlwaysShown','calendarEnabled','showSeconds','batteryPercentage','pomodoroDnd','timerSound','privacyIndicators','capsLockIndicator','bluetoothAlerts','codexTypingEnabled']:
  if type(d[key]) is not bool:raise ValueError('Invalid toggle value')
 if not isinstance(d['fontFamily'],str) or len(d['fontFamily'])>120:raise ValueError('Invalid font family')
 return d

class ConfigStore:
 def __init__(self,path,backups):
  self.path=Path(path);self.backups=Path(backups);self.original=self.read();self.backed_up=False
 def read(self):
  if not self.path.exists():return {}
  data=decode_json(self.path.read_text(encoding="utf-8"))
  if not isinstance(data,dict):raise ValueError('Latto configuration must be a JSON object.')
  return data
 def _write(self,data):
  self.path.parent.mkdir(parents=True,exist_ok=True)
  if not self.backed_up and self.path.exists():
   self.backups.mkdir(parents=True,exist_ok=True)
   stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f');target=self.backups/('config-'+stamp+'.json');shutil.copy2(self.path,target);target.chmod(0o600)
   for p in sorted(self.backups.glob('config-*.json'))[:-10]:p.unlink()
   self.backed_up=True
  fd,name=tempfile.mkstemp(prefix='.studio-',suffix='.json',dir=self.path.parent)
  try:
   with os.fdopen(fd,'w') as file:json.dump(data,file,indent=2,ensure_ascii=False);file.write('\n');file.flush();os.fsync(file.fileno())
   os.chmod(name,0o600);os.replace(name,self.path)
  finally:
   if os.path.exists(name):os.unlink(name)
 def update(self,updates):
  if any(key not in DEFAULTS for key in updates):raise ValueError('Studio only changes its supported settings.')
  self.path.parent.mkdir(parents=True,exist_ok=True)
  with (self.path.parent/'.studio.lock').open('a') as lock:
   fcntl.flock(lock,fcntl.LOCK_EX);data=self.read();validate({**data,**updates});data.update(updates);self._write(data)
  return data
 def undo_session(self):
  self.path.parent.mkdir(parents=True,exist_ok=True)
  with (self.path.parent/'.studio.lock').open('a') as lock:
   fcntl.flock(lock,fcntl.LOCK_EX);data=self.read()
   for key in DEFAULTS:
    # JsonAdapter keeps old values for removed keys, so restore defaults explicitly.
    data[key]=self.original.get(key,DEFAULTS[key])
   validate(data);self._write(data)
  return data


class Profiles:
 """Local portable profiles contain only Studio-managed values."""
 def __init__(self,folder):self.folder=Path(folder)
 def entries(self):return sorted(self.folder.glob('*.json'),key=lambda p:p.stem.lower()) if self.folder.exists() else []
 def path(self,name):
  name=name.strip()
  if not re.fullmatch(r"[\w -]{1,48}",name):raise ValueError('Use 1–48 letters, numbers, spaces, underscores or dashes.')
  return self.folder/(name+'.json')
 def save(self,name,settings):
  target=self.path(name);data=validate({key:value for key,value in settings.items() if key in DEFAULTS});self.folder.mkdir(parents=True,exist_ok=True)
  self.export(target,data);return target
 @staticmethod
 def export(path,settings):
  selected={key:value for key,value in settings.items() if key in DEFAULTS};validate(selected)
  payload={'format':'latto-studio','version':1,'settings':selected}
  path=Path(path);fd,temp=tempfile.mkstemp(prefix='.profile-',dir=path.parent)
  try:
   with os.fdopen(fd,'w') as file:json.dump(payload,file,indent=2);file.write('\n');file.flush();os.fsync(file.fileno())
   os.chmod(temp,0o600);os.replace(temp,path)
  finally:
   if os.path.exists(temp):os.unlink(temp)
 @staticmethod
 def read(path):
  path=Path(path)
  fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK)
  with os.fdopen(fd,'rb') as file:
   info=os.fstat(file.fileno())
   if not stat.S_ISREG(info.st_mode):raise ValueError('Choose a regular JSON profile file.')
   if info.st_size>131072:raise ValueError('Profile is too large.')
   content=file.read(131073)
  if len(content)>131072:raise ValueError('Profile is too large.')
  payload=decode_json(content.decode('utf-8-sig'))
  if not isinstance(payload,dict) or payload.get('format')!='latto-studio' or type(payload.get('version')) is not int or payload.get('version')!=1:raise ValueError('Choose a Latto Studio profile (version 1).')
  values=payload.get('settings')
  if not isinstance(values,dict) or not values or any(key not in DEFAULTS for key in values):raise ValueError('Profile contains unsupported settings.')
  return validate(values)
