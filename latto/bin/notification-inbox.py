#!/usr/bin/python
"""Local, RAM-only companion to the existing desktop notification daemon.

Monitor only notification calls/replies and close signals. Never own a bus name,
log payloads, relay them over a network, or write notification content to disk.
"""
import collections
import json
import os
import signal
import sys
import time

import gi
gi.require_version('Gio', '2.0')
gi.require_version('GioUnix', '2.0')
from gi.repository import Gio, GioUnix, GLib
try:
    from gi.repository import GLibUnix
except ImportError:
    GLibUnix = None

FDO = 'org.freedesktop.Notifications'
GTK = 'org.gtk.Notifications'
PATH = '/org/freedesktop/Notifications'
LIMIT = 80


def unpack(value):
    if isinstance(value, GLib.Variant):
        return unpack(value.unpack())
    if isinstance(value, dict):
        return {key: unpack(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [unpack(item) for item in value]
    return value


class Inbox:
    def __init__(self, emit):
        self.emit = emit
        self.entries = collections.OrderedDict()
        self.pending = collections.OrderedDict()
        self.serial = 0
        self.locked = True
        self.banners = True
        self.writable = False
        self.error = ''
        self.connected = False

    def snapshot(self):
        return {'ready': self.connected, 'locked': self.locked, 'banners': self.banners,
                'writable': self.writable, 'error': self.error,
                'history': [] if self.locked else list(reversed(self.entries.values()))}

    def publish(self):
        self.emit(self.snapshot())

    def put(self, key, data):
        previous = self.entries.pop(key, None)
        self.serial += 1
        self.entries[key] = {**data, 'key': key, 'token': str(self.serial),
                             'at': int(time.time()*1000), 'unread': True,
                             'active': True}
        # A replacement stays one card, with a fresh timestamp and unread dot.
        if previous:
            self.entries[key]['key'] = previous['key']
        while len(self.entries) > LIMIT:
            self.entries.popitem(last=False)
        self.publish()

    def closed(self, key, reason=2):
        entry = self.entries.get(key)
        if not entry:
            return
        if reason == 1:
            entry['active'] = False
        else:
            self.entries.pop(key, None)
        self.publish()

    def read(self):
        if self.locked:
            return
        for item in self.entries.values():
            item['unread'] = False
        self.publish()

    def message(self, message):
        interface = message.get_interface()
        member = message.get_member()
        kind = message.get_message_type()
        body = message.get_body()
        if body is None:
            return
        if kind == Gio.DBusMessageType.METHOD_CALL and interface == FDO and member == 'Notify':
            args = unpack(body)
            self.pending[(message.get_sender(), message.get_serial())] = args
            while len(self.pending) > 128:
                self.pending.popitem(last=False)
        elif kind in (Gio.DBusMessageType.METHOD_RETURN, Gio.DBusMessageType.ERROR):
            args = self.pending.pop((message.get_destination(), message.get_reply_serial()), None)
            if args is None or kind == Gio.DBusMessageType.ERROR:
                return
            ident = unpack(body)[0]
            app, _, icon, title, text, _, hints, _ = args
            if hints.get('transient', False):
                return
            self.put('fdo:'+str(ident), {'id': ident, 'kind': 'fdo', 'appName': str(app)[:120],
                     'appIcon': str(icon)[:512], 'summary': str(title)[:240], 'body': str(text)[:4000],
                     'desktopEntry': str(hints.get('desktop-entry', ''))[:256],
                     'urgency': int(hints.get('urgency', 1))})
        elif kind == Gio.DBusMessageType.SIGNAL and interface == FDO and member == 'NotificationClosed':
            ident, reason = unpack(body)
            self.closed('fdo:'+str(ident), reason)
        elif kind == Gio.DBusMessageType.METHOD_CALL and interface == GTK:
            args = unpack(body)
            if member == 'RemoveNotification':
                self.closed('gtk:'+json.dumps(args[:2]))
            elif member == 'AddNotification':
                app, ident, data = args
                info = None
                try:
                    info = GioUnix.DesktopAppInfo.new(app if app.endswith('.desktop') else app+'.desktop')
                except TypeError:
                    pass
                self.put('gtk:'+json.dumps([app, ident]), {'id': ident, 'appId': app, 'kind': 'gtk',
                         'appName': info.get_display_name() if info else app,
                         'appIcon': info.get_icon().to_string() if info and info.get_icon() else '',
                         'desktopEntry': app, 'summary': str(data.get('title', 'Notification'))[:240],
                         'body': str(data.get('body', ''))[:4000],
                         'urgency': 2 if data.get('priority') == 'urgent' else 1})


class DesktopInbox(Inbox):
    def __init__(self):
        super().__init__(lambda data: print(json.dumps(data, ensure_ascii=False), flush=True))
        self.loop = GLib.MainLoop()
        self.control = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.focus_dnd_owned = False
        self.close_destination = FDO
        gnome = 'GNOME' in os.environ.get('XDG_CURRENT_DESKTOP', '').upper().split(':')
        try:
            info = self.control.call_sync(FDO, PATH, FDO, 'GetServerInformation', None,
                GLib.VariantType.new('(ssss)'), Gio.DBusCallFlags.NO_AUTO_START, 2000, None).unpack()
            if 'gnome' in info[0].lower():
                gnome = True
                self.close_destination = 'org.gnome.Shell'
        except GLib.Error:
            pass
        self.settings = None
        if gnome:
            schema_source = Gio.SettingsSchemaSource.get_default()
            schema = schema_source.lookup('org.gnome.desktop.notifications', True) if schema_source else None
            if schema and schema.has_key('show-banners'):
                self.settings = Gio.Settings.new_full(schema, None, None)
                self.settings.connect('changed::show-banners', lambda *_: self.preferences())
                self.preferences()
        self.setup_lock_watch()
        self.monitor = Gio.DBusConnection.new_for_address_sync(
            Gio.dbus_address_get_for_bus_sync(Gio.BusType.SESSION, None),
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
            None, None)
        self.monitor.add_filter(self.filter_message, None)
        rules = [f"type='method_call',destination='{FDO}',interface='{FDO}',member='Notify'",
                 f"type='method_return',sender='{FDO}'", f"type='error',sender='{FDO}'",
                 f"type='signal',sender='{FDO}',interface='{FDO}',member='NotificationClosed'",
                 f"type='method_call',destination='{GTK}',interface='{GTK}',member='AddNotification'",
                 f"type='method_call',destination='{GTK}',interface='{GTK}',member='RemoveNotification'"]
        self.monitor.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
            'org.freedesktop.DBus.Monitoring', 'BecomeMonitor', GLib.Variant('(asu)', (rules, 0)),
            None, Gio.DBusCallFlags.NONE, 2000, None)
        self.connected = True
        self.monitor.connect('closed', lambda *_: self.loop.quit())
        self.control.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus', 'NameOwnerChanged',
            '/org/freedesktop/DBus', FDO, Gio.DBusSignalFlags.NONE, self.owner_changed)
        self.input = Gio.DataInputStream.new(GioUnix.InputStream.new(sys.stdin.fileno(), False))
        self.read_next_command()
        self.publish()

    def owner_changed(self, *_args):
        self.entries.clear()
        self.pending.clear()
        self.publish()

    def preferences(self):
        self.banners = self.settings.get_boolean('show-banners')
        if self.banners:
            # A change in the GNOME UI can end our temporary quiet mode.
            self.focus_dnd_owned = False
        self.writable = self.settings.is_writable('show-banners')
        self.publish()

    def set_dnd(self, on):
        if self.settings is None:
            self.error = 'Do Not Disturb is unavailable in this desktop session'
            self.publish()
            return False
        if not self.settings.is_writable('show-banners') or not self.settings.set_boolean('show-banners', not on):
            self.error = 'Notification preferences are managed by desktop policy'
            self.preferences()
            return False
        self.preferences()
        return True

    def focus_dnd(self, on):
        if self.settings is None:
            return
        if on:
            if self.settings.get_boolean('show-banners'):
                self.focus_dnd_owned = self.set_dnd(True)
        elif self.focus_dnd_owned:
            self.focus_dnd_owned = False
            if not self.settings.get_boolean('show-banners'):
                self.set_dnd(False)

    def setup_lock_watch(self):
        self.system = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        try:
            user = self.system.call_sync('org.freedesktop.login1', '/org/freedesktop/login1',
                'org.freedesktop.login1.Manager', 'GetUser', GLib.Variant('(u)', (os.getuid(),)),
                None, Gio.DBusCallFlags.NONE, 2000, None).unpack()[0]
            display = unpack(self.system.call_sync('org.freedesktop.login1', user,
                'org.freedesktop.DBus.Properties', 'Get', GLib.Variant('(ss)',
                ('org.freedesktop.login1.User', 'Display')), None,
                Gio.DBusCallFlags.NONE, 2000, None))[0]
            self.session_path = display[1]
            if self.session_path == '/':
                raise RuntimeError('No graphical session')
            self.system.signal_subscribe('org.freedesktop.login1', 'org.freedesktop.DBus.Properties',
                'PropertiesChanged', self.session_path, 'org.freedesktop.login1.Session',
                Gio.DBusSignalFlags.NONE, lambda *_: self.update_lock())
            self.update_lock()
        except (GLib.Error, RuntimeError):
            self.locked = True
            self.error = 'Lock status is unavailable'

    def update_lock(self):
        try:
            props = unpack(self.system.call_sync('org.freedesktop.login1', self.session_path,
                'org.freedesktop.DBus.Properties', 'GetAll', GLib.Variant('(s)',
                ('org.freedesktop.login1.Session',)), None, Gio.DBusCallFlags.NONE, 2000, None))[0]
            self.locked = props.get('LockedHint', True) or not props.get('Active', False)
        except GLib.Error:
            self.locked = True
        self.publish()

    def filter_message(self, _connection, message, incoming, _data):
        if incoming:
            # Gio filters run on an I/O thread; serialize state on the main loop.
            GLib.idle_add(self.deliver_message, message)
            # Monitored calls belong to other clients. Do not let GIO answer
            # them: a monitor is forbidden from sending such automatic replies.
            if message.get_destination() != _connection.get_unique_name():
                return None
        return message

    def deliver_message(self, message):
        try:
            self.message(message)
        except (ValueError, TypeError, IndexError, KeyError):
            pass
        return GLib.SOURCE_REMOVE

    def dismiss(self, key, token):
        entry = self.entries.get(key)
        if self.locked or not entry or entry['token'] != token:
            return
        if not entry['active']:
            self.closed(key)
            return
        if entry['kind'] == 'gtk':
            destination, path, interface, method = GTK, '/org/gtk/Notifications', GTK, 'RemoveNotification'
            params = GLib.Variant('(ss)', (entry['appId'], entry['id']))
        else:
            destination, path, interface, method = self.close_destination, PATH, FDO, 'CloseNotification'
            params = GLib.Variant('(u)', (entry['id'],))
        def done(connection, result):
            try:
                connection.call_finish(result)
                current = self.entries.get(key)
                if current and current['token'] == token:
                    self.closed(key)
            except GLib.Error:
                self.error = 'Could not dismiss this notification'
                self.publish()
        self.control.call(destination, path, interface, method, params, None,
            Gio.DBusCallFlags.NONE, 3000, None, done)

    def command(self, data):
        action = data.get('action')
        if action == 'focus-dnd' and type(data.get('on')) is bool:
            self.focus_dnd(data['on'])
            return
        if self.locked:
            return
        self.error = ''
        if action == 'read':
            self.read()
        elif action == 'dismiss':
            self.dismiss(data.get('key'), data.get('token'))
        elif action == 'clear':
            for key, value in list(self.entries.items()):
                self.dismiss(key, value['token'])
        elif action == 'dnd' and type(data.get('on')) is bool:
            self.focus_dnd_owned = False
            self.set_dnd(data['on'])

    def read_next_command(self):
        self.input.read_line_async(GLib.PRIORITY_DEFAULT, None, self.input_ready)

    def input_ready(self, stream, result):
        try:
            line, _ = stream.read_line_finish_utf8(result)
        except GLib.Error:
            self.loop.quit()
            return
        if line is None:
            self.loop.quit()
            return
        try:
            data = json.loads(line)
            if isinstance(data, dict):
                self.command(data)
        except (ValueError, TypeError):
            pass
        self.read_next_command()


def main():
    try:
        inbox = DesktopInbox()
        add_signal = GLibUnix.signal_add if GLibUnix else GLib.unix_signal_add
        add_signal(GLib.PRIORITY_DEFAULT, signal.SIGTERM, inbox.loop.quit)
        add_signal(GLib.PRIORITY_DEFAULT, signal.SIGINT, inbox.loop.quit)
        try:
            inbox.loop.run()
        finally:
            # Quickshell can close the pipe before stopping this helper.
            inbox.emit = lambda _snapshot: None
            inbox.focus_dnd(False)
            Gio.Settings.sync()
        if not inbox.monitor.is_closed():
            inbox.monitor.close_sync(None)
    except (GLib.Error, RuntimeError):
        print(json.dumps({'ready': False, 'history': [], 'error': 'Desktop notification connection is unavailable'}), flush=True)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
