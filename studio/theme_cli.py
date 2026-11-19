#!/usr/bin/python
"""Choose Latto's local appearance templates without opening Studio."""
from pathlib import Path
import argparse,json,os,sys
from model import DEFAULTS,PRESETS,CINEMA_NOTES,ConfigStore,validate
APPEARANCE=['backgroundColor','surfaceColor','textColor','accentColor','backgroundOpacity','cornerStyle','ambientStyle','ambientIntensity','ambientSpeed','motionStyle']
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('theme',nargs='?',choices=list(PRESETS))
    parser.add_argument('--list',action='store_true')
    parser.add_argument('--motion',choices=['smooth','snappy','reduced'])
    parser.add_argument('--effect',choices=['off','embers','haunted','prism','odyssey','reactor','web','neon','aurora','solar','candy'])
    parser.add_argument('--restore',action='store_true',help='Restore appearance from before the first CLI change')
    parser.add_argument('--dry-run',action='store_true',help='Print the draft without applying')
    args=parser.parse_args()
    if args.list or not any([args.theme,args.motion,args.effect,args.restore]):
        for name in PRESETS:print(name+(' — '+CINEMA_NOTES[name] if name in CINEMA_NOTES else ''))
        return
    if args.restore and any([args.theme,args.motion,args.effect]):parser.error('--restore cannot be combined with appearance changes')
    config=Path(os.environ.get('XDG_CONFIG_HOME',Path.home()/'.config'))/'latto/config.json'
    state=Path(os.environ.get('XDG_STATE_HOME',Path.home()/'.local/state'))/'latto-cinema'
    original=state/'original-appearance.json'
    store=ConfigStore(config,state/'backups')
    if args.restore:
        if not original.exists():raise ValueError('No original CLI appearance has been saved.')
        updates=json.loads(original.read_text())
        if any(k not in APPEARANCE for k in updates):raise ValueError('Invalid original appearance backup.')
    else:
        updates=dict(PRESETS[args.theme]) if args.theme else {}
        if args.motion:updates['motionStyle']=args.motion
        if args.effect:updates['ambientStyle']=args.effect
    validate({**store.read(),**updates})
    if args.dry_run:print(json.dumps(updates,indent=2));return
    state.mkdir(parents=True,exist_ok=True,mode=0o700)
    if not original.exists():
        values=validate(store.read())
        with original.open('x') as file:json.dump({k:values[k] for k in APPEARANCE},file,indent=2)
        original.chmod(0o600)
    store.update(updates)
    print('Latto appearance updated live'+(': '+args.theme if args.theme else '')+'.')
if __name__=='__main__':
    try:main()
    except (ValueError,OSError) as error:print('Latto theme:',error,file=sys.stderr);sys.exit(1)
