"""Exercise the desktop portal protocol using local fixtures; never access a bus."""

import importlib.util
from pathlib import Path
import stat
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location("latto_codex", Path(__file__).with_name("latto-codex.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Variant:
    def __init__(self, _signature, value):
        self.value = value

    def unpack(self):
        return self.value


class Portal:
    """Small protocol peer that can reply immediately or leave a request pending."""
    def __init__(self, code=0, values=None, mode="response", immediate=False):
        self.code, self.values = code, values or {}
        self.mode, self.immediate = mode, immediate
        self.callback = None
        self.timer = None
        self.subscribed = False
        self.closed = False
        self.removed = False
        self.requested = False
        self.options = {}
        self.handle = ""
        self.gio = SimpleNamespace(
            BusType=SimpleNamespace(SESSION=0),
            DBusSignalFlags=SimpleNamespace(NONE=0),
            DBusCallFlags=SimpleNamespace(NONE=0),
            bus_get_sync=lambda *_: self,
            File=SimpleNamespace(new_for_uri=lambda uri: SimpleNamespace(
                get_path=lambda: self.file_path if uri == self.uri else None)),
        )
        self.glib = SimpleNamespace(
            Variant=Variant, MainLoop=lambda: self,
            timeout_add=self.timeout_add,
            MainContext=SimpleNamespace(default=lambda: SimpleNamespace(
                find_source_by_id=lambda _id: self.timer is not None)),
            source_remove=self.remove_timer, SOURCE_REMOVE=False, SOURCE_CONTINUE=True,
        )
        self.uri, self.file_path = "", None

    def get_unique_name(self):
        return ":1.42"

    def signal_subscribe(self, *_args):
        self.callback = _args[-1]
        self.subscribed = True
        return 1

    def signal_unsubscribe(self, _id):
        self.subscribed = False

    def timeout_add(self, _interval, callback):
        self.timer = callback
        return 2

    def remove_timer(self, _id):
        self.timer = None
        self.removed = True

    def call_sync(self, _bus, _path, _interface, method, parameters, *_args):
        if method == "Close":
            self.closed = True
            return None
        if not self.subscribed:
            raise AssertionError("Response subscription must precede the request")
        self.requested = True
        _parent, self.options = parameters.unpack()
        token = self.options["handle_token"].unpack()
        self.handle = "/org/freedesktop/portal/desktop/request/1_42/" + token
        if self.mode == "error":
            raise RuntimeError("Portal unavailable")
        if self.immediate:
            self.respond()
        return Variant("(o)", (self.handle,))

    def respond(self):
        self.callback(self, "portal", self.handle, "request", "Response",
                      Variant("(ua{sv})", (self.code, self.values)))

    def run(self):
        if self.mode == "pending":
            if self.timer() is False:
                self.timer = None
        else:
            self.respond()

    def quit(self):
        pass


class PortalTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.directory = Path(self.folder.name)
        self.source = self.directory / "fixture.png"
        self.source.write_bytes(b"synthetic screenshot fixture")
        self.destination = self.directory / "copy.png"
        self.action = Mock()
        self.addCleanup(self.folder.cleanup)

    def invoke(self, portal):
        portal.uri = self.source.as_uri()
        portal.file_path = str(self.source)
        with patch.object(module, "gio", return_value=(portal.gio, portal.glib)):
            module.capture_screen(self.action, self.destination)

    def assert_clean(self, portal):
        self.assertFalse(portal.subscribed)
        self.assertIsNone(portal.timer)
        self.assertTrue(portal.closed)

    def test_success_copies_uri_bytes_with_private_permissions(self):
        portal = Portal(values={"uri": self.source.as_uri()})
        self.invoke(portal)
        self.assertEqual(self.destination.read_bytes(), self.source.read_bytes())
        self.assertEqual(stat.S_IMODE(self.destination.stat().st_mode), 0o600)
        self.assertFalse(portal.options["interactive"].unpack())
        self.assertFalse(portal.options["modal"].unpack())
        self.assert_clean(portal)

    def test_response_before_method_reply_is_not_lost(self):
        portal = Portal(values={"uri": self.source.as_uri()}, immediate=True)
        self.invoke(portal)
        self.assertTrue(self.destination.exists())
        self.assert_clean(portal)

    def test_denied_response_never_creates_destination(self):
        portal = Portal(code=2)
        with self.assertRaisesRegex(ValueError, "denied or unavailable"):
            self.invoke(portal)
        self.assertFalse(self.destination.exists())
        self.assert_clean(portal)

    def test_user_cancel_response_never_creates_destination(self):
        portal = Portal(code=1)
        with self.assertRaises(module.Cancelled):
            self.invoke(portal)
        self.assertFalse(self.destination.exists())
        self.assert_clean(portal)

    def test_success_without_readable_uri_is_rejected(self):
        for values in ({}, {"uri": "https://invalid.example/image.png"}):
            with self.subTest(values=values):
                portal = Portal(values=values)
                with self.assertRaisesRegex(ValueError, "readable screenshot"):
                    self.invoke(portal)
                self.assertFalse(self.destination.exists())
                self.assert_clean(portal)

    def test_cancel_pending_request_closes_portal_and_unsubscribes(self):
        portal = Portal(mode="pending")
        self.action.check.side_effect = [None, module.Cancelled()]
        with self.assertRaises(module.Cancelled):
            self.invoke(portal)
        self.assertFalse(self.destination.exists())
        self.assert_clean(portal)

    def test_pending_request_timeout_closes_portal_and_unsubscribes(self):
        portal = Portal(mode="pending")
        with patch.object(module.time, "monotonic", side_effect=[0, 121]):
            with self.assertRaisesRegex(ValueError, "timed out"):
                self.invoke(portal)
        self.assertFalse(self.destination.exists())
        self.assert_clean(portal)

    def test_request_method_failure_cleans_subscription_and_timer(self):
        portal = Portal(mode="error")
        with self.assertRaisesRegex(RuntimeError, "Portal unavailable"):
            self.invoke(portal)
        self.assertFalse(self.destination.exists())
        self.assert_clean(portal)


if __name__ == "__main__":
    unittest.main()
