#!/usr/bin/python
"""Small allowlisted interface to local GNOME and Latto preferences."""
from pathlib import Path
import json,math,subprocess,sys,os,hashlib,hmac

PREFERENCES={
 'cameraDisabled':('org.gnome.desktop.privacy','disable-camera','bool'),
 'nightLight':('org.gnome.settings-daemon.plugins.color','night-light-enabled','bool'),
 'temperature':('org.gnome.settings-daemon.plugins.color','night-light-temperature','temperature'),
 'colorScheme':('org.gnome.desktop.interface','color-scheme','scheme'),
 'textScale':('org.gnome.desktop.interface','text-scaling-factor','scale'),
 'idleDelay':('org.gnome.desktop.session','idle-delay','delay'),
 'sleepAC':('org.gnome.settings-daemon.plugins.power','sleep-inactive-ac-type','sleep'),
 'sleepBattery':('org.gnome.settings-daemon.plugins.power','sleep-inactive-battery-type','sleep'),
 'showBanners':('org.gnome.desktop.notifications','show-banners','bool'),
 'lockNotifications':('org.gnome.desktop.notifications','show-in-lock-screen','bool'),
}

def validate_preference(name,value):
 if name not in PREFERENCES:raise ValueError('Unsupported preference')
 kind=PREFERENCES[name][2]
 valid=(kind=='bool' and type(value) is bool
  or kind=='temperature' and type(value) is int and 1700<=value<=6500
  or kind=='scheme' and isinstance(value,str) and value in {'default','prefer-dark','prefer-light'}
  or kind=='scale' and type(value) in {int,float} and math.isfinite(value) and .8<=value<=1.5
  or kind=='delay' and type(value) is int and value in {0,60,300,600,900,1800}
  or kind=='sleep' and isinstance(value,str) and value in {'suspend','nothing'})
 if not valid:raise ValueError('Unsupported value for '+name)
 return value

def preference_command(name,value):
 value=validate_preference(name,value);schema,key,_=PREFERENCES[name]
 literal=('true' if value else 'false') if type(value) is bool else str(value) if type(value) in {int,float} else "'"+value+"'"
 return ['gsettings','set',schema,key,literal]

def snapshot():
 from gi.repository import Gio
 source=Gio.SettingsSchemaSource.get_default();values={};writable={}
 for name,(schema,key,kind) in PREFERENCES.items():
  spec=source.lookup(schema,True)
  if not spec or not spec.has_key(key):continue
  settings=Gio.Settings.new_full(spec,None,None)
  values[name]=settings.get_value(key).unpack();writable[name]=settings.is_writable(key)
 return {'values':values,'writable':writable}

def set_preference(name,value):
 command=preference_command(name,value)
 reply=subprocess.run(command,capture_output=True,text=True,timeout=8)
 if reply.returncode or any(term in reply.stderr.lower() for term in ['failed','critical','error']):raise ValueError('GNOME could not apply this preference. Check the desktop session or policy.')
 from gi.repository import GLib
 schema,key,_=PREFERENCES[name]
 verify=subprocess.run(['gsettings','get',schema,key],capture_output=True,text=True,timeout=4)
 if verify.returncode:raise ValueError('Could not confirm the GNOME preference.')
 confirmed=GLib.Variant.parse(None,verify.stdout.strip(),None,None).unpack()
 if confirmed!=value:raise ValueError('GNOME did not confirm the requested preference.')
 return {'ok':True}

def latto_update(name,value,config=None,backups=None):
 sys.path.insert(0,str(Path.home()/'Apps/LattoStudio'))
 from model import ConfigStore,PRESETS
 path=config or Path(os.environ.get('XDG_CONFIG_HOME',Path.home()/'.config'))/'latto/config.json'
 store=ConfigStore(path,backups or Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'latto-studio/backups')
 if name=='preset':
  if not isinstance(value,str) or value not in PRESETS:raise ValueError('Unsupported palette')
  update=PRESETS[value]
 else:
  if name not in {'accentColor','cornerStyle','motionStyle','idleWidth','backgroundOpacity'}:raise ValueError('Unsupported island preference')
  update={name:value}
 store.update(update);return {'ok':True}

def profile_directory():
 return Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'latto-studio/profiles'

def profile_review(name,folder=None):
 sys.path.insert(0,str(Path.home()/'Apps/LattoStudio'))
 from model import Profiles
 profiles=Profiles(folder or profile_directory());path=profiles.path(name)
 if path.is_symlink():raise ValueError('Choose a profile saved directly in Studio.')
 if path.stat().st_size>131072:raise ValueError('Profile is too large.')
 first=path.read_bytes()
 if len(first)>131072:raise ValueError('Profile is too large.')
 settings=Profiles.read(path)
 if path.read_bytes()!=first:raise ValueError('Profile changed while opening it. Review it again.')
 return {'ok':True,'name':name,'digest':hashlib.sha256(first).hexdigest(),'settings':settings}

def profile_list(folder=None):
 sys.path.insert(0,str(Path.home()/'Apps/LattoStudio'))
 from model import Profiles
 profiles=Profiles(folder or profile_directory());names=[]
 for path in profiles.entries():
  try:
   profiles.path(path.stem)
   if not path.is_symlink():names.append(path.stem)
  except ValueError:continue
 return {'ok':True,'names':names}

def profile_apply(name,payload,folder=None,config=None,backups=None):
 if not isinstance(payload,dict) or not isinstance(payload.get('digest'),str):raise ValueError('Review a profile before applying it.')
 review=profile_review(name,folder)
 if not hmac.compare_digest(review['digest'],payload['digest']):raise ValueError('This profile changed. Review it again before applying.')
 sys.path.insert(0,str(Path.home()/'Apps/LattoStudio'))
 from model import ConfigStore
 path=config or Path(os.environ.get('XDG_CONFIG_HOME',Path.home()/'.config'))/'latto/config.json'
 store=ConfigStore(path,backups or Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'latto-studio/backups')
 store.update(review['settings'])
 return {'ok':True}

def main():
 try:
  action=sys.argv[1] if len(sys.argv)>1 else 'snapshot'
  if action=='snapshot':reply=snapshot()
  elif action=='profiles' and len(sys.argv)==2:reply=profile_list()
  elif action=='profile-review' and len(sys.argv)==3:reply=profile_review(sys.argv[2])
  elif action=='profile' and len(sys.argv)==4:reply=profile_apply(sys.argv[2],json.loads(sys.argv[3]))
  elif action in {'set','latto'} and len(sys.argv)==4:
   name=sys.argv[2];value=json.loads(sys.argv[3]);reply=set_preference(name,value) if action=='set' else latto_update(name,value)
  else:raise ValueError('Unknown desktop action')
  print(json.dumps(reply,allow_nan=False))
 except Exception as error:
  print(json.dumps({'ok':False,'error':str(error)},allow_nan=False))
if __name__=='__main__':main()
