#!/usr/bin/python
"""Local hardware readings and allow-listed desktop actions. No network access."""
from pathlib import Path
import json,subprocess,shutil,sys,os,math

def number(path,default=0):
 try:
  value=float(path.read_text().strip());return value if math.isfinite(value) and value>=0 else default
 except (OSError,ValueError):return default

def keyboard(sysroot=Path('/sys')):
 for p in sorted((sysroot/'class/leds').glob('*kbd_backlight')):
  maximum=int(number(p/'max_brightness'));current=int(number(p/'brightness'))
  if maximum>0:return {'available':True,'device':p.name,'current':min(current,maximum),'maximum':maximum}
 return {'available':False,'device':'','current':0,'maximum':0}

def battery(sysroot=Path('/sys')):
 for p in sorted((sysroot/'class/power_supply').glob('BAT*')):
  try:status=(p/'status').read_text().strip()
  except OSError:continue
  percent=min(100,number(p/'capacity'));watts=number(p/'power_now')/1e6
  if not watts:watts=number(p/'current_now')*number(p/'voltage_now')/1e12
  now=number(p/'energy_now');full=number(p/'energy_full');design=number(p/'energy_full_design');hours=None
  if watts>0.1 and now and full:
   if status=='Discharging':hours=now/1e6/watts
   elif status=='Charging':hours=max(0,full-now)/1e6/watts
  return {'available':True,'percent':percent,'status':status,'watts':round(watts,2),'hours':round(hours,2) if hours is not None else None,'health':round(min(100,full/design*100),1) if full and design else None}
 return {'available':False,'percent':0,'status':'Unavailable','watts':0,'hours':None,'health':None}

def system_info(procroot=Path('/proc'),storage_path=None):
 result={'uptimeSeconds':None,'storageFreeGiB':None,'storageTotalGiB':None,'osName':'Linux','kernel':os.uname().release}
 try:
  for line in Path('/etc/os-release').read_text().splitlines():
   if line.startswith('PRETTY_NAME='):result['osName']=line.split('=',1)[1].strip().strip(chr(34))
 except OSError:pass
 try:
  uptime=float((procroot/'uptime').read_text().split()[0])
  if math.isfinite(uptime) and uptime>=0:result['uptimeSeconds']=int(uptime)
 except (OSError,ValueError,IndexError):pass
 try:
  usage=shutil.disk_usage(storage_path or Path.home())
  result.update(storageFreeGiB=round(usage.free/1073741824,1),storageTotalGiB=round(usage.total/1073741824,1))
 except OSError:pass
 return result

def profiles():
 if not shutil.which('powerprofilesctl'):return {'active':'','available':[]}
 try:
  p=subprocess.run(['powerprofilesctl','get'],capture_output=True,text=True,timeout=3)
  q=subprocess.run(['powerprofilesctl','list'],capture_output=True,text=True,timeout=3)
  available=[s for s in ['power-saver','balanced','performance'] if any(line.strip().lstrip('* ').startswith(s+':') for line in q.stdout.splitlines())]
  return {'active':p.stdout.strip() if p.returncode==0 else '', 'available':available}
 except (OSError,subprocess.TimeoutExpired):return {'active':'','available':[]}

def action_command(action,value='',sysroot=Path('/sys')):
 if action=='keyboard':
  info=keyboard(sysroot)
  if not info['available']:raise ValueError('Keyboard backlight is unavailable')
  try:level=int(value)
  except (ValueError,TypeError):raise ValueError('Invalid keyboard brightness')
  level=max(0,min(info['maximum'],level));return ['brightnessctl','--device',info['device'],'set',str(level)]
 if action=='profile':
  if value not in {'power-saver','balanced','performance'}:raise ValueError('Invalid power profile')
  return ['powerprofilesctl','set',value]
 if action=='settings':
  if value not in {'power','network','sound','display','bluetooth','keyboard','wifi','notifications','system'}:raise ValueError('Unknown settings panel')
  return ['gnome-control-center',value]
 if action=='studio' and value:
  if value!='profiles':raise ValueError('Unknown Studio page')
  return [str(Path.home()/'.local/bin/latto-studio'),'--page','5']
 commands={'studio':[str(Path.home()/'.local/bin/latto-studio')],'lock':['loginctl','lock-session'],'suspend':['systemctl','suspend'],'restart':['systemctl','reboot'],'shutdown':['systemctl','poweroff'],'logout':['gnome-session-quit','--logout']}
 if action not in commands:raise ValueError('Unknown action')
 return commands[action]

def main():
 action=sys.argv[1] if len(sys.argv)>1 else 'snapshot'
 try:
  if action=='snapshot':result={'keyboard':keyboard(),'battery':battery(),'profiles':profiles(),'system':system_info()}
  else:
   command=action_command(action,sys.argv[2] if len(sys.argv)>2 else '')
   if not shutil.which(command[0]):raise ValueError('Required command is unavailable: '+command[0])
   if '--dry-run' in sys.argv:result={'ok':True,'command':command}
   elif action in {'settings','logout','studio'}:
    subprocess.Popen(command,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True);result={'ok':True}
   else:
    completed=subprocess.run(command,capture_output=True,text=True,timeout=15)
    result={'ok':completed.returncode==0}
    if not result['ok']:result['error']='Action was denied or unavailable. Check permissions in GNOME settings.'
  print(json.dumps(result,allow_nan=False))
 except (ValueError,OSError,subprocess.TimeoutExpired) as error:print(json.dumps({'ok':False,'error':str(error)}))
if __name__=='__main__':main()
