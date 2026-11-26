#!/usr/bin/python
"""Session-local music search and windowless playback. No cookies/history files."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import socket
import struct
import subprocess
import threading
import time

import gi
gi.require_version('Gio', '2.0')
gi.require_version('GLibUnix', '2.0')
from gi.repository import Gio, GLib, GLibUnix

PLAYER = 'org.mpris.MediaPlayer2.Player'
ROOT = 'org.mpris.MediaPlayer2'
MPATH = '/org/mpris/MediaPlayer2'
XML = '''<node>
<interface name="org.mpris.MediaPlayer2">
<method name="Raise"/><method name="Quit"/>
<property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
<property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
<property name="DesktopEntry" type="s" access="read"/><property name="SupportedUriSchemes" type="as" access="read"/>
<property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
<method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/><method name="Stop"/><method name="Play"/>
<method name="Seek"><arg type="x" direction="in"/></method>
<method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
<method name="OpenUri"><arg type="s" direction="in"/></method>
<signal name="Seeked"><arg type="x"/></signal>
<property name="PlaybackStatus" type="s" access="read"/>
<property name="Rate" type="d" access="readwrite"/>
<property name="Metadata" type="a{sv}" access="read"/><property name="Volume" type="d" access="readwrite"/>
<property name="Position" type="x" access="read"/><property name="MinimumRate" type="d" access="read"/><property name="MaximumRate" type="d" access="read"/>
<property name="CanGoNext" type="b" access="read"/><property name="CanGoPrevious" type="b" access="read"/>
<property name="CanPlay" type="b" access="read"/><property name="CanPause" type="b" access="read"/>
<property name="CanSeek" type="b" access="read"/><property name="CanControl" type="b" access="read"/>
</interface></node>'''


def normalize_results(raw, limit):
    result, seen = [], set()
    for item in raw:
        ident = item.get('videoId', '')
        if not re.fullmatch(r'[\w-]{11}', ident, re.ASCII) or ident in seen:
            continue
        seen.add(ident)
        artists = item.get('artists') or []
        duration = item.get('duration_seconds') or 0
        result.append({'id': ident, 'title': str(item.get('title') or 'Untitled')[:240],
            'artist': ', '.join(str(a.get('name', '')) for a in artists)[:240],
            'album': str((item.get('album') or {}).get('name', ''))[:240],
            'duration': max(0, int(duration)), 'durationText': str(item.get('duration') or ''),
            'explicit': bool(item.get('isExplicit'))})
        if len(result) == limit:
            break
    return result


class Music:
    def __init__(self):
        self.runtime = Path(os.environ['XDG_RUNTIME_DIR'])/'latto-player'
        self.runtime.mkdir(mode=0o700, exist_ok=True)
        self.runtime.chmod(0o700)
        self.lock = (self.runtime/'daemon.lock').open('w')
        fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.results, self.queue = [], []
        self.query, self.error, self.phase = '', '', 'idle'
        self.limit, self.index = 20, -1
        self.searching, self.has_more, self.paused = False, False, False
        self.position, self.duration, self.volume = 0., 0., .65
        self.search_revision, self.play_revision = 0, 0
        self.mpv, self.mpv_socket = None, None
        self.mpv_lock = threading.Lock()
        self.resolver_lock = threading.Lock()
        self.resolver_process = None
        self.clients = set()
        self.last_properties = {}
        self.last_broadcast = 0
        self.loop = GLib.MainLoop()
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        for interface in Gio.DBusNodeInfo.new_for_xml(XML).interfaces:
            self.bus.register_object(MPATH, interface, self.method, self.get_property, self.set_property)
        self.owner = Gio.bus_own_name_on_connection(self.bus, ROOT+'.Latto', Gio.BusNameOwnerFlags.NONE, None, None)
        path = self.runtime/'control.sock'
        path.unlink(missing_ok=True)
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(str(path));path.chmod(0o600);self.server.listen(4)
        threading.Thread(target=self.accept_clients, daemon=True).start()
        GLib.timeout_add(250, self.tick)

    @property
    def track(self):
        return self.queue[self.index] if 0 <= self.index < len(self.queue) else None

    def state(self):
        return {'ready': True, 'query': self.query, 'limit': self.limit,
            'searching': self.searching, 'hasMore': self.has_more, 'results': self.results,
            'track': self.track, 'phase': self.phase, 'paused': self.paused,
            'error': self.error, 'position': self.position, 'duration': self.duration}

    def accept_clients(self):
        while True:
            try:
                client, _ = self.server.accept()
                _, uid, _ = struct.unpack('3i', client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
                if uid != os.getuid():
                    client.close();continue
                client.settimeout(2)
                GLib.idle_add(self.add_client, client)
                threading.Thread(target=self.read_client, args=(client,), daemon=True).start()
            except OSError:
                return

    def add_client(self, client):
        self.clients.add(client);self.publish();return GLib.SOURCE_REMOVE

    def read_client(self, client):
        buffer = b''
        try:
            while True:
                try:
                    chunk = client.recv(8192)
                except socket.timeout:
                    continue
                if not chunk:
                    break
                buffer += chunk
                if len(buffer) > 65536:
                    break
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    try:
                        data = json.loads(line)
                        if isinstance(data, dict):
                            GLib.idle_add(self.command, data)
                    except (ValueError, UnicodeError):
                        continue
        except OSError:
            pass
        GLib.idle_add(self.remove_client, client)

    def remove_client(self, client):
        self.clients.discard(client)
        with contextlib.suppress(OSError):client.close()
        return GLib.SOURCE_REMOVE

    def publish(self):
        packet = (json.dumps(self.state(), ensure_ascii=False)+'\n').encode()
        for client in list(self.clients):
            try:client.sendall(packet)
            except OSError:self.remove_client(client)
        self.emit_properties()
        self.last_broadcast = time.monotonic()

    def search(self, query, limit):
        if not isinstance(query, str) or not query.strip() or len(query) > 500:
            return
        if type(limit) is not int or not 1 <= limit <= 100:
            return
        query = query.strip()
        self.search_revision += 1
        revision = self.search_revision
        if query != self.query:self.results = []
        self.query, self.limit, self.searching, self.error = query, limit, True, ''
        self.publish()
        def worker():
            session = None
            try:
                from ytmusicapi import YTMusic
                # Bounded network timeouts, no authentication or browser data.
                import requests
                session = requests.Session()
                request = session.request
                session.request = lambda *a, **kw: request(*a, **{**kw, 'timeout': (5, 15)})
                raw = YTMusic(requests_session=session).search(query, filter='songs', limit=limit)
                tracks = normalize_results(raw, limit)
                GLib.idle_add(self.search_done, revision, tracks, len(raw) >= limit, '')
            except Exception:
                GLib.idle_add(self.search_done, revision, [], False, 'Could not search the music catalog. Try again.')
            finally:
                if session is not None:session.close()
        threading.Thread(target=worker, daemon=True).start()

    def search_done(self, revision, tracks, more, error):
        if revision == self.search_revision:
            self.results, self.has_more, self.searching, self.error = tracks, more and self.limit < 100, False, error
            self.publish()
        return GLib.SOURCE_REMOVE

    def command(self, data):
        action = data.get('action')
        if action == 'search':self.search(data.get('query'), data.get('limit', 20))
        elif action == 'play':
            ident = data.get('id')
            if any(track['id'] == ident for track in self.results):
                self.queue = list(self.results);self.index = next(i for i,t in enumerate(self.queue) if t['id'] == ident)
                self.play_current()
        elif action == 'stop':self.stop()
        elif action == 'clearError':self.error='';self.publish()
        return GLib.SOURCE_REMOVE

    def play_current(self):
        if not self.track:return
        self.play_revision += 1;revision = self.play_revision
        self.cancel_resolver()
        self.phase, self.error, self.paused = 'loading', '', False
        self.position, self.duration = 0., float(self.track['duration'])
        self.mpv_send(['stop'])
        self.publish();ident = self.track['id']
        def worker():
            process = None
            try:
                cmd = ['/usr/bin/yt-dlp','--ignore-config','--no-cache-dir','--no-playlist','--skip-download',
                    '--dump-single-json','--socket-timeout','8','--retries','0','--extractor-retries','0',
                    '--format','bestaudio','https://www.youtube.com/watch?v='+ident]
                with self.resolver_lock:
                    if revision != self.play_revision:return
                    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                    self.resolver_process = process
                try:output,_ = process.communicate(timeout=35)
                except subprocess.TimeoutExpired:
                    process.kill();process.communicate();raise RuntimeError('Timed out')
                if process.returncode:raise RuntimeError('Unavailable')
                info = json.loads(output);url = info.get('url', '')
                if not url.startswith('https://'):raise RuntimeError('Invalid stream')
                if revision != self.play_revision:return
                self.ensure_mpv()
                GLib.idle_add(self.resolved, revision, url, '')
            except Exception:
                GLib.idle_add(self.resolved, revision, '', 'This track could not be played. Try another result.')
            finally:
                with self.resolver_lock:
                    if self.resolver_process is process:self.resolver_process = None
        threading.Thread(target=worker, daemon=True).start()

    def resolved(self, revision, url, error):
        if revision != self.play_revision:
            if self.phase == 'stopped':self.release_mpv()
            return GLib.SOURCE_REMOVE
        if error:self.phase, self.error = 'error', error
        elif not self.mpv_send(['loadfile',url,'replace']):self.phase,self.error='error','Audio player is unavailable. Try again.'
        else:self.mpv_send(['set_property','pause',False])
        self.publish();return GLib.SOURCE_REMOVE

    def ensure_mpv(self):
        with self.mpv_lock:
            if self.mpv and self.mpv.poll() is None and self.mpv_socket:return
            path = self.runtime/'mpv.sock';path.unlink(missing_ok=True)
            cmd = ['/usr/bin/mpv','--no-config','--load-scripts=no','--idle=yes','--vid=no','--audio-display=no',
                '--force-window=no','--terminal=no','--resume-playback=no','--input-default-bindings=no',
                '--input-ipc-server='+str(path),'--audio-client-name=Latto Music','--volume='+str(self.volume*100)]
            if os.environ.get('LATTO_MUSIC_TEST_NULL_AUDIO') == '1':cmd.append('--ao=null')
            self.mpv = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for _ in range(100):
                if path.exists():break
                if self.mpv.poll() is not None:raise RuntimeError('Audio player exited')
                time.sleep(.025)
            peer = socket.socket(socket.AF_UNIX);peer.connect(str(path));self.mpv_socket = peer
            threading.Thread(target=self.mpv_events,args=(peer,),daemon=True).start()
            for ident,name in enumerate(['time-pos','duration','pause','volume']):
                peer.sendall((json.dumps({'command':['observe_property',ident,name]})+'\n').encode())

    def mpv_send(self, command):
        if not self.mpv_socket:return False
        try:
            with self.mpv_lock:self.mpv_socket.sendall((json.dumps({'command':command})+'\n').encode())
            return True
        except OSError:return False

    def mpv_events(self, peer):
        try:
            for line in peer.makefile('rb'):
                GLib.idle_add(self.mpv_event, peer, json.loads(line))
        except (OSError, ValueError):pass
        GLib.idle_add(self.mpv_disconnected, peer)

    def mpv_disconnected(self, peer):
        if self.mpv_socket is peer:
            self.mpv_socket = None
            if self.phase not in ('idle','stopped'):
                self.phase,self.error='error','Audio player disconnected. Select the track to retry.';self.publish()
        return GLib.SOURCE_REMOVE

    def mpv_event(self, peer, event):
        if peer is not self.mpv_socket:return GLib.SOURCE_REMOVE
        kind = event.get('event')
        if kind == 'property-change':
            name,value = event.get('name'),event.get('data')
            if value is None:return GLib.SOURCE_REMOVE
            if name == 'time-pos':self.position=max(0,float(value))
            elif name == 'duration':self.duration=max(0,float(value))
            elif name == 'volume':self.volume=max(0,min(1,float(value)/100))
            elif name == 'pause':
                self.paused=bool(value)
                if self.phase in ('playing','paused'):self.phase='paused' if self.paused else 'playing'
                self.publish()
        elif kind == 'file-loaded':self.phase='paused' if self.paused else 'playing';self.publish()
        elif kind == 'end-file':
            if event.get('reason') == 'eof':
                if self.index+1<len(self.queue):self.index+=1;self.play_current()
                else:self.phase='stopped';self.release_mpv();self.publish()
            elif event.get('reason') == 'error':
                self.phase,self.error='error','Playback failed. Try another result.';self.publish()
        return GLib.SOURCE_REMOVE

    def stop(self):
        self.play_revision+=1;self.cancel_resolver();self.phase='stopped';self.position=0;self.error='';self.release_mpv();self.publish()

    def cancel_resolver(self):
        with self.resolver_lock:
            if self.resolver_process and self.resolver_process.poll() is None:
                self.resolver_process.terminate()

    def release_mpv(self):
        with self.mpv_lock:
            process,peer=self.mpv,self.mpv_socket
            self.mpv,self.mpv_socket=None,None
            if peer:
                with contextlib.suppress(OSError):peer.shutdown(socket.SHUT_RDWR);peer.close()
            if process and process.poll() is None:
                process.terminate()
                def reap():
                    try:process.wait(timeout=2)
                    except subprocess.TimeoutExpired:process.kill();process.wait()
                threading.Thread(target=reap,daemon=True).start()

    def tick(self):
        if self.phase in ('playing','paused') and self.clients and time.monotonic()-self.last_broadcast>=.5:self.publish()
        return GLib.SOURCE_CONTINUE

    def properties(self):
        track=self.track;metadata={}
        if track:
            metadata={'mpris:trackid':GLib.Variant('o','/io/github/latto/track/'+track['id'].replace('-','_')),
                'xesam:title':GLib.Variant('s',track['title']),'xesam:artist':GLib.Variant('as',[track['artist']]),
                'xesam:album':GLib.Variant('s',track['album']),'mpris:length':GLib.Variant('x',int(self.duration*1000000))}
        return {'PlaybackStatus':GLib.Variant('s','Playing' if self.phase=='playing' else 'Paused' if self.phase=='paused' else 'Stopped'),
            'Metadata':GLib.Variant('a{sv}',metadata),
            'Rate':GLib.Variant('d',1.),'Volume':GLib.Variant('d',self.volume),'Position':GLib.Variant('x',int(self.position*1000000)),
            'MinimumRate':GLib.Variant('d',1.),'MaximumRate':GLib.Variant('d',1.),
            'CanGoNext':GLib.Variant('b',0<=self.index<len(self.queue)-1),'CanGoPrevious':GLib.Variant('b',self.index>0),
            'CanPlay':GLib.Variant('b',bool(track) and self.phase!='loading'),'CanPause':GLib.Variant('b',self.phase in ('playing','paused')),
            'CanSeek':GLib.Variant('b',self.duration>0 and self.phase in ('playing','paused')),'CanControl':GLib.Variant('b',True)}

    def emit_properties(self):
        current=self.properties();changed={k:v for k,v in current.items() if k!='Position' and self.last_properties.get(k)!=v}
        if changed:self.bus.emit_signal(None,MPATH,'org.freedesktop.DBus.Properties','PropertiesChanged',GLib.Variant('(sa{sv}as)',(PLAYER,changed,[])))
        self.last_properties=current

    def get_property(self,_bus,_sender,_path,interface,name):
        if interface==PLAYER:return self.properties().get(name)
        root={'CanQuit':GLib.Variant('b',True),'CanRaise':GLib.Variant('b',False),'HasTrackList':GLib.Variant('b',False),
            'Identity':GLib.Variant('s','Latto Music'),'DesktopEntry':GLib.Variant('s','latto-studio'),
            'SupportedUriSchemes':GLib.Variant('as',[]),'SupportedMimeTypes':GLib.Variant('as',[])}
        return root.get(name)

    def set_property(self,_bus,_sender,_path,_interface,name,value):
        if name=='Volume':
            self.volume=max(0,min(1,value.unpack()));self.mpv_send(['set_property','volume',self.volume*100]);self.publish();return True
        return name=='Rate' and value.unpack()==1.

    def seek(self,seconds):
        if self.phase not in ('playing','paused'):return
        self.position=max(0,min(self.duration,seconds));self.mpv_send(['seek',self.position,'absolute+exact'])
        self.bus.emit_signal(None,MPATH,PLAYER,'Seeked',GLib.Variant('(x)',(int(self.position*1000000),)))

    def method(self,_bus,_sender,_path,interface,name,params,invocation):
        if interface==ROOT:
            if name=='Quit':GLib.idle_add(self.loop.quit)
        elif name=='Stop':self.stop()
        elif name in ('Next','Previous'):
            target=self.index+(1 if name=='Next' else -1)
            if 0<=target<len(self.queue):self.index=target;self.play_current()
        elif name in ('Play','Pause','PlayPause'):
            if name in ('Play','PlayPause') and self.phase in ('stopped','idle','error'):self.play_current()
            elif self.phase in ('playing','paused'):
                pause=name=='Pause' or (name=='PlayPause' and self.phase=='playing')
                self.mpv_send(['set_property','pause',pause])
        elif name=='Seek':self.seek(self.position+params.unpack()[0]/1000000)
        elif name=='SetPosition':
            path,pos=params.unpack()
            if self.track and path==self.properties()['Metadata'].unpack()['mpris:trackid']:self.seek(pos/1000000)
        elif name=='OpenUri':invocation.return_dbus_error('org.mpris.MediaPlayer2.Error.NotSupported','Select a track in Latto.');return
        invocation.return_value(None)

    def close(self):
        self.play_revision+=1;self.cancel_resolver()
        if self.mpv:
            self.mpv.terminate()
            with contextlib.suppress(subprocess.TimeoutExpired):self.mpv.wait(timeout=2)
            if self.mpv.poll() is None:self.mpv.kill()
        self.server.close();(self.runtime/'control.sock').unlink(missing_ok=True)


def main():
    music=Music()
    for sig in (signal.SIGTERM,signal.SIGINT):GLibUnix.signal_add(GLib.PRIORITY_DEFAULT,sig,lambda: (music.loop.quit(),False)[1])
    try:music.loop.run()
    finally:music.close()


if __name__=='__main__':main()
