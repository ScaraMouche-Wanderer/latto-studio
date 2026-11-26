#!/usr/bin/python
"""Private, bounded clipboard history. No network, payload logging or shell commands.

GNOME lacks wl-paste's data-control watch protocol. GTK's X11 owner-change
notification and native selection requests use its clipboard bridge. A short-lived
GTK owner process serves restored bytes without requiring a Wayland focus popup.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import selectors
import sqlite3
import subprocess
import sys
import threading
import time
from urllib.parse import unquote, urlparse
import warnings

TEXT_LIMIT = 256 * 1024
IMAGE_LIMIT = 4 * 1024 * 1024
TOTAL_LIMIT = 64 * 1024 * 1024
PIXEL_LIMIT = 16_000_000
TEXT_MIMES = ('text/plain;charset=utf-8', 'text/plain;charset=UTF-8', 'text/plain', 'UTF8_STRING')
MIMES = ['x-special/gnome-copied-files', 'text/uri-list', 'image/png', 'image/jpeg',
         'image/webp', 'image/gif', 'image/bmp', 'text/plain;charset=utf-8',
         'text/plain;charset=UTF-8', 'text/plain', 'UTF8_STRING', 'text/html', 'application/pdf']


def read_command(args, cap, timeout=3):
    """Read a bounded pipe without buffering an arbitrarily large clipboard."""
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    data = bytearray()
    deadline = time.monotonic() + timeout
    try:
        while time.monotonic() < deadline:
            if not selector.select(max(0, deadline-time.monotonic())):
                break
            part = os.read(process.stdout.fileno(), min(65536, cap+1-len(data)))
            if not part:
                if process.wait(timeout=.5) != 0:
                    raise ValueError('Clipboard unavailable')
                return bytes(data)
            data.extend(part)
            if len(data) > cap:
                raise ValueError('Item exceeds size limit')
        raise ValueError('Clipboard read timed out')
    finally:
        selector.close()
        if process.poll() is None:
            process.kill()
        process.wait()
        process.stdout.close()


def classify(mime, data):
    if mime not in MIMES or not data:
        raise ValueError('Unsupported or empty item')
    cap = IMAGE_LIMIT if mime.startswith('image/') or mime == 'application/pdf' else TEXT_LIMIT
    if len(data) > cap:
        raise ValueError('Item exceeds size limit')
    kind, preview, thumb = 'text', '', None
    if mime.startswith('image/'):
        from PIL import Image
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as image:
                if image.width*image.height > PIXEL_LIMIT:
                    raise ValueError('Image dimensions exceed limit')
                preview = f'{image.width} × {image.height} image'
                image.thumbnail((128, 96))
                buffer = io.BytesIO()
                image.convert('RGBA').save(buffer, format='PNG')
                thumb = buffer.getvalue()
        kind = 'image'
    elif mime == 'application/pdf':
        if not data.startswith(b'%PDF-'):
            raise ValueError('Invalid document')
        kind, preview = 'file', 'PDF document'
    else:
        text = data.decode('utf-8', errors='replace')
        if '\x00' in text:
            raise ValueError('Binary content is not text')
        if mime in ('text/uri-list', 'x-special/gnome-copied-files'):
            refs = [line for line in text.splitlines() if line and not line.startswith('#') and line not in ('copy', 'cut')]
            if not refs:
                raise ValueError('Empty references')
            kind = 'file' if any(urlparse(ref).scheme == 'file' for ref in refs) else 'link'
            preview = '\n'.join(unquote(urlparse(ref).path).rsplit('/', 1)[-1] if urlparse(ref).scheme == 'file' else ref for ref in refs)
            if len(refs) > 1:
                preview = f'{len(refs)} references · ' + preview
        else:
            kind = 'link' if urlparse(text.strip()).scheme.lower() in ('https', 'http', 'mailto') and '\n' not in text.strip() else 'text'
            preview = text
    preview = ' '.join(preview.split())[:500]
    return kind, preview, thumb


class Store:
    def __init__(self, directory, limit=100):
        self.directory = Path(directory)
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.directory.chmod(0o700)
        self.thumbs = self.directory/'thumbnails'
        self.thumbs.mkdir(mode=0o700, exist_ok=True)
        self.thumbs.chmod(0o700)
        self.path = self.directory/'history.sqlite3'
        self.db = sqlite3.connect(self.path)
        self.path.chmod(0o600)
        self.db.execute('PRAGMA auto_vacuum=FULL')
        self.db.execute('PRAGMA secure_delete=ON')
        self.db.execute('PRAGMA journal_mode=DELETE')
        self.db.execute('CREATE TABLE IF NOT EXISTS items(id TEXT PRIMARY KEY,mime TEXT,kind TEXT,preview TEXT,data BLOB,size INTEGER,at INTEGER,seq INTEGER)')
        self.db.execute('CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT)')
        self.db.commit()
        self.limit = max(50, min(100, int(limit)))
        self.serial = self.db.execute('SELECT COALESCE(MAX(seq),0) FROM items').fetchone()[0]
        self.prune()
        self.clean_thumbs()

    @property
    def paused(self):
        row = self.db.execute("SELECT value FROM settings WHERE key='paused'").fetchone()
        return bool(row and row[0] == '1')

    def set_paused(self, value):
        with self.db:
            self.db.execute("INSERT OR REPLACE INTO settings VALUES('paused',?)", ('1' if value else '0',))

    def put(self, mime, data, prepared=None):
        kind, preview, thumbnail = prepared or classify(mime, data)
        ident = hashlib.sha256(mime.encode()+b'\0'+data).hexdigest()
        # GNOME can expose the same text under different UTF-8 aliases.
        if mime in TEXT_MIMES:
            existing = self.db.execute('SELECT id,mime FROM items WHERE data=? AND mime IN (?,?,?,?) ORDER BY seq DESC LIMIT 1', (data, *TEXT_MIMES)).fetchone()
            if existing:
                ident, mime = existing
        latest = self.db.execute('SELECT id FROM items ORDER BY seq DESC LIMIT 1').fetchone()
        if latest and latest[0] == ident:
            return ident
        self.serial += 1
        with self.db:
            self.db.execute('INSERT OR REPLACE INTO items VALUES(?,?,?,?,?,?,?,?)',
                            (ident, mime, kind, preview, data, len(data), int(time.time()*1000), self.serial))
        if thumbnail:
            target = self.thumbs/(ident+'.png')
            target.write_bytes(thumbnail)
            target.chmod(0o600)
        self.prune()
        return ident

    def prune(self):
        rows = self.db.execute('SELECT id,size FROM items ORDER BY seq DESC').fetchall()
        total, deleted = 0, []
        for index, (ident, size) in enumerate(rows):
            total += size
            if index >= self.limit or total > TOTAL_LIMIT:
                deleted.append(ident)
        with self.db:
            self.db.executemany('DELETE FROM items WHERE id=?', [(i,) for i in deleted])
        for ident in deleted:
            (self.thumbs/(ident+'.png')).unlink(missing_ok=True)

    def clean_thumbs(self):
        known = {row[0]+'.png' for row in self.db.execute('SELECT id FROM items')}
        for p in self.thumbs.glob('*.png'):
            if p.name not in known:
                p.unlink()

    def list(self, query='', kind='all'):
        items = []
        for ident, mime, item_kind, preview, size, at in self.db.execute('SELECT id,mime,kind,preview,size,at FROM items ORDER BY seq DESC'):
            if kind != 'all' and item_kind != kind:
                continue
            if query:
                match = query.casefold() in preview.casefold()
                if not match and not mime.startswith('image/') and mime != 'application/pdf':
                    match = query.casefold() in self.get(ident)[1].decode('utf-8', errors='replace').casefold()
                if not match:
                    continue
            thumb = self.thumbs/(ident+'.png')
            items.append(dict(id=ident, mime=mime, kind=item_kind, text=preview, size=size, at=at,
                              thumbnail=thumb.as_uri() if item_kind == 'image' and thumb.is_file() else ''))
        return items

    def get(self, ident):
        if not isinstance(ident, str) or len(ident) != 64:
            return None
        return self.db.execute('SELECT mime,data FROM items WHERE id=?', (ident,)).fetchone()

    def remove(self, ident):
        if self.get(ident):
            with self.db:
                self.db.execute('DELETE FROM items WHERE id=?', (ident,))
            (self.thumbs/(ident+'.png')).unlink(missing_ok=True)

    def clear(self):
        with self.db:
            self.db.execute('DELETE FROM items')
        self.clean_thumbs()

    def totals(self):
        return self.db.execute('SELECT COUNT(*),COALESCE(SUM(size),0) FROM items').fetchone()

    def close(self):
        self.db.close()


class Companion:
    def __init__(self, args):
        import gi
        gi.require_version('Gtk', '3.0')
        gi.require_version('Gio', '2.0')
        from gi.repository import Gtk, Gdk, GLib, Gio
        self.Gtk, self.Gdk, self.GLib, self.Gio = Gtk, Gdk, GLib, Gio
        Gtk.init([])
        self.store = Store(args.state_dir, args.limit)
        self.query, self.kind, self.error, self.copied = '', 'all', '', ''
        self.locked, self.revision, self.pending = True, 0, 0
        self.capture_busy = False
        self.capture_token = 0
        self.capture_timeout = 0
        self.capture_attempt = 0
        self.capture_requested_revision = 0
        self.input_buffer = bytearray()
        self.clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        if not self.clipboard:
            raise RuntimeError('Desktop clipboard is unavailable')
        self.clipboard.connect('owner-change', self.changed)
        self.setup_lock()
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, self.command)
        if not args.skip_initial:
            GLib.timeout_add(250, self.changed)
        self.publish()

    def setup_lock(self):
        try:
            self.system = self.Gio.bus_get_sync(self.Gio.BusType.SYSTEM, None)
            result = self.system.call_sync('org.freedesktop.login1', f'/org/freedesktop/login1/user/_{os.getuid()}',
                'org.freedesktop.DBus.Properties', 'Get', self.GLib.Variant('(ss)', ('org.freedesktop.login1.User', 'Display')), None,
                self.Gio.DBusCallFlags.NONE, 1500, None).unpack()[0]
            if isinstance(result, self.GLib.Variant):
                result = result.unpack()
            self.session_path = result[1]
            self.system.signal_subscribe('org.freedesktop.login1', 'org.freedesktop.DBus.Properties', 'PropertiesChanged',
                self.session_path, 'org.freedesktop.login1.Session', self.Gio.DBusSignalFlags.NONE, self.lock_changed)
            self.lock_changed()
        except Exception:
            self.locked = True
            self.error = 'Could not check the desktop lock state'

    def lock_changed(self, *unused):
        previous = self.locked
        try:
            props = self.system.call_sync('org.freedesktop.login1', self.session_path, 'org.freedesktop.DBus.Properties', 'GetAll',
                self.GLib.Variant('(s)', ('org.freedesktop.login1.Session',)), None, self.Gio.DBusCallFlags.NONE, 1500, None).unpack()[0]
            self.locked = bool(props.get('LockedHint', True)) or not bool(props.get('Active', False))
        except Exception:
            self.locked = True
        if previous != self.locked:
            self.revision += 1
            if hasattr(self, 'store'):
                self.publish()

    def publish(self):
        count, total = self.store.totals()
        message = dict(ready=True, locked=self.locked, paused=self.store.paused, items=[] if self.locked else self.store.list(self.query, self.kind),
            query=self.query, kind=self.kind, count=count, totalBytes=total, limit=self.store.limit, error=self.error, copied=self.copied)
        try:
            print(json.dumps(message, ensure_ascii=True), flush=True)
        except BrokenPipeError:
            self.Gtk.main_quit()
        self.copied = ''

    def changed(self, *unused):
        self.revision += 1
        self.capture_attempt = 0
        if self.pending:
            self.GLib.source_remove(self.pending)
        self.pending = 0
        if not self.locked and not self.store.paused:
            self.capture_requested_revision = self.revision
            self.pending = self.GLib.timeout_add(70, self.capture, self.revision)
        return False

    def capture(self, revision):
        self.pending = 0
        if revision != self.revision or self.locked or self.store.paused:
            return False
        if self.capture_busy:
            return False
        self.capture_busy = True
        self.capture_attempt += 1
        self.capture_token += 1
        token = self.capture_token
        self.capture_timeout = self.GLib.timeout_add(1800, self.capture_expired, revision, token)
        self.clipboard.request_contents(self.Gdk.Atom.intern('TARGETS', False), self.target_data_received, (revision, token))
        return False

    def request_active(self, revision, token):
        return token == self.capture_token and revision == self.revision and not self.locked and not self.store.paused

    def target_data_received(self, clipboard, selection, context):
        revision, token = context
        if selection.get_length() <= 0:
            self.native_finished(revision, token)
            if selection.get_length() < 0:
                self.capture_failed(revision)
            return
        success, targets = selection.get_targets()
        self.targets_received(clipboard, targets if success else [], len(targets or []), context)

    def targets_received(self, clipboard, targets, count, context):
        revision, token = context
        if not self.request_active(revision, token):
            self.native_finished(revision, token)
            return
        offered = [target.name() for target in (targets or [])]
        if any('password' in t.lower() or 'keepass' in t.lower() or 'sensitive' in t.lower() for t in offered):
            self.native_finished(revision, token)
            return
        candidates = [mime for mime in MIMES if mime in offered]
        if not candidates:
            self.native_finished(revision, token)
            return
        self.request_candidate(revision, token, candidates)

    def request_candidate(self, revision, token, candidates):
        mime = candidates[0]
        self.clipboard.request_contents(self.Gdk.Atom.intern(mime, False), self.contents_received, (revision, token, candidates))

    def contents_received(self, clipboard, selection, context):
        revision, token, candidates = context
        if not self.request_active(revision, token):
            self.native_finished(revision, token)
            return
        mime = candidates[0]
        length = selection.get_length()
        if length <= 0:
            if len(candidates) > 1:
                self.request_candidate(revision, token, candidates[1:])
            else:
                self.native_finished(revision, token)
                if length < 0:
                    self.capture_failed(revision)
            return
        cap = IMAGE_LIMIT if mime.startswith('image/') or mime == 'application/pdf' else TEXT_LIMIT
        if length > cap:
            self.native_finished(revision, token)
            self.capture_skipped(revision)
            return
        data = bytes(selection.get_data())
        if self.capture_timeout:
            self.GLib.source_remove(self.capture_timeout)
            self.capture_timeout = 0
        def prepare():
            try:
                prepared = classify(mime, data)
                self.GLib.idle_add(self.captured, revision, mime, data, prepared)
            except Exception:
                self.GLib.idle_add(self.capture_skipped, revision)
            finally:
                self.GLib.idle_add(self.native_finished, revision, token)
        threading.Thread(target=prepare, daemon=True).start()

    def native_finished(self, revision, token):
        if token != self.capture_token:
            return False
        if self.capture_timeout:
            self.GLib.source_remove(self.capture_timeout)
            self.capture_timeout = 0
        self.capture_finished(revision)
        return False

    def capture_expired(self, revision, token):
        if token != self.capture_token:
            return False
        self.capture_timeout = 0
        self.capture_token += 1  # Ignore an eventual response to the expired request.
        self.capture_finished(revision)
        self.capture_failed(revision)
        return False

    def capture_failed(self, revision):
        if revision != self.revision or self.locked or self.store.paused:
            return False
        if self.capture_attempt < 3:
            self.pending = self.GLib.timeout_add(150*self.capture_attempt, self.capture, revision)
        else:
            self.error = 'The source app did not provide this copy. Copy it again to retry.'
            self.publish()
        return False

    def capture_finished(self, revision):
        self.capture_busy = False
        if revision != self.revision and self.capture_requested_revision == self.revision and not self.locked and not self.store.paused:
            if self.pending:
                self.GLib.source_remove(self.pending)
            self.pending = self.GLib.timeout_add(70, self.capture, self.revision)
        return False

    def capture_skipped(self, revision):
        if revision == self.revision and not self.locked and not self.store.paused:
            self.error = 'Item skipped: unavailable, unsupported or over the size limit'
            self.publish()
        return False

    def captured(self, revision, mime, data, prepared):
        if revision == self.revision and not self.locked and not self.store.paused:
            try:
                self.store.put(mime, data, prepared)
                self.error = ''
                self.publish()
            except Exception:
                self.error = 'Could not save this clipboard item'
                self.publish()
        return False

    def command(self, stream, condition):
        if not condition & self.GLib.IO_IN:
            self.Gtk.main_quit()
            return False
        chunk = os.read(stream.fileno(), 65536)
        if not chunk:
            self.Gtk.main_quit()
            return False
        self.input_buffer.extend(chunk)
        while b'\n' in self.input_buffer:
            line, rest = self.input_buffer.split(b'\n', 1)
            self.input_buffer = bytearray(rest)
            if len(line) <= 65536:
                self.dispatch(line)
        if len(self.input_buffer) > 65536:
            self.input_buffer.clear()
        return True

    def dispatch(self, line):
        try:
            data = json.loads(line)
            action = data.get('action')
            if self.locked:
                return True
            self.error = ''
            if action == 'search':
                self.query = str(data.get('query', ''))[:200]
                self.kind = data.get('kind', 'all') if data.get('kind') in ('all', 'text', 'link', 'image', 'file') else 'all'
            elif action == 'pause':
                self.revision += 1
                self.store.set_paused(data.get('paused') is True)
            elif action == 'limit':
                self.store.limit = max(50, min(100, int(data['limit'])))
                self.store.prune()
            elif action == 'delete':
                self.store.remove(data.get('id'))
            elif action == 'clear':
                self.revision += 1
                self.store.clear()
            elif action == 'copy':
                entry = self.store.get(data.get('id'))
                if not entry:
                    raise ValueError('Item unavailable')
                ident = data['id']
                def restore():
                    try:
                        offer_native(entry[0], entry[1])
                        self.GLib.idle_add(self.restored, ident, True)
                    except Exception:
                        self.GLib.idle_add(self.restored, ident, False)
                threading.Thread(target=restore, daemon=True).start()
            elif action != 'refresh':
                raise ValueError('Unknown command')
            self.publish()
        except Exception:
            self.error = 'Clipboard action could not be completed'
            self.publish()
        return True

    def restored(self, ident, success):
        if not self.locked:
            self.copied = ident if success else ''
            self.error = '' if success else 'Could not restore this item'
            self.publish()
        return False


def offer_native(mime, data):
    """The separate owner survives QML/helper reloads until the next copy."""
    process = subprocess.Popen([sys.executable, __file__, '--offer-stdin', mime], stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        process.stdin.write(data)
        process.stdin.close()
        ready = selectors.DefaultSelector()
        try:
            ready.register(process.stdout, selectors.EVENT_READ)
            if not ready.select(3) or process.stdout.readline(64) != b'READY\n':
                raise ValueError('Clipboard owner did not start')
        finally:
            ready.close()
        process.stdout.close()
    except Exception:
        process.kill()
        process.wait()
        raise


def serve_native(mime, data):
    # GTK's data-provider callbacks are not introspected by PyGObject. Keep
    # these small C callbacks alive for the duration of the clipboard ownership.
    import ctypes as C
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, Gdk, GLib
    Gtk.init([])
    clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    gtk = C.CDLL('libgtk-3.so.0')
    gdk = C.CDLL('libgdk-3.so.0')
    capsule = C.pythonapi.PyCapsule_GetPointer
    capsule.argtypes = [C.py_object, C.c_char_p]
    capsule.restype = C.c_void_p
    pointer = capsule(clipboard.__gpointer__, None)
    class Target(C.Structure):
        _fields_ = [('target', C.c_char_p), ('flags', C.c_uint), ('info', C.c_uint)]
    names = TEXT_MIMES if mime in TEXT_MIMES else [mime]
    targets = (Target*len(names))(*[Target(name.encode(), 0, i) for i, name in enumerate(names)])
    payload = C.create_string_buffer(data)
    get_callback = C.CFUNCTYPE(None, C.c_void_p, C.c_void_p, C.c_uint, C.c_void_p)
    clear_callback = C.CFUNCTYPE(None, C.c_void_p, C.c_void_p)
    gdk.gdk_atom_intern.argtypes = [C.c_char_p, C.c_int]
    gdk.gdk_atom_intern.restype = C.c_void_p
    gtk.gtk_selection_data_set.argtypes = [C.c_void_p, C.c_void_p, C.c_int, C.c_void_p, C.c_int]
    @get_callback
    def provide(unused, selection, index, user_data):
        if index < len(names):
            gtk.gtk_selection_data_set(selection, gdk.gdk_atom_intern(names[index].encode(), 0), 8, payload, len(data))
    owned = [True]
    @clear_callback
    def cleared(unused, user_data):
        owned[0] = False
        if Gtk.main_level():
            Gtk.main_quit()
    gtk.gtk_clipboard_set_with_data.argtypes = [C.c_void_p, C.POINTER(Target), C.c_uint, get_callback, clear_callback, C.c_void_p]
    gtk.gtk_clipboard_set_with_data.restype = C.c_int
    if not gtk.gtk_clipboard_set_with_data(pointer, targets, len(names), provide, cleared, None):
        raise ValueError('Could not own clipboard')
    clipboard.set_can_store(None)
    Gdk.Display.get_default().sync()
    def ready():
        print('READY', flush=True)
        return False
    if owned[0]:
        GLib.idle_add(ready)
        Gtk.main()


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument('--state-dir', default=str(Path(os.environ.get('XDG_DATA_HOME', Path.home()/'.local/share'))/'latto/clipboard'))
    parser.add_argument('--limit', type=int, default=100)
    parser.add_argument('--skip-initial', action='store_true')
    parser.add_argument('--offer-stdin', choices=MIMES)
    args = parser.parse_args()
    os.environ['GDK_BACKEND'] = 'x11'
    if args.offer_stdin:
        data = sys.stdin.buffer.read(IMAGE_LIMIT+1)
        if not data or len(data) > IMAGE_LIMIT:
            raise ValueError('Invalid clipboard payload')
        serve_native(args.offer_stdin, data)
        return
    companion = Companion(args)
    try:
        companion.Gtk.main()
    finally:
        companion.store.close()


if __name__ == '__main__':
    main()
